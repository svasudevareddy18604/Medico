const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const { sendPushNotification } = require("../services/pushNotification.service");

/* GET /caretaker/order-detail/:id */
router.get("/order-detail/:id", async (req, res) => {
  try {
    const [[order]] = await db.query(`
      SELECT o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.total, o.payment_method, o.payment_status,
             o.payment_id, o.status, o.caretaker_id, o.assigned_caretaker_id,
             o.otp, o.otp_verified, o.otp_used_at, o.otp_created_at, o.otp_expired,
             u.first_name AS careseeker_name, u.mobile AS careseeker_phone,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services,
             GROUP_CONCAT(DISTINCT bd.file_url     ORDER BY bd.uploaded_at SEPARATOR '|||') AS document_urls,
             GROUP_CONCAT(DISTINCT bd.file_type    ORDER BY bd.uploaded_at SEPARATOR '|||') AS document_types,
             GROUP_CONCAT(DISTINCT bd.document_key ORDER BY bd.uploaded_at SEPARATOR '|||') AS document_keys
      FROM orders o
      JOIN  users u            ON u.id        = o.user_id
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      LEFT JOIN booking_documents bd
             ON bd.order_id      = o.id
            AND bd.user_id       = o.user_id
            AND bd.is_deleted    = 0
            AND bd.uploaded_at   = (
              SELECT MAX(bd2.uploaded_at)
              FROM booking_documents bd2
              WHERE bd2.order_id      = bd.order_id
                AND bd2.document_key  = bd.document_key
                AND bd2.is_deleted    = 0
            )
      WHERE o.id = ?
      GROUP BY o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.total, o.payment_method, o.payment_status,
               o.payment_id, o.status, o.caretaker_id, o.assigned_caretaker_id,
               o.otp, o.otp_verified, o.otp_used_at, o.otp_created_at, o.otp_expired,
               u.first_name, u.mobile
    `, [req.params.id]);

    if (!order) return res.status(404).json({ success: false, message: "Order not found" });
    res.json({ success: true, data: order });
  } catch (err) {
    console.error("ORDER DETAIL ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* GET /caretaker/orders */
router.get("/orders", async (req, res) => {
  try {
    const [orders] = await db.query(`
      SELECT o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.total, o.payment_method, o.payment_status,
             o.status, o.caretaker_id,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.status = 'CONFIRMED' AND o.caretaker_id IS NULL
      GROUP BY o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.total, o.payment_method, o.payment_status,
               o.status, o.caretaker_id
      ORDER BY o.created_at ASC
    `);
    res.json({ success: true, count: orders.length, orders });
  } catch (err) {
    console.error("AVAILABLE ORDERS ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* GET /caretaker/orders/:category */
router.get("/orders/:category", async (req, res) => {
  try {
    const [orders] = await db.query(`
      SELECT o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.total, o.payment_method, o.payment_status,
             o.status, o.caretaker_id,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.status = 'CONFIRMED' AND o.caretaker_id IS NULL AND o.category = ?
      GROUP BY o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.total, o.payment_method, o.payment_status,
               o.status, o.caretaker_id
      ORDER BY o.created_at ASC
    `, [req.params.category]);
    res.json({ success: true, count: orders.length, orders });
  } catch (err) {
    console.error("AVAILABLE ORDERS BY CATEGORY ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* POST /caretaker/accept */
router.post("/accept", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    const [result] = await db.query(`
      UPDATE orders o
      JOIN caretaker_profiles cp ON cp.user_id = ?
      SET o.caretaker_id          = ?,
          o.assigned_caretaker_id = ?,
          o.status                = 'ACCEPTED',
          o.accepted_at           = NOW()
      WHERE o.id              = ?
        AND o.caretaker_id   IS NULL
        AND o.status          = 'CONFIRMED'
        AND cp.caregiver_type = o.category
    `, [caretaker_id, caretaker_id, caretaker_id, order_id]);

    if (result.affectedRows === 0)
      return res.json({ success: false, message: "Already accepted or category mismatch" });

    const [[order]] = await db.query(`
      SELECT o.order_code, o.slot, o.category, u.fcm_token
      FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?
    `, [order_id]);

    if (order?.fcm_token)
      sendPushNotification(order.fcm_token, "Booking Accepted ✅",
        `Your ${order.category} service at ${order.slot} (${order.order_code}) has been accepted.`);

    res.json({ success: true, message: "Booking accepted successfully" });
  } catch (err) {
    console.error("ACCEPT ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* POST /caretaker/mark-payment-received */
router.post("/mark-payment-received", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    const [[order]] = await db.query(
      "SELECT id, payment_status, caretaker_id FROM orders WHERE id = ?", [order_id]);

    if (!order)        return res.json({ success: false, message: "Order not found" });
    if (order.payment_status === "PAID")
                       return res.json({ success: true,  message: "Already marked as paid" });
    if (Number(order.caretaker_id) !== Number(caretaker_id))
                       return res.json({ success: false, message: "Unauthorized" });

    await db.query(
      "UPDATE orders SET payment_status='PAID' WHERE id=?", [order_id]);

    const [[ord]] = await db.query(`
      SELECT o.order_code, o.category, u.fcm_token
      FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?
    `, [order_id]);

    if (ord?.fcm_token)
      sendPushNotification(ord.fcm_token, "Payment Received 💳",
        `Payment for your ${ord.category} service (${ord.order_code}) has been confirmed.`);

    res.json({ success: true, message: "Payment marked as received" });
  } catch (err) {
    console.error("MARK PAYMENT RECEIVED ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* POST /caretaker/start
   Moves the booking to ON_THE_WAY. No OTP check here — OTP is only
   verified once the caretaker has actually reached the customer. */
router.post("/start", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    const [result] = await db.query(`
      UPDATE orders SET status='ON_THE_WAY'
      WHERE id=? AND caretaker_id=?
        AND status IN ('ACCEPTED','CONFIRMED')
    `, [order_id, caretaker_id]);

    if (result.affectedRows === 0)
      return res.json({ success: false, message: "Not found or not accepted by you" });

    const [[order]] = await db.query(`
      SELECT o.order_code, o.category, u.fcm_token
      FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?
    `, [order_id]);

    if (order?.fcm_token)
      sendPushNotification(order.fcm_token, "Caretaker On The Way 🚗",
        `Your caretaker is heading to you for the ${order.category} service (${order.order_code}). Share the OTP only once they arrive.`);

    res.json({ success: true, message: "Journey started" });
  } catch (err) {
    console.error("START ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* POST /caretaker/verify-otp
   Caretaker enters the 4-digit OTP shown to the careseeker. This is the
   proof-of-arrival gate: only after this succeeds is the service treated
   as actually started, and only then does Complete Service unlock. */
router.post("/verify-otp", async (req, res) => {
  try {
    const { order_id, caretaker_id, otp } = req.body;
    if (!order_id || !caretaker_id || !otp)
      return res.status(400).json({ success: false, message: "Missing order_id, caretaker_id or otp" });

    const [[order]] = await db.query(
      `SELECT otp, otp_verified, otp_expired, caretaker_id, status
       FROM orders WHERE id = ?`,
      [order_id]
    );

    if (!order) return res.json({ success: false, message: "Order not found" });

    if (Number(order.caretaker_id) !== Number(caretaker_id))
      return res.json({ success: false, message: "Unauthorized" });

    if (!["ACCEPTED", "CONFIRMED", "ON_THE_WAY"].includes(order.status))
      return res.json({ success: false, message: `Cannot verify OTP — order is ${order.status}` });

    if (Number(order.otp_expired) === 1)
      return res.json({ success: false, message: "OTP expired" });

    if (Number(order.otp_verified) === 1)
      return res.json({ success: true, message: "OTP already verified" });

    if (String(order.otp).trim() !== String(otp).trim())
      return res.json({ success: false, message: "Invalid OTP" });

    await db.query(
      `UPDATE orders SET otp_verified = 1, otp_used_at = NOW() WHERE id = ?`,
      [order_id]
    );

    const [[ord]] = await db.query(`
      SELECT o.order_code, o.category, u.fcm_token
      FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?
    `, [order_id]);

    if (ord?.fcm_token)
      sendPushNotification(ord.fcm_token, "Caretaker Arrived ✅",
        `Your caretaker has verified the OTP and started your ${ord.category} service (${ord.order_code}).`);

    res.json({ success: true, message: "OTP verified successfully" });
  } catch (err) {
    console.error("VERIFY OTP ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* POST /caretaker/complete
   Requires: payment collected AND arrival OTP verified. */
router.post("/complete", async (req, res) => {
  const connection = await db.getConnection();
  try {
    const { order_id, caretaker_id } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    await connection.beginTransaction();

    const [[order]] = await connection.query(
      "SELECT * FROM orders WHERE id=? FOR UPDATE", [order_id]);

    if (!order) {
      await connection.rollback();
      return res.json({ success: false, message: "Order not found" });
    }
    if (order.payment_status !== "PAID") {
      await connection.rollback();
      return res.json({ success: false, message: "Payment not completed — cannot mark as done" });
    }
    if (order.status === "COMPLETED") {
      await connection.commit();
      return res.json({ success: true, message: "Already completed" });
    }
    if (!["ACCEPTED", "CONFIRMED", "ON_THE_WAY"].includes(order.status)) {
      await connection.rollback();
      return res.json({ success: false, message: `Cannot complete — order is ${order.status}` });
    }
    if (Number(order.caretaker_id) !== Number(caretaker_id)) {
      await connection.rollback();
      return res.json({ success: false, message: "Unauthorized" });
    }
    if (Number(order.otp_verified) !== 1) {
      await connection.rollback();
      return res.json({ success: false, message: "Arrival OTP not verified — cannot complete service" });
    }

    const [[existing]] = await connection.query(
      "SELECT id FROM earnings WHERE order_id=? AND caretaker_id=?", [order_id, caretaker_id]);

    if (existing) {
      await connection.query(
        "UPDATE orders SET status='COMPLETED', completed_at=NOW(), otp_expired=1 WHERE id=?", [order_id]);
      await connection.commit();
      return res.json({ success: true, message: "Completed" });
    }

    const total           = Number(order.total || 0);
    const commission      = parseFloat((total * 0.20).toFixed(2));
    const caretakerAmount = parseFloat((total - commission).toFixed(2));

    await connection.query(
      "UPDATE orders SET status='COMPLETED', completed_at=NOW(), otp_expired=1 WHERE id=?", [order_id]);
    await connection.query(`
      INSERT INTO earnings (order_id, caretaker_id, total_amount, commission, caretaker_amount, status)
      VALUES (?,?,?,?,?,'pending')
    `, [order_id, caretaker_id, total, commission, caretakerAmount]);

    await connection.commit();

    const [[ord]] = await db.query(`
      SELECT o.order_code, o.slot, o.category, u.fcm_token
      FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?
    `, [order_id]);

    if (ord?.fcm_token)
      sendPushNotification(ord.fcm_token, "Service Completed ✅",
        `Your ${ord.category} service (${ord.order_code}) has been completed. Thank you!`);

    res.json({ success: true, message: "Service completed & earnings recorded" });
  } catch (err) {
    await connection.rollback();
    console.error("COMPLETE ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

/* GET /caretaker/my-jobs/:caretakerId */
router.get("/my-jobs/:caretakerId", async (req, res) => {
  try {
    const [jobs] = await db.query(`
      SELECT o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.status, o.payment_status, o.total, o.payment_method,
             o.otp_verified,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.caretaker_id=? AND o.status != 'CANCELLED'
      GROUP BY o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.status, o.payment_status, o.total, o.payment_method,
               o.otp_verified
      ORDER BY o.created_at DESC
    `, [req.params.caretakerId]);

    res.json({ success: true, count: jobs.length, jobs });
  } catch (err) {
    console.error("MY JOBS ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;