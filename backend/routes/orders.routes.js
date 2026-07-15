const router = require("express").Router();
const db     = require("../config/db");

const {
  sendBookingConfirmedToUser,
  sendBookingAlertToCaretakers,
  sendCancellationNotifications,
  sendRescheduleConfirmation,
} = require("../services/notificationEmail.service");

const {
  sendReschedulePush,
} = require("../services/pushNotification.service");

const rateLimit = require("express-rate-limit");

const rescheduleLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { success: false, message: "Too many reschedule attempts. Please try again later." },
});

/* =====================================================
   HELPERS
===================================================== */

const generateOrderCode = () => {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "ORD-";
  for (let i = 0; i < 6; i++)
    code += chars[Math.floor(Math.random() * chars.length)];
  return code;
};

// ✅ NEW — 4-digit Service OTP, shown to the careseeker and later verified
// by the caretaker on-site (Phase 1: generate + display only).
const generateOtp = () => {
  // Math.floor(1000 + rand*9000) always yields a 4-digit number (1000-9999),
  // so no leading-zero padding is needed.
  return Math.floor(1000 + Math.random() * 9000).toString();
};

const fmtDate = (d) =>
  d
    ? new Date(d).toLocaleDateString("en-IN", {
        day: "2-digit",
        month: "short",
        year: "numeric",
      })
    : "";

const getServiceName = async (orderId) => {
  const [rows] = await db.query(
    `SELECT s.name
     FROM services s
     JOIN order_items oi ON oi.service_id = s.id
     WHERE oi.order_id = ?`,
    [orderId]
  );
  return rows.map((r) => r.name).join(", ") || "Service";
};

// Refund computed on subtotal only — service_charge is non-refundable
const computeRefund = (order) => {
  if (
    order.payment_method !== "ONLINE" ||
    order.payment_status !== "PAID"
  )
    return { refundAmount: 0, refundPercent: 0, eligible: false };

  const slotDt  = new Date(`${order.date.toISOString().split("T")[0]}T${order.slot}`);
  const diffHrs = (slotDt - new Date()) / (1000 * 60 * 60);
  const subtotal = parseFloat(order.subtotal ?? order.total);

  if (diffHrs >= 3)
    return { refundAmount: subtotal,       refundPercent: 100, eligible: true };
  if (diffHrs >  0)
    return { refundAmount: subtotal * 0.5, refundPercent: 50,  eligible: true };

  return { refundAmount: 0, refundPercent: 0, eligible: false };
};

/* =====================================================
   GET /orders/:userId
===================================================== */

router.get("/:userId", async (req, res) => {
  try {
    const [orders] = await db.query(
      `SELECT o.*, o.subtotal, o.service_charge,
              GROUP_CONCAT(s.name SEPARATOR ', ') AS service_names
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       LEFT JOIN services    s  ON s.id = oi.service_id
       WHERE o.user_id = ?
       GROUP BY o.id
       ORDER BY o.id DESC`,
      [req.params.userId]
    );
    return res.json(orders);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   GET /orders/detail/:id
===================================================== */

router.get("/detail/:id", async (req, res) => {
  try {
    const [[order]] = await db.query(
      `SELECT o.*, o.subtotal, o.service_charge,
              o.otp, o.otp_verified, o.otp_created_at,
              o.otp_used_at, o.otp_expired,
              GROUP_CONCAT(s.name SEPARATOR ', ') AS service_names,
              ct.first_name         AS caregiver_name,
              ct.mobile             AS caregiver_phone,
              ct.approval_status    AS caregiver_approval_status,
              ct.documents_uploaded AS caregiver_documents_uploaded,
              CASE WHEN f.id IS NOT NULL THEN 1 ELSE 0 END AS feedback_given,
              f.rating   AS feedback_rating,
              f.feedback AS feedback_text
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       LEFT JOIN services    s  ON s.id = oi.service_id
       LEFT JOIN users       ct ON ct.id = o.caretaker_id
       LEFT JOIN feedback    f  ON f.order_id = o.id
       WHERE o.id = ?
       GROUP BY o.id`,
      [req.params.id]
    );
    if (!order)
      return res.status(404).json({ success: false, message: "Order not found" });

    return res.json({ success: true, order });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   POST /orders/place
===================================================== */

router.post("/place", async (req, res) => {
  let conn;
  try {
    const {
      user_id,
      location,
      date,
      slot,
      payment_method,
      payment_id,
      latitude,
      longitude,
      items,
      service_charge,
      coupon_code,      // ← now read from Flutter
    } = req.body;

    if (!items?.length)
      return res
        .status(400)
        .json({ success: false, message: "No services selected" });

    let serviceCharge = parseFloat(service_charge ?? -1);
    if (isNaN(serviceCharge) || serviceCharge < 0) {
      const [[settings]] = await db
        .query(`SELECT service_charge FROM admin_settings LIMIT 1`)
        .catch(() => [[{ service_charge: 0 }]]);
      serviceCharge = parseFloat(settings?.service_charge ?? 0);
    }

    const cartSubtotal = items.reduce((s, i) => s + parseFloat(i.price), 0);

    // ── SERVER-SIDE COUPON VALIDATION ──────────────────────────────────────
    // Never trust a client-sent discount amount — recompute it here.
    let appliedCoupon = null;
    let totalDiscount = 0;

    if (coupon_code) {
      const [[coupon]] = await db.query(
        `SELECT * FROM coupons WHERE code = ? AND is_active = 1`,
        [coupon_code.trim().toUpperCase()]
      );

      if (coupon) {
        const now = new Date();
        const notStarted = coupon.start_time && now < new Date(coupon.start_time);
        const expired     = coupon.end_time   && now > new Date(coupon.end_time);
        const belowMin    = cartSubtotal < (coupon.min_order || 0);

        let usedByUser = 0;
        if (coupon.per_user_limit) {
          const [[row]] = await db.query(
            `SELECT COUNT(*) AS cnt FROM orders
             WHERE user_id = ? AND coupon_code = ? AND status != 'CANCELLED'`,
            [user_id, coupon.code]
          );
          usedByUser = row.cnt;
        }
        const overUserLimit  = coupon.per_user_limit && usedByUser >= coupon.per_user_limit;
        const overUsageLimit = coupon.usage_limit && coupon.used_count >= coupon.usage_limit;

        if (!notStarted && !expired && !belowMin && !overUserLimit && !overUsageLimit) {
          let discount = coupon.discount_type === "percentage"
            ? (cartSubtotal * coupon.discount) / 100
            : coupon.discount;

          if (coupon.max_discount) discount = Math.min(discount, coupon.max_discount);
          discount = Math.min(discount, cartSubtotal); // never exceed subtotal

          totalDiscount = discount;
          appliedCoupon = coupon;
        } else {
          console.warn(`⚠️ Coupon ${coupon_code} rejected:`, {
            notStarted, expired, belowMin, overUserLimit, overUsageLimit,
          });
        }
      }
    }

    console.log(`💰 service_charge: ${serviceCharge}, discount: ${totalDiscount} (coupon: ${appliedCoupon?.code || "none"})`);

    conn = await db.getConnection();
    await conn.beginTransaction();

    const grouped = {};
    for (const item of items) {
      const cat = item.category || "Nurse";
      (grouped[cat] = grouped[cat] || []).push(item);
    }

    const createdOrders = [];
    let discountRemaining = totalDiscount;
    const groupKeys = Object.keys(grouped);

    for (let gi = 0; gi < groupKeys.length; gi++) {
      const category   = groupKeys[gi];
      const groupItems = grouped[category];
      const orderCode  = generateOrderCode();
      const subtotal   = groupItems.reduce((s, i) => s + parseFloat(i.price), 0);

      // Split discount proportionally across grouped orders; dump the
      // rounding remainder into the last group so amounts add up exactly.
      let groupDiscount;
      if (gi === groupKeys.length - 1) {
        groupDiscount = discountRemaining;
      } else {
        groupDiscount = cartSubtotal > 0
          ? Math.round((subtotal / cartSubtotal) * totalDiscount * 100) / 100
          : 0;
        discountRemaining -= groupDiscount;
      }

      const total = Math.max(0, subtotal + serviceCharge - groupDiscount);
      const isPaid = payment_method === "ONLINE" && !!payment_id;

      const serviceIds = groupItems.map((item) => item.service_id);
      const [requiredServices] = await conn.query(
        `SELECT id, name FROM services WHERE id IN (?) AND requires_documents = 1`,
        [serviceIds]
      );

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

      // ✅ NEW — one Service OTP per created order (each grouped order gets
      // its own OTP, since a careseeker could have multiple caretakers).
      const otp = generateOtp();

      const [orderRes] = await conn.query(
        `INSERT INTO orders
         (order_code, user_id, location, date, slot,
          subtotal, service_charge, discount_amount, coupon_code, total,
          payment_method, payment_id,
          status, latitude, longitude,
          payment_status, category,
          otp, otp_verified, otp_created_at, otp_expired)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'CONFIRMED', ?, ?, ?, ?, ?, 0, NOW(), 0)`,
        [
          orderCode,
          user_id,
          location,
          date,
          slot,
          subtotal,
          serviceCharge,
          groupDiscount,
          appliedCoupon ? appliedCoupon.code : null,
          total,
          payment_method,
          payment_id || "",
          latitude  || null,
          longitude || null,
          isPaid ? "PAID" : "PENDING",
          category,
          otp,
        ]
      );
      const orderId = orderRes.insertId;

      for (const item of groupItems) {
        await conn.query(
          `INSERT INTO order_items (order_id, service_id, quantity, price)
           VALUES (?, ?, 1, ?)`,
          [orderId, item.service_id, item.price]
        );
        await conn.query(
          `UPDATE booking_documents SET order_id = ?
           WHERE user_id = ? AND service_id = ? AND order_id IS NULL`,
          [orderId, user_id, item.service_id]
        );
      }

      const serviceNamesForOrder =
        groupItems.map((i) => i.name || i.service_name).filter(Boolean).join(", ") ||
        category;

      createdOrders.push({
        order_id:      orderId,
        order_code:    orderCode,
        category,
        subtotal,
        service_charge: serviceCharge,
        discount:      groupDiscount,
        total,
        service_name:  serviceNamesForOrder,
        otp,                    // ✅ NEW — returned so the app can show it immediately
      });
    }

    // Bump usage count once, for the whole checkout — not per grouped order
    if (appliedCoupon) {
      await conn.query(
        `UPDATE coupons SET used_count = used_count + 1 WHERE id = ?`,
        [appliedCoupon.id]
      );
    }

    await conn.commit();

    res.json({
      success: true,
      message: "Order placed successfully",
      orders: createdOrders,
      discount_applied: totalDiscount,
      coupon_code: appliedCoupon?.code || null,
    });

    setImmediate(async () => {
      try {
        const [[user]] = await db.query(
          `SELECT first_name, email, fcm_token FROM users WHERE id = ?`,
          [user_id]
        );
        const dateStr = fmtDate(date);
        for (const ord of createdOrders) {
          const serviceName = ord.service_name || (await getServiceName(ord.order_id));
          await sendBookingConfirmedToUser({
            user, order: ord, bookingId: ord.order_code,
            serviceName, dateStr, slot, payment_method,
          });
          await sendBookingAlertToCaretakers({
            order: ord, bookingId: ord.order_code,
            serviceName, dateStr, slot, location,
          });
        }
      } catch (err) {
        console.error("BACKGROUND EMAIL ERROR:", err);
      }
    });
  } catch (err) {
    if (conn) await conn.rollback();
    console.error(err);
    return res
      .status(500)
      .json({ success: false, message: "Failed to place order" });
  } finally {
    if (conn) conn.release();
  }
});
/* =====================================================
   POST /orders/:orderId/cancel
===================================================== */

router.post("/:orderId/cancel", async (req, res) => {
  try {
    const { orderId } = req.params;
    const { reason }  = req.body;

    const [[order]] = await db.query(
      `SELECT * FROM orders WHERE id = ?`,
      [orderId]
    );
    if (!order)
      return res
        .status(404)
        .json({ success: false, message: "Order not found" });

    if (["COMPLETED", "CANCELLED"].includes(order.status))
      return res
        .status(400)
        .json({ success: false, message: "Order cannot be cancelled." });

    const { refundAmount, refundPercent, eligible } =
      computeRefund(order);

    await db.query(
      `UPDATE orders
       SET status        = 'CANCELLED',
           cancel_reason = ?,
           cancelled_at  = NOW(),
           refund_amount = ?,
           refund_status = ?,
           otp_expired   = 1
       WHERE id = ?`,
      [
        reason || "",
        refundAmount,
        eligible ? "PENDING" : "NOT_ELIGIBLE",
        orderId,
      ]
    );

    if (eligible && refundAmount > 0) {
      await db.query(
        `INSERT INTO refund_requests
         (order_id, user_id, payment_id,
          refund_amount, refund_percent, status, requested_at)
         VALUES (?, ?, ?, ?, ?, 'PENDING', NOW())`,
        [
          order.id,
          order.user_id,
          order.payment_id,
          refundAmount,
          refundPercent,
        ]
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
          ? order.payment_method === "COD"
            ? "COD orders are not eligible for refund."
            : "Refund not applicable — service time has already passed."
          : `₹${refundAmount.toFixed(0)} (${refundPercent}%) of service amount will be refunded after admin approval. Service charge is non-refundable.`,
      },
    });

    setImmediate(async () => {
      try {
        await sendCancellationNotifications(order);
      } catch (_) {}
    });
  } catch (err) {
    console.error(err);
    return res
      .status(500)
      .json({ success: false, message: "Cancellation failed" });
  }
});

/* =====================================================
   GET /orders/:orderId/available-slots?date=YYYY-MM-DD
   Pulls from the admin-managed service_slots table.
===================================================== */

router.get("/:orderId/available-slots", async (req, res) => {
  try {
    const { orderId } = req.params;
    const { date } = req.query;

    if (!date)
      return res.status(400).json({ success: false, message: "Date is required" });

    const [[order]] = await db.query(
      `SELECT id, status FROM orders WHERE id = ?`,
      [orderId]
    );

    if (!order)
      return res.status(404).json({ success: false, message: "Order not found" });

    if (order.status !== "CONFIRMED")
      return res.status(400).json({
        success: false,
        message: "This booking can no longer be rescheduled.",
      });

    const [rows] = await db.query(
      `SELECT id, slot_time
       FROM service_slots
       WHERE slot_date = ? AND status = 'available'
       ORDER BY slot_time ASC`,
      [date]
    );

    // Filter out past times if the chosen date is today
    const now      = new Date();
    const isToday  = date === now.toISOString().split("T")[0];

    const slots = rows
      .map((r) => {
        const hhmm = r.slot_time.toString().slice(0, 5); // "09:00:00" -> "09:00"
        return { id: r.id, slot_time: hhmm };
      })
      .filter((s) => {
        if (!isToday) return true;
        const [h, m] = s.slot_time.split(":").map(Number);
        const slotDt = new Date();
        slotDt.setHours(h, m, 0, 0);
        return slotDt > now;
      });

    return res.json({ success: true, slots });
  } catch (err) {
    console.error("AVAILABLE SLOTS ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to fetch slots" });
  }
});

/* =====================================================
   POST /orders/:orderId/reschedule
   Body: { date, slot_id }
===================================================== */

const MAX_RESCHEDULES   = 3;   // total reschedules allowed per booking
const MIN_NOTICE_HOURS  = 2;   // can't reschedule within X hrs of current slot
const COOLDOWN_MINUTES  = 5;   // gap required between consecutive reschedules

router.post("/:orderId/reschedule", rescheduleLimiter, async (req, res) => {
  let conn;
  try {
    const { orderId } = req.params;
    const { date, slot_id } = req.body;

    if (!date || !slot_id)
      return res.status(400).json({ success: false, message: "Date and slot are required" });

    conn = await db.getConnection();
    await conn.beginTransaction();

    const [[order]] = await conn.query(
      `SELECT * FROM orders WHERE id = ? FOR UPDATE`,
      [orderId]
    );

    if (!order) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: "Order not found" });
    }

    // ── Ownership check ──────────────────────────────────────────────
    // TODO: wire this to your auth middleware once available.
    // If you attach the logged-in user to req.user (e.g. via JWT
    // middleware), uncomment this block — it's the single most
    // important guard on this route, since right now anyone who
    // knows an orderId can reschedule someone else's booking.
    //
    // if (order.user_id !== req.user.id) {
    //   await conn.rollback();
    //   return res.status(403).json({ success: false, message: "Not authorized to modify this booking." });
    // }

    if (order.status !== "CONFIRMED") {
      await conn.rollback();
      return res.status(400).json({
        success: false,
        message: "Booking can't be rescheduled — a caretaker has already accepted it. Please contact support.",
      });
    }

    if (order.reschedule_count >= MAX_RESCHEDULES) {
      await conn.rollback();
      return res.status(400).json({
        success: false,
        message: `This booking has already been rescheduled ${MAX_RESCHEDULES} times. Please contact support for further changes.`,
      });
    }

    // ── Cooldown between reschedules ────────────────────────────────
    if (order.last_rescheduled_at) {
      const minsSinceLast = (new Date() - new Date(order.last_rescheduled_at)) / 60000;
      if (minsSinceLast < COOLDOWN_MINUTES) {
        await conn.rollback();
        return res.status(429).json({
          success: false,
          message: `Please wait a few minutes before rescheduling again.`,
        });
      }
    }

    // ── Minimum notice before current slot ──────────────────────────
    const currentSlotDt = new Date(
      `${order.date.toISOString().split("T")[0]}T${order.slot}`
    );
    const hoursUntilCurrentSlot = (currentSlotDt - new Date()) / (1000 * 60 * 60);

    if (hoursUntilCurrentSlot < MIN_NOTICE_HOURS) {
      await conn.rollback();
      return res.status(400).json({
        success: false,
        message: `Bookings can't be rescheduled less than ${MIN_NOTICE_HOURS} hours before the scheduled time. Please contact support.`,
      });
    }

    // ── Lock and re-validate the target slot ────────────────────────
    const [[targetSlot]] = await conn.query(
      `SELECT * FROM service_slots WHERE id = ? AND slot_date = ? FOR UPDATE`,
      [slot_id, date]
    );

    if (!targetSlot) {
      await conn.rollback();
      return res.status(400).json({ success: false, message: "Selected slot no longer exists." });
    }

    if (targetSlot.status !== "available") {
      await conn.rollback();
      return res.status(400).json({ success: false, message: "That slot was just taken. Please pick another." });
    }

    const hhmm = targetSlot.slot_time.toString().slice(0, 5); // "09:00"

    // ── Free the previously held slot (if tracked in service_slots) ──
    await conn.query(
      `UPDATE service_slots
       SET status = 'available', order_id = NULL
       WHERE order_id = ? AND status = 'booked'`,
      [orderId]
    );

    // ── Book the new slot ────────────────────────────────────────────
    await conn.query(
      `UPDATE service_slots SET status = 'booked', order_id = ? WHERE id = ?`,
      [orderId, slot_id]
    );

    // ── Update the order itself ─────────────────────────────────────
    const isFirstReschedule = order.reschedule_count === 0;

    await conn.query(
      `UPDATE orders
       SET date = ?,
           slot = ?,
           reschedule_count = reschedule_count + 1,
           last_rescheduled_at = NOW(),
           original_date = ${isFirstReschedule ? "?" : "original_date"},
           original_slot = ${isFirstReschedule ? "?" : "original_slot"}
       WHERE id = ?`,
      isFirstReschedule
        ? [date, hhmm, order.date, order.slot, orderId]
        : [date, hhmm, orderId]
    );

    // ── Audit log entry ──────────────────────────────────────────────
    await conn.query(
      `INSERT INTO reschedule_log (order_id, old_date, old_slot, new_date, new_slot)
       VALUES (?, ?, ?, ?, ?)`,
      [orderId, order.date, order.slot, date, hhmm]
    );

    await conn.commit();

    res.json({
      success: true,
      message: "Booking rescheduled successfully",
      order: { id: orderId, date, slot: hhmm },
      reschedules_remaining: MAX_RESCHEDULES - (order.reschedule_count + 1), // ✅ NEW — for UI display
    });

    setImmediate(async () => {
      try {
        const [[user]] = await db.query(
          `SELECT first_name, email, fcm_token FROM users WHERE id = ?`,
          [order.user_id]
        );

        await sendRescheduleConfirmation({
          user,
          order: { order_code: order.order_code },
          newDate: date,
          newSlot: hhmm,
          oldDate: order.date,
          oldSlot: order.slot,
        });

        await sendReschedulePush({
          fcmToken: user?.fcm_token,
          orderCode: order.order_code,
          newDate: date,
          newSlot: hhmm,
        });
      } catch (err) {
        console.error("RESCHEDULE NOTIFICATION ERROR:", err);
      }
    });
  } catch (err) {
    if (conn) await conn.rollback();
    console.error("RESCHEDULE ERROR:", err);
    return res.status(500).json({ success: false, message: "Reschedule failed" });
  } finally {
    if (conn) conn.release();
  }
});

/* =====================================================
   GET /orders/admin/refunds
===================================================== */

router.get("/admin/refunds", async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT rr.*,
              o.order_code, o.subtotal, o.service_charge, o.total,
              o.payment_method,
              o.payment_id AS order_payment_id,
              o.date, o.slot, o.cancel_reason, o.cancelled_at,
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

/* =====================================================
   POST /orders/admin/refunds/:id/approve
===================================================== */

router.post("/admin/refunds/:id/approve", async (req, res) => {
  try {
    const [[refund]] = await db.query(
      `SELECT * FROM refund_requests WHERE id = ?`,
      [req.params.id]
    );

    if (!refund)
      return res
        .status(404)
        .json({ success: false, message: "Not found" });

    if (refund.status !== "PENDING")
      return res
        .status(400)
        .json({ success: false, message: "Already processed." });

    await db.query(
      `UPDATE refund_requests
       SET status = 'APPROVED', processed_at = NOW()
       WHERE id = ?`,
      [refund.id]
    );

    await db.query(
      `UPDATE orders SET refund_status = 'REFUNDED' WHERE id = ?`,
      [refund.order_id]
    );

    return res.json({
      success: true,
      message: `Refund of ₹${refund.refund_amount} marked as approved. Please process manually via Cashfree dashboard.`,
    });
  } catch (err) {
    console.error(err);
    return res
      .status(500)
      .json({ success: false, message: "Refund approval failed" });
  }
});

/* =====================================================
   POST /orders/admin/refunds/:id/reject
===================================================== */

router.post("/admin/refunds/:id/reject", async (req, res) => {
  try {
    const { reason } = req.body;

    await db.query(
      `UPDATE refund_requests
       SET status = 'REJECTED', reject_reason = ?, processed_at = NOW()
       WHERE id = ?`,
      [reason || "", req.params.id]
    );

    await db.query(
      `UPDATE orders o
       JOIN refund_requests rr ON rr.order_id = o.id
       SET o.refund_status = 'REJECTED'
       WHERE rr.id = ?`,
      [req.params.id]
    );

    return res.json({ success: true, message: "Refund rejected." });
  } catch (err) {
    console.error(err);
    return res
      .status(500)
      .json({ success: false, message: "Rejection failed." });
  }
});

module.exports = router;