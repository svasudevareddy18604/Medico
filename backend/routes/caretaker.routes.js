const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const multer  = require("multer");
const { sendPushNotification } = require("../services/pushNotification.service");
const sendEmail                = require("../config/mailer");

/* ─── MULTER ─────────────────────────────────────────────── */
const upload = multer({
  storage: multer.diskStorage({
    destination: (_, __, cb) => cb(null, "uploads/profile"),
    filename:    (_, file, cb) =>
      cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}-${file.originalname}`)
  })
});

/* ─── EMAIL HELPERS ──────────────────────────────────────── */
const emailBase = (content) => `
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#f0f2f5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif}
.wrap{max-width:520px;margin:40px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 16px rgba(0,0,0,.07)}
.head{background:linear-gradient(135deg,#1B7F6E,#25A98F);padding:28px 32px;text-align:center}
.head h1{color:#fff;font-size:17px;font-weight:600;margin:0}
.head p{color:rgba(255,255,255,.72);font-size:11.5px;margin-top:5px}
.body{padding:28px 32px}
.note{font-size:13px;color:#4b5563;line-height:1.65;margin-bottom:6px}
.card{background:#f8fffe;border:1px solid #d4f0ea;border-radius:10px;padding:18px 20px;margin:18px 0}
.row{display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid #e8f6f2;font-size:12.5px}
.row:last-child{border-bottom:none}
.row .l{color:#6b7280;font-weight:500}.row .v{color:#111827;font-weight:600}
.badge{display:inline-block;padding:3px 11px;border-radius:20px;font-size:11px;font-weight:700}
.green{background:#e6f5f0;color:#1B7F6E}.blue{background:#e3f0fd;color:#1565C0}
.footer{background:#f9fafb;padding:18px 32px;text-align:center;border-top:1px solid #eee}
.footer p{color:#9ca3af;font-size:11px;margin:3px 0}
.footer a{color:#1B7F6E;text-decoration:none;font-weight:600}
</style></head><body><div class="wrap">${content}</div></body></html>`;

const footer = `<div class="footer">
  <p>Need help? <a href="mailto:support@medico.com">support@medico.com</a></p>
  <p>© ${new Date().getFullYear()} Medico. All rights reserved.</p>
</div>`;

const acceptedEmail = ({ name, order_code, date, slot, location, total, payment_method }) =>
  emailBase(`
  <div class="head"><h1>✅ Caretaker Assigned</h1><p>Your care is on the way!</p></div>
  <div class="body">
    <p class="note">Hi <strong>${name}</strong>, a verified caretaker has accepted your booking.</p>
    <div class="card">
      <div class="row"><span class="l">Booking ID</span><span class="v">${order_code}</span></div>
      <div class="row"><span class="l">Date</span><span class="v">${date}</span></div>
      <div class="row"><span class="l">Slot</span><span class="v">${slot}</span></div>
      <div class="row"><span class="l">Location</span><span class="v">${location}</span></div>
      <div class="row"><span class="l">Amount</span><span class="v">₹${total}</span></div>
      <div class="row"><span class="l">Payment</span><span class="v">${payment_method}</span></div>
      <div class="row"><span class="l">Status</span><span class="v"><span class="badge green">Accepted</span></span></div>
    </div>
  </div>${footer}`);

const completedEmail = ({ name, order_code, date, slot, total }) =>
  emailBase(`
  <div class="head"><h1>🎉 Service Completed</h1><p>Thank you for choosing Medico!</p></div>
  <div class="body">
    <p class="note">Hi <strong>${name}</strong>, your service has been completed.</p>
    <div class="card">
      <div class="row"><span class="l">Booking ID</span><span class="v">${order_code}</span></div>
      <div class="row"><span class="l">Date</span><span class="v">${date}</span></div>
      <div class="row"><span class="l">Slot</span><span class="v">${slot}</span></div>
      <div class="row"><span class="l">Amount Paid</span><span class="v">₹${total}</span></div>
      <div class="row"><span class="l">Status</span><span class="v"><span class="badge blue">Completed</span></span></div>
    </div>
  </div>${footer}`);

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "";

/* ═══════════════════════════════════════════════════════════
   GET /caretaker/status/:userId
═══════════════════════════════════════════════════════════ */
router.get("/status/:userId", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT u.profile_completed, u.documents_uploaded, u.approval_status,
             u.reject_reason, u.allow_reupload, cp.caregiver_type
      FROM users u
      LEFT JOIN caretaker_profiles cp ON cp.user_id = u.id
      WHERE u.id = ?`, [req.params.userId]);

    if (!rows.length)
      return res.status(404).json({ success: false, message: "User not found" });

    const [loc] = await db.query(
      "SELECT id FROM addresses WHERE user_id = ? AND is_default = 1 LIMIT 1",
      [req.params.userId]);

    res.json({ success: true, ...rows[0], location_added: loc.length > 0 ? 1 : 0 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/onboarding
═══════════════════════════════════════════════════════════ */
router.post("/onboarding", upload.single("profile_image"), async (req, res) => {
  try {
    const { user_id, caregiver_type, services, experience, availability } = req.body;
    if (!user_id)
      return res.status(400).json({ success: false, message: "User ID required" });

    const profileImage = req.file?.path ?? null;
    const [ex] = await db.query("SELECT id FROM caretaker_profiles WHERE user_id = ?", [user_id]);

    if (ex.length) {
      await db.query(
        "UPDATE caretaker_profiles SET caregiver_type=?,services=?,experience=?,availability=?,profile_image=? WHERE user_id=?",
        [caregiver_type, services, experience, availability, profileImage, user_id]);
    } else {
      await db.query(
        "INSERT INTO caretaker_profiles (user_id,caregiver_type,services,experience,availability,profile_image) VALUES (?,?,?,?,?,?)",
        [user_id, caregiver_type, services, experience, availability, profileImage]);
    }
    await db.query("UPDATE users SET profile_completed = 1 WHERE id = ?", [user_id]);
    res.json({ success: true, message: "Caretaker profile saved" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/reset-status/:userId
═══════════════════════════════════════════════════════════ */
router.post("/reset-status/:userId", async (req, res) => {
  try {
    await db.query(
      `UPDATE users
          SET approval_status = 'pending',
              reject_reason   = NULL,
              allow_reupload  = 0,
              documents_uploaded = 0
        WHERE id = ?`,
      [req.params.userId]);
    res.json({ success: true, message: "Status reset to pending" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});
/* ═══════════════════════════════════════════════════════════
   GET /caretaker/order-detail/:id
   ✅ Includes document_urls, document_types, document_keys
   ✅ NEW: Includes emergency contact — ONLY when order is ON_THE_WAY
      (service actively started). Hidden before (ACCEPTED/CONFIRMED)
      and after (COMPLETED/CANCELLED) automatically, server-side.
═══════════════════════════════════════════════════════════ */
router.get("/order-detail/:id", async (req, res) => {
  try {
    const [[order]] = await db.query(
      `
      SELECT
        o.id,
        o.order_code,
        o.category,
        o.location,
        o.latitude,
        o.longitude,
        o.date,
        o.slot,
        o.total,
        o.payment_method,
        o.payment_status,
        o.payment_id,
        o.status,
        o.caretaker_id,
        o.assigned_caretaker_id,
        o.otp_verified,

        u.first_name AS careseeker_name,
        u.mobile     AS careseeker_phone,

        GROUP_CONCAT(
          DISTINCT s.name
          SEPARATOR ', '
        ) AS services,

        GROUP_CONCAT(
          DISTINCT bd.file_url
          SEPARATOR '|||'
        ) AS document_urls,

        GROUP_CONCAT(
          DISTINCT bd.file_type
          SEPARATOR ','
        ) AS document_types,

        GROUP_CONCAT(
          DISTINCT bd.document_key
          SEPARATOR ','
        ) AS document_keys,

        ec.name         AS emergency_name,
        ec.relationship AS emergency_relationship,
        ec.phone        AS emergency_phone,
        ec.alt_phone    AS emergency_alt_phone

      FROM orders o

      JOIN users u
        ON u.id = o.user_id

      LEFT JOIN order_items oi
        ON oi.order_id = o.id

      LEFT JOIN services s
        ON s.id = oi.service_id

      LEFT JOIN booking_documents bd
        ON bd.order_id = o.id
        AND bd.is_deleted = 0

      LEFT JOIN careseeker_emergency_contact ec
        ON ec.user_id = o.user_id

      WHERE o.id = ?

      GROUP BY o.id
      `,
      [req.params.id]
    );

    if (!order)
      return res.status(404).json({ success: false, message: "Order not found" });

    // 🔒 EMERGENCY CONTACT VISIBILITY GATE
// Only expose emergency contact once the caretaker has verified arrival OTP
// (proves they're actually on-site), not just "started journey".
if (order.status !== "ON_THE_WAY" || order.otp_verified !== 1) {
  order.emergency_name         = null;
  order.emergency_relationship = null;
  order.emergency_phone        = null;
  order.emergency_alt_phone    = null;
}
    
    console.log("🔥 ORDER DETAIL RESPONSE:", order);

    return res.json({ success: true, data: order });
  } catch (err) {
    console.error("ORDER DETAIL ERROR:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   GET /caretaker/orders
═══════════════════════════════════════════════════════════ */
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

/* ═══════════════════════════════════════════════════════════
   GET /caretaker/orders/:category
═══════════════════════════════════════════════════════════ */
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

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/accept
   ✅ Slot conflict check before accepting
═══════════════════════════════════════════════════════════ */
router.post("/accept", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;

    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    /* ── 1. Get target order ── */
    const [[targetOrder]] = await db.query(
      `SELECT id, date, slot, category, status FROM orders WHERE id = ?`,
      [order_id]
    );

    if (!targetOrder)
      return res.json({ success: false, message: "Order not found" });

    /* ── 2. Slot conflict check ── */
    const [[slotConflict]] = await db.query(
      `
      SELECT id
      FROM orders
      WHERE caretaker_id = ?
        AND date         = ?
        AND slot         = ?
        AND status IN ('ACCEPTED', 'ON_THE_WAY')
      LIMIT 1
      `,
      [caretaker_id, targetOrder.date, targetOrder.slot]
    );

    if (slotConflict)
      return res.json({
        success: false,
        message: "You already accepted another booking for this slot",
      });

    /* ── 3. Accept order ── */
    const [result] = await db.query(
      `
      UPDATE orders o
      JOIN caretaker_profiles cp ON cp.user_id = ?
      SET
        o.caretaker_id          = ?,
        o.assigned_caretaker_id = ?,
        o.status                = 'ACCEPTED',
        o.accepted_at           = NOW()
      WHERE o.id            = ?
        AND o.caretaker_id IS NULL
        AND o.status        = 'CONFIRMED'
        AND cp.caregiver_type = o.category
      `,
      [caretaker_id, caretaker_id, caretaker_id, order_id]
    );

    if (result.affectedRows === 0)
      return res.json({ success: false, message: "Already accepted or category mismatch" });

    /* ── 4. Fetch order + user for notification ── */
    const [[order]] = await db.query(
      `
      SELECT o.order_code, o.slot, o.category, o.location, o.total,
             o.payment_method, o.date, u.first_name, u.email, u.fcm_token
      FROM orders o
      JOIN users u ON u.id = o.user_id
      WHERE o.id = ?
      `,
      [order_id]
    );

    res.json({ success: true, message: "Booking accepted successfully" });

    /* ── 5. Fire-and-forget notifications ── */
    (async () => {
      try {
        const tasks = [];
        if (order?.fcm_token)
          tasks.push(sendPushNotification(
            order.fcm_token,
            "Booking Accepted ✅",
            `Your ${order.category} service at ${order.slot} (${order.order_code}) has been accepted`
          ));
        if (order?.email)
          tasks.push(sendEmail({
            to:      order.email,
            subject: `✅ Caretaker Assigned — ${order.order_code}`,
            html:    acceptedEmail({
              name:           order.first_name,
              order_code:     order.order_code,
              date:           fmtDate(order.date),
              slot:           order.slot,
              location:       order.location,
              total:          order.total,
              payment_method: order.payment_method,
            }),
          }));
        await Promise.allSettled(tasks);
      } catch (e) {
        console.error("Accept notify error:", e.message);
      }
    })();
  } catch (err) {
    console.error("ACCEPT ERROR:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/cancel
   ✅ COD / unpaid  → reopens booking (caretaker_id = NULL)
   ✅ Online paid   → flags as CARETAKER_CANCELLED for admin
═══════════════════════════════════════════════════════════ */
router.post("/cancel", async (req, res) => {
  try {
    const { order_id, caretaker_id, cancel_reason } = req.body;

    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    const [[order]] = await db.query(
      `SELECT * FROM orders WHERE id = ?`,
      [order_id]
    );

    if (!order)
      return res.json({ success: false, message: "Order not found" });

    if (Number(order.caretaker_id) !== Number(caretaker_id))
      return res.json({ success: false, message: "Unauthorized" });

    if (order.status === "COMPLETED")
      return res.json({ success: false, message: "Completed order cannot be cancelled" });

    const isOnlinePaid =
      order.payment_method !== "COD" && order.payment_status === "PAID";

    if (isOnlinePaid) {
      /* Online-paid: flag for admin — do NOT reset caretaker */
      await db.query(
        `
        UPDATE orders
        SET status        = 'CARETAKER_CANCELLED',
            cancel_reason = ?,
            cancelled_at  = NOW()
        WHERE id = ?
        `,
        [cancel_reason || "Cancelled by caretaker", order_id]
      );
    } else {
      /* COD / unpaid: reopen so another caretaker can pick it up */
      await db.query(
        `
        UPDATE orders
        SET caretaker_id          = NULL,
            assigned_caretaker_id = NULL,
            status                = 'CONFIRMED',
            accepted_at           = NULL,
            cancel_reason         = ?,
            cancelled_at          = NOW()
        WHERE id = ?
        `,
        [cancel_reason || "Cancelled by caretaker", order_id]
      );
    }

    return res.json({
      success: true,
      message: isOnlinePaid
        ? "Paid booking flagged for admin reassignment"
        : "Booking cancelled and reopened successfully",
    });
  } catch (err) {
    console.error("CANCEL ERROR:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/mark-payment-received
═══════════════════════════════════════════════════════════ */
router.post("/mark-payment-received", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    const [[order]] = await db.query(
      "SELECT id, payment_status, caretaker_id FROM orders WHERE id = ?",
      [order_id]
    );

    if (!order)        return res.json({ success: false, message: "Order not found" });
    if (order.payment_status === "PAID")
                       return res.json({ success: true,  message: "Already paid" });
    if (Number(order.caretaker_id) !== Number(caretaker_id))
                       return res.json({ success: false, message: "Unauthorized" });

    await db.query(
      "UPDATE orders SET payment_status = 'PAID' WHERE id = ?",
      [order_id]
    );

    const [[ord]] = await db.query(
      `SELECT o.order_code, o.category, u.fcm_token
       FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?`,
      [order_id]
    );

    if (ord?.fcm_token)
      sendPushNotification(
        ord.fcm_token,
        "Payment Received 💳",
        `Payment for your ${ord.category} service (${ord.order_code}) has been confirmed.`
      );

    res.json({ success: true, message: "Payment marked as received" });
  } catch (err) {
    console.error("MARK PAYMENT RECEIVED ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

router.put("/profile/availability/:id", async (req, res) => {
  const { id } = req.params;
  const { is_available } = req.body;

  try {
    // ── LOCK CHECK ──────────────────────────────────────────
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
    // ── END LOCK CHECK ──────────────────────────────────────

    const newVal = Number(is_available) === 1 ? 1 : 0;
    const tsCol  = newVal ? "last_available_at" : "last_unavailable_at";

    await db.query(
      `UPDATE caretaker_profiles 
          SET is_available = ?, ${tsCol} = NOW()
        WHERE user_id = ?`,
      [newVal, id]
    );

    // upsert daily snapshot
    await db.query(
      `INSERT INTO caregiver_daily_status (caregiver_id, status_date, is_available)
       VALUES (?, CURDATE(), ?)
       ON DUPLICATE KEY UPDATE is_available = VALUES(is_available)`,
      [id, newVal]
    );

    return res.json({ success: true, message: newVal ? "You are now available" : "You are now unavailable" });
  } catch (err) {
    console.error("TOGGLE AVAILABILITY ERROR:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});


router.post("/update-location", async (req, res) => {

  try {

    const {
      order_id,
      caretaker_id,
      latitude,
      longitude
    } = req.body;

    /* ─────────────────────────────
       VALIDATION
    ───────────────────────────── */

    if (
      !order_id ||
      !caretaker_id ||
      latitude == null ||
      longitude == null
    ) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields"
      });
    }

    /* ─────────────────────────────
       UPDATE LIVE LOCATION
    ───────────────────────────── */

    const [result] = await db.query(
      `
      UPDATE orders
      SET
        caretaker_latitude = ?,
        caretaker_longitude = ?
      WHERE id = ?
        AND caretaker_id = ?
        AND status = 'ON_THE_WAY'
      `,
      [
        latitude,
        longitude,
        order_id,
        caretaker_id
      ]
    );

    /* ─────────────────────────────
       CHECK UPDATE
    ───────────────────────────── */

    if (result.affectedRows === 0) {

      return res.status(404).json({
        success: false,
        message: "Order not active"
      });

    }

    /* ─────────────────────────────
       SUCCESS
    ───────────────────────────── */

    return res.json({
      success: true,
      message: "Location updated"
    });

  } catch (err) {

    console.error("UPDATE LOCATION ERROR:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

  }

});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/start
═══════════════════════════════════════════════════════════ */
router.post("/start", async (req, res) => {
  try {

    const { order_id, caretaker_id } = req.body;

    /* ─────────────────────────────
       VALIDATION
    ───────────────────────────── */
    if (!order_id || !caretaker_id) {
      return res.status(400).json({
        success: false,
        message: "Missing order_id or caretaker_id"
      });
    }

    /* ─────────────────────────────
       UPDATE ORDER STATUS
       ACCEPTED -> ON_THE_WAY
    ───────────────────────────── */
    const [result] = await db.query(
      `
      UPDATE orders
      SET status = 'ON_THE_WAY'
      WHERE id = ?
        AND caretaker_id = ?
        AND status IN ('ACCEPTED', 'CONFIRMED')
      `,
      [order_id, caretaker_id]
    );

    /* ─────────────────────────────
       CHECK UPDATE
    ───────────────────────────── */
    if (result.affectedRows === 0) {
      return res.json({
        success: false,
        message: "Order not found or already started"
      });
    }

    /* ─────────────────────────────
       FETCH ORDER DETAILS
    ───────────────────────────── */
    const [[order]] = await db.query(
      `
      SELECT
        o.order_code,
        o.category,
        u.fcm_token
      FROM orders o
      JOIN users u
        ON u.id = o.user_id
      WHERE o.id = ?
      `,
      [order_id]
    );

    /* ─────────────────────────────
       SEND PUSH NOTIFICATION
    ───────────────────────────── */
    if (order?.fcm_token) {

      sendPushNotification(
        order.fcm_token,
        "Caretaker On The Way 🚗",
        `Your caretaker for ${order.category} service (${order.order_code}) is on the way`
      );

    }

    /* ─────────────────────────────
       RESPONSE
    ───────────────────────────── */
    return res.json({
      success: true,
      message: "Caretaker journey started successfully"
    });

  } catch (err) {

    console.error("START ERROR:", err);

    return res.status(500).json({
      success: false,
      message: err.message
    });

  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/verify-otp
   ✅ Matches CaretakerOtpScreen: order_id, caretaker_id, otp
   ✅ Only valid once order is ON_THE_WAY and caretaker matches
   ✅ Sets otp_verified = 1, which /complete now requires
═══════════════════════════════════════════════════════════ */
router.post("/verify-otp", async (req, res) => {
  try {
    const { order_id, caretaker_id, otp } = req.body;

    if (!order_id || !caretaker_id || !otp) {
      return res.status(400).json({
        success: false,
        message: "Missing order_id, caretaker_id or otp"
      });
    }

    const [[order]] = await db.query(
      `SELECT id, otp, otp_verified, status, caretaker_id
       FROM orders
       WHERE id = ?`,
      [order_id]
    );

    if (!order)
      return res.json({ success: false, message: "Order not found" });

    if (Number(order.caretaker_id) !== Number(caretaker_id))
      return res.json({ success: false, message: "Unauthorized" });

    if (order.status !== "ON_THE_WAY")
      return res.json({
        success: false,
        message: `Cannot verify OTP — order is ${order.status}`
      });

    if (order.otp_verified === 1)
      return res.json({ success: true, message: "OTP already verified" });

    if (!order.otp || String(order.otp) !== String(otp)) {
      return res.json({ success: false, message: "Invalid OTP" });
    }

    await db.query(
      `UPDATE orders
       SET otp_verified = 1, otp_verified_at = NOW()
       WHERE id = ?`,
      [order_id]
    );

    return res.json({ success: true, message: "OTP verified successfully" });
  } catch (err) {
    console.error("VERIFY OTP ERROR:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});

/* ═══════════════════════════════════════════════════════════
   POST /caretaker/complete
   ✅ Now requires otp_verified = 1 before allowing completion
═══════════════════════════════════════════════════════════ */
router.post("/complete", async (req, res) => {
  const connection = await db.getConnection();
  try {
    const { order_id, caretaker_id } = req.body;
    if (!order_id || !caretaker_id)
      return res.status(400).json({ success: false, message: "Missing order_id or caretaker_id" });

    await connection.beginTransaction();

    const [[order]] = await connection.query(
      "SELECT * FROM orders WHERE id = ? FOR UPDATE",
      [order_id]
    );

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
      "SELECT id FROM earnings WHERE order_id = ? AND caretaker_id = ?",
      [order_id, caretaker_id]
    );

    if (existing) {
      await connection.query(
        "UPDATE orders SET status = 'COMPLETED', completed_at = NOW() WHERE id = ?",
        [order_id]
      );
      await connection.commit();
      return res.json({ success: true, message: "Completed" });
    }

    const total           = Number(order.total || 0);
    const commission      = parseFloat((total * 0.20).toFixed(2));
    const caretakerAmount = parseFloat((total - commission).toFixed(2));

    await connection.query(
      "UPDATE orders SET status = 'COMPLETED', completed_at = NOW() WHERE id = ?",
      [order_id]
    );
    await connection.query(
      `INSERT INTO earnings
         (order_id, caretaker_id, total_amount, commission, caretaker_amount, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [order_id, caretaker_id, total, commission, caretakerAmount]
    );

    await connection.commit();

    const [[ord]] = await db.query(
      `SELECT o.order_code, o.slot, o.category, o.date, o.total,
              u.first_name, u.email, u.fcm_token
       FROM orders o JOIN users u ON u.id = o.user_id WHERE o.id = ?`,
      [order_id]
    );

    res.json({ success: true, message: "Service completed & earnings recorded" });

    (async () => {
      try {
        const tasks = [];
        if (ord?.fcm_token)
          tasks.push(sendPushNotification(
            ord.fcm_token,
            "Service Completed ✅",
            `Your ${ord.category} service (${ord.order_code}) has been completed. Thank you!`
          ));
        if (ord?.email)
          tasks.push(sendEmail({
            to:      ord.email,
            subject: `🎉 Service Completed | ${ord.order_code}`,
            html:    completedEmail({
              name:       ord.first_name,
              order_code: ord.order_code,
              date:       fmtDate(ord.date),
              slot:       ord.slot,
              total:      ord.total,
            }),
          }));
        await Promise.allSettled(tasks);
      } catch (e) {
        console.error("Complete notify error:", e.message);
      }
    })();
  } catch (err) {
    await connection.rollback();
    console.error("COMPLETE ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  } finally {
    connection.release();
  }
});

/* ═══════════════════════════════════════════════════════════
   GET /caretaker/my-jobs/:caretakerId
═══════════════════════════════════════════════════════════ */
router.get("/my-jobs/:caretakerId", async (req, res) => {
  try {
    const [jobs] = await db.query(
      `
      SELECT o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
             o.date, o.slot, o.status, o.payment_status, o.total, o.payment_method,
             GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS services
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN services s     ON s.id        = oi.service_id
      WHERE o.caretaker_id = ? AND o.status != 'CANCELLED'
      GROUP BY o.id, o.order_code, o.category, o.location, o.latitude, o.longitude,
               o.date, o.slot, o.status, o.payment_status, o.total, o.payment_method
      ORDER BY o.created_at DESC
      `,
      [req.params.caretakerId]
    );
    res.json({ success: true, count: jobs.length, jobs });
  } catch (err) {
    console.error("MY JOBS ERROR:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;