const router   = require("express").Router();
const db       = require("../config/db");
const Razorpay = require("razorpay");
const { sendBookingConfirmedToUser, sendBookingAlertToCaretakers, sendCancellationNotifications } =
  require("../services/notificationEmail.service");

const razorpay = new Razorpay({
  key_id:     process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

const generateOrderCode = () => {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "ORD-";
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
};

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "";

const getServiceName = async (orderId) => {
  const [rows] = await db.query(
    `SELECT s.name FROM services s JOIN order_items oi ON oi.service_id = s.id WHERE oi.order_id = ?`,
    [orderId]
  );
  return rows.map((r) => r.name).join(", ") || "Service";
};

// Refund computed on subtotal only — service_charge is non-refundable
const computeRefund = (order) => {
  if (order.payment_method !== "RAZORPAY" || order.payment_status !== "PAID")
    return { refundAmount: 0, refundPercent: 0, eligible: false };
  const slotDt   = new Date(`${order.date.toISOString().split("T")[0]}T${order.slot}`);
  const diffHrs  = (slotDt - new Date()) / (1000 * 60 * 60);
  const subtotal = parseFloat(order.subtotal ?? order.total);
  if (diffHrs >= 3) return { refundAmount: subtotal,       refundPercent: 100, eligible: true };
  if (diffHrs >  0) return { refundAmount: subtotal * 0.5, refundPercent: 50,  eligible: true };
  return { refundAmount: 0, refundPercent: 0, eligible: false };
};

/* =========================================
   GET /orders/:userId
========================================= */
router.get("/:userId", async (req, res) => {
  try {
    const [orders] = await db.query(
      `SELECT o.*, o.subtotal, o.service_charge,
              GROUP_CONCAT(s.name SEPARATOR ', ') AS service_names
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       LEFT JOIN services    s  ON s.id = oi.service_id
       WHERE o.user_id = ? GROUP BY o.id ORDER BY o.id DESC`,
      [req.params.userId]
    );
    return res.json(orders);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =========================================
   GET /orders/detail/:id
========================================= */
router.get("/detail/:id", async (req, res) => {
  try {
    const [[order]] = await db.query(
      `SELECT o.*, o.subtotal, o.service_charge,
              GROUP_CONCAT(s.name SEPARATOR ', ') AS service_names,
              ct.first_name AS caregiver_name, ct.mobile AS caregiver_phone
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       LEFT JOIN services    s  ON s.id = oi.service_id
       LEFT JOIN users       ct ON ct.id = o.caretaker_id
       WHERE o.id = ? GROUP BY o.id`,
      [req.params.id]
    );
    if (!order) return res.status(404).json({ success: false, message: "Order not found" });
    return res.json({ success: true, order });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =========================================
   POST /orders/place
========================================= */
router.post("/place", async (req, res) => {
  let conn;
  try {
    const { user_id, location, date, slot, payment_method, payment_id, latitude, longitude, items } = req.body;

    if (!items?.length)
      return res.status(400).json({ success: false, message: "No services selected" });

    const [[settings]] = await db
      .query(`SELECT service_charge FROM admin_settings LIMIT 1`)
      .catch(() => [[{ service_charge: 0 }]]);
    const serviceCharge = parseFloat(settings?.service_charge ?? 0);

    conn = await db.getConnection();
    await conn.beginTransaction();

    // Group items by category — each category becomes its own order
    const grouped = {};
    for (const item of items) {
      const cat = item.category || "Nurse";
      (grouped[cat] = grouped[cat] || []).push(item);
    }

    const createdOrders = [];

    for (const category of Object.keys(grouped)) {
      const groupItems = grouped[category];
      const orderCode  = generateOrderCode();
      const subtotal   = groupItems.reduce((s, i) => s + parseFloat(i.price), 0);
      const total      = subtotal + serviceCharge;
      const isPaid     = payment_method === "RAZORPAY" && !!payment_id;

      /* =========================================
         CHECK SERVICES THAT REQUIRE DOCUMENTS
      ========================================= */
      const serviceIds = groupItems.map((item) => item.service_id);

      const [requiredServices] = await conn.query(
        `SELECT id, name FROM services WHERE id IN (?) AND requires_documents = 1`,
        [serviceIds]
      );

      /* =========================================
         VALIDATE DOCUMENTS UPLOADED
      ========================================= */
      for (const service of requiredServices) {
        const [documents] = await conn.query(
          `SELECT id FROM booking_documents
           WHERE user_id = ? AND service_id = ? AND order_id IS NULL`,
          [user_id, service.id]
        );

        if (documents.length === 0) {
          await conn.rollback();
          return res.status(400).json({
            success: false,
            message: `${service.name} requires medical documents before payment.`,
          });
        }
      }

      const [orderRes] = await conn.query(
        `INSERT INTO orders
         (order_code, user_id, location, date, slot, subtotal, service_charge, total,
          payment_method, payment_id, status, latitude, longitude, payment_status, category)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'CONFIRMED', ?, ?, ?, ?)`,
        [
          orderCode, user_id, location, date, slot,
          subtotal, serviceCharge, total,
          payment_method, payment_id || "",
          latitude || null, longitude || null,
          isPaid ? "PAID" : "PENDING",
          category,
        ]
      );
      const orderId = orderRes.insertId;

      for (const item of groupItems) {
        await conn.query(
          `INSERT INTO order_items (order_id, service_id, quantity, price) VALUES (?, ?, 1, ?)`,
          [orderId, item.service_id, item.price]
        );

        // Attach pre-uploaded documents to this order
        await conn.query(
          `UPDATE booking_documents SET order_id = ?
           WHERE user_id = ? AND service_id = ? AND order_id IS NULL`,
          [orderId, user_id, item.service_id]
        );
      }

      createdOrders.push({ orderId, orderCode, category, subtotal, serviceCharge, total });
    }

    await conn.commit();
    res.json({ success: true, message: "Order placed successfully", orders: createdOrders });

    // Background: send confirmation emails
    setImmediate(async () => {
      try {
        const [[user]] = await db.query(
          `SELECT first_name, email, fcm_token FROM users WHERE id = ?`,
          [user_id]
        );
        const dateStr = fmtDate(date);
        for (const ord of createdOrders) {
          const serviceName = await getServiceName(ord.orderId);
          await sendBookingConfirmedToUser({ user, order: ord, serviceName, dateStr, slot, payment_method });
          await sendBookingAlertToCaretakers({ order: ord, serviceName, dateStr, slot, location });
        }
      } catch (err) {
        console.error("BACKGROUND EMAIL ERROR:", err);
      }
    });
  } catch (err) {
    if (conn) await conn.rollback();
    console.error(err);
    return res.status(500).json({ success: false, message: "Failed to place order" });
  } finally {
    if (conn) conn.release();
  }
});

/* =========================================
   POST /orders/:orderId/cancel
========================================= */
router.post("/:orderId/cancel", async (req, res) => {
  try {
    const { orderId } = req.params;
    const { reason }  = req.body;

    const [[order]] = await db.query(`SELECT * FROM orders WHERE id = ?`, [orderId]);
    if (!order) return res.status(404).json({ success: false, message: "Order not found" });
    if (["COMPLETED", "CANCELLED"].includes(order.status))
      return res.status(400).json({ success: false, message: "Order cannot be cancelled." });

    const { refundAmount, refundPercent, eligible } = computeRefund(order);

    await db.query(
      `UPDATE orders SET status='CANCELLED', cancel_reason=?, cancelled_at=NOW(),
       refund_amount=?, refund_status=? WHERE id=?`,
      [reason || "", refundAmount, eligible ? "PENDING" : "NOT_ELIGIBLE", orderId]
    );

    if (eligible && refundAmount > 0) {
      await db.query(
        `INSERT INTO refund_requests
         (order_id, user_id, payment_id, refund_amount, refund_percent, status, requested_at)
         VALUES (?, ?, ?, ?, ?, 'PENDING', NOW())`,
        [order.id, order.user_id, order.payment_id, refundAmount, refundPercent]
      );
    }

    res.json({
      success: true,
      message: "Order cancelled successfully.",
      refund: {
        eligible,
        refundAmount,
        refundPercent,
        method: order.payment_method,
        note: !eligible
          ? (order.payment_method === "COD"
              ? "COD orders are not eligible for refund."
              : "Refund not applicable — service time has already passed.")
          : `₹${refundAmount.toFixed(0)} (${refundPercent}%) of service amount will be refunded after admin approval. Service charge is non-refundable.`,
      },
    });

    setImmediate(async () => {
      try { await sendCancellationNotifications(order); } catch (_) {}
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Cancellation failed" });
  }
});

/* =========================================
   GET /orders/admin/refunds
========================================= */
router.get("/admin/refunds", async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT rr.*, o.order_code, o.subtotal, o.service_charge, o.total, o.payment_method,
              o.payment_id AS order_payment_id, o.date, o.slot, o.cancel_reason, o.cancelled_at,
              u.first_name, u.email, u.mobile
       FROM refund_requests rr
       JOIN orders o ON o.id = rr.order_id
       JOIN users  u ON u.id = rr.user_id
       ORDER BY rr.requested_at DESC`
    );
    return res.json({ success: true, refunds: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =========================================
   POST /orders/admin/refunds/:id/approve
========================================= */
router.post("/admin/refunds/:id/approve", async (req, res) => {
  try {
    const [[refund]] = await db.query(`SELECT * FROM refund_requests WHERE id = ?`, [req.params.id]);
    if (!refund) return res.status(404).json({ success: false, message: "Not found" });
    if (refund.status !== "PENDING")
      return res.status(400).json({ success: false, message: "Already processed." });

    const rzRefund = await razorpay.payments.refund(refund.payment_id, {
      amount: Math.round(refund.refund_amount * 100),
      speed:  "optimum",
      notes:  { order_id: refund.order_id.toString(), reason: "Cancellation refund" },
    });

    await db.query(
      `UPDATE refund_requests SET status='APPROVED', razorpay_refund_id=?, processed_at=NOW() WHERE id=?`,
      [rzRefund.id, refund.id]
    );
    await db.query(`UPDATE orders SET refund_status='REFUNDED' WHERE id=?`, [refund.order_id]);

    return res.json({
      success: true,
      message: `Refund of ₹${refund.refund_amount} initiated.`,
      razorpay_refund_id: rzRefund.id,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Refund failed: " + err.message });
  }
});

/* =========================================
   POST /orders/admin/refunds/:id/reject
========================================= */
router.post("/admin/refunds/:id/reject", async (req, res) => {
  try {
    const { reason } = req.body;
    await db.query(
      `UPDATE refund_requests SET status='REJECTED', reject_reason=?, processed_at=NOW() WHERE id=?`,
      [reason || "", req.params.id]
    );
    await db.query(
      `UPDATE orders o JOIN refund_requests rr ON rr.order_id = o.id
       SET o.refund_status = 'REJECTED' WHERE rr.id = ?`,
      [req.params.id]
    );
    return res.json({ success: true, message: "Refund rejected." });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Rejection failed." });
  }
});

module.exports = router;