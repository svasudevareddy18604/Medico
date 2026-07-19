const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const { sendPushNotification } = require("../services/pushNotification.service");

/* ═══════════════════════════════════════════════════════════
   GET /caretaker/order-detail/:id
   ✅ Includes otp, otp_verified, caretaker_latitude/longitude
      (required by the Flutter order details + tracking screens)
   ✅ Keeps the "latest doc per document_key" dedup logic
═══════════════════════════════════════════════════════════ */
router.get("/order-detail/:id", async (req, res) => {
  try {
    const [[order]] = await db.query(`
      SELECT o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.total, o.payment_method, o.payment_status,
             o.payment_id, o.status, o.caretaker_id, o.assigned_caretaker_id,
             o.otp, o.otp_verified, o.otp_verified_at,
             o.caretaker_latitude, o.caretaker_longitude,
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
      GROUP BY o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.total, o.payment_method, o.payment_status,
               o.payment_id, o.status, o.caretaker_id, o.assigned_caretaker_id,
               o.otp, o.otp_verified, o.otp_verified_at,
               o.caretaker_latitude, o.caretaker_longitude,
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
      SELECT o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.total, o.payment_method, o.payment_status,
             o.status, o.caretaker_id,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.status = 'CONFIRMED' AND o.caretaker_id IS NULL
      GROUP BY o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
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
      SELECT o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.total, o.payment_method, o.payment_status,
             o.status, o.caretaker_id,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.status = 'CONFIRMED' AND o.caretaker_id IS NULL AND o.category = ?
      GROUP BY o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
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

    const [[targetOrder]] = await db.query(
      `SELECT id, date, slot, category, status FROM orders WHERE id = ?`,
      [order_id]
    );
    if (!targetOrder)
      return res.json({ success: false, message: "Order not found" });

    // Slot conflict check — caretaker can't hold two active bookings at the same time
    const [[slotConflict]] = await db.query(
      `SELECT id FROM orders
       WHERE caretaker_id = ? AND date = ? AND slot = ?
         AND status IN ('ACCEPTED', 'ON_THE_WAY')
       LIMIT 1`,
      [caretaker_id, targetOrder.date, targetOrder.slot]
    );
    if (slotConflict)
      return res.json({ success: false, message: "You already accepted another booking for this slot" });

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

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/cancel
═══════════════════════════════════════════════════════════ */
router.post("/cancel", async (req, res) => {
  try {
    const { order_id, caretaker_id, cancel_reason } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    const [[order]] = await db.query(`SELECT * FROM orders WHERE id = ?`, [order_id]);
    if (!order) return res.json({ success: false, message: "Order not found" });
    if (Number(order.caretaker_id) !== Number(caretaker_id))
      return res.json({ success: false, message: "Unauthorized" });
    if (order.status === "COMPLETED")
      return res.json({ success: false, message: "Completed order cannot be cancelled" });

    const isOnlinePaid = order.payment_method !== "COD" && order.payment_status === "PAID";

    if (isOnlinePaid) {
      await db.query(
        `UPDATE orders SET status='CARETAKER_CANCELLED', cancel_reason=?, cancelled_at=NOW() WHERE id=?`,
        [cancel_reason || "Cancelled by caretaker", order_id]
      );
    } else {
      await db.query(
        `UPDATE orders
         SET caretaker_id=NULL, assigned_caretaker_id=NULL, status='CONFIRMED',
             accepted_at=NULL, cancel_reason=?, cancelled_at=NOW()
         WHERE id=?`,
        [cancel_reason || "Cancelled by caretaker", order_id]
      );
    }

    res.json({
      success: true,
      message: isOnlinePaid
        ? "Paid booking flagged for admin reassignment"
        : "Booking cancelled and reopened successfully",
    });
  } catch (err) {
    console.error("CANCEL ERROR:", err);
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

    // ✅ FIXED — no longer overwrites status. Payment and journey status
    // are independent; forcing status here used to fight with /start
    // and /complete over which status the order should be in.
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

/* ═══════════════════════════════════════════════════════════
   PUT /caretaker/profile/availability/:id
═══════════════════════════════════════════════════════════ */
router.put("/profile/availability/:id", async (req, res) => {
  const { id } = req.params;
  const { is_available } = req.body;

  try {
    const [[profile]] = await db.query(
      "SELECT availability_locked FROM caretaker_profiles WHERE user_id = ?",
      [id]
    );
    if (!profile)
      return res.status(404).json({ success: false, message: "Profile not found" });

    if (profile.availability_locked === 1) {
      return res.status(403).json({
        success: false,
        message: "Your availability is locked by admin. Contact admin to reactivate.",
        locked: true,
      });
    }

    const newVal = Number(is_available) === 1 ? 1 : 0;
    const tsCol  = newVal ? "last_available_at" : "last_unavailable_at";

    await db.query(
      `UPDATE caretaker_profiles SET is_available = ?, ${tsCol} = NOW() WHERE user_id = ?`,
      [newVal, id]
    );

    await db.query(
      `INSERT INTO caregiver_daily_status (caregiver_id, status_date, is_available)
       VALUES (?, CURDATE(), ?)
       ON DUPLICATE KEY UPDATE is_available = VALUES(is_available)`,
      [id, newVal]
    );

    res.json({ success: true, message: newVal ? "You are now available" : "You are now unavailable" });
  } catch (err) {
    console.error("TOGGLE AVAILABILITY ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/start
   ✅ FIXED — sets 'ON_THE_WAY' (was 'IN_PROGRESS', which never
      matched the Flutter app's status checks, so tracking never
      showed up and the "On The Way" step never activated).
   ✅ FIXED — no longer requires payment_status='PAID'. COD orders
      pay AFTER service, so requiring payment upfront blocked every
      COD caretaker from ever starting the journey.
═══════════════════════════════════════════════════════════ */
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
      return res.json({ success: false, message: "Order not found, not accepted, or already started" });

    const [[order]] = await db.query(`
      SELECT o.order_code, o.category, u.fcm_token
      FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?
    `, [order_id]);

    if (order?.fcm_token)
      sendPushNotification(order.fcm_token, "Caretaker On The Way 🚗",
        `Your caretaker for ${order.category} service (${order.order_code}) is on the way.`);

    res.json({ success: true, message: "Caretaker journey started successfully" });
  } catch (err) {
    console.error("START ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/update-location
   ✅ ADDED — this route was completely missing from this file,
      so every location ping from _startLiveTracking() was 404ing
      silently and the careseeker's live map never got coordinates.
═══════════════════════════════════════════════════════════ */
router.post("/update-location", async (req, res) => {
  try {
    const { order_id, caretaker_id, latitude, longitude } = req.body;

    if (!order_id || !caretaker_id || latitude == null || longitude == null) {
      return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    const [result] = await db.query(
      `UPDATE orders
       SET caretaker_latitude = ?, caretaker_longitude = ?
       WHERE id = ? AND caretaker_id = ? AND status = 'ON_THE_WAY'`,
      [latitude, longitude, order_id, caretaker_id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: "Order not active" });
    }

    res.json({ success: true, message: "Location updated" });
  } catch (err) {
    console.error("UPDATE LOCATION ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/verify-otp
   ✅ ADDED — this route was completely missing from this file,
      so CaretakerOtpScreen's verify call always 404'd and
      otp_verified could never flip to 1.
═══════════════════════════════════════════════════════════ */
router.post("/verify-otp", async (req, res) => {
  try {
    const { order_id, caretaker_id, otp } = req.body;

    if (!order_id || !caretaker_id || !otp) {
      return res.status(400).json({ success: false, message: "Missing order_id, caretaker_id or otp" });
    }

    const [[order]] = await db.query(
      `SELECT id, otp, otp_verified, status, caretaker_id FROM orders WHERE id = ?`,
      [order_id]
    );

    if (!order) return res.json({ success: false, message: "Order not found" });
    if (Number(order.caretaker_id) !== Number(caretaker_id))
      return res.json({ success: false, message: "Unauthorized" });
    if (order.status !== "ON_THE_WAY")
      return res.json({ success: false, message: `Cannot verify OTP — order is ${order.status}` });
    if (order.otp_verified === 1)
      return res.json({ success: true, message: "OTP already verified" });
    if (!order.otp || String(order.otp) !== String(otp))
      return res.json({ success: false, message: "Invalid OTP" });

    await db.query(
      `UPDATE orders SET otp_verified = 1, otp_verified_at = NOW() WHERE id = ?`,
      [order_id]
    );

    res.json({ success: true, message: "OTP verified successfully" });
  } catch (err) {
    console.error("VERIFY OTP ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/complete
   ✅ FIXED — status check now uses 'ON_THE_WAY' (was matching
      'IN_PROGRESS', which is never actually set anymore).
   ✅ FIXED — now requires otp_verified = 1, consistent with the
      Flutter CTA logic (_ctaAction only offers "Complete Service"
      after OTP verification + payment).
═══════════════════════════════════════════════════════════ */
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
    if (order.status !== "ON_THE_WAY") {
      await connection.rollback();
      return res.json({ success: false, message: `Cannot complete — order is ${order.status}` });
    }
    if (Number(order.caretaker_id) !== Number(caretaker_id)) {
      await connection.rollback();
      return res.json({ success: false, message: "Unauthorized" });
    }
    if (order.otp_verified !== 1) {
      await connection.rollback();
      return res.json({ success: false, message: "Please verify arrival OTP before completing" });
    }

    const [[existing]] = await connection.query(
      "SELECT id FROM earnings WHERE order_id=? AND caretaker_id=?", [order_id, caretaker_id]);

    if (existing) {
      await connection.query(
        "UPDATE orders SET status='COMPLETED', completed_at=NOW() WHERE id=?", [order_id]);
      await connection.commit();
      return res.json({ success: true, message: "Completed" });
    }

    const total           = Number(order.total || 0);
    const commission      = parseFloat((total * 0.20).toFixed(2));
    const caretakerAmount = parseFloat((total - commission).toFixed(2));

    await connection.query(
      "UPDATE orders SET status='COMPLETED', completed_at=NOW() WHERE id=?", [order_id]);
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
      SELECT o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.status, o.payment_status, o.total, o.payment_method,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.caretaker_id=? AND o.status != 'CANCELLED'
      GROUP BY o.id, o.user_id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.status, o.payment_status, o.total, o.payment_method
      ORDER BY o.created_at DESC
    `, [req.params.caretakerId]);

    res.json({ success: true, count: jobs.length, jobs });
  } catch (err) {
    console.error("MY JOBS ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;