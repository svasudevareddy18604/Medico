const express     = require("express");
const router      = express.Router();
const db          = require("../config/db");
const sendMailFn  = require("../config/mailer"); // ✅ this is a function, not a transporter
const admin       = require("../utils/firebase");

/* ─────────────────────────────────────────────────────────────────────────────
   HELPERS
───────────────────────────────────────────────────────────────────────────── */
const sendEmail = async (to, subject, html) => {
  try {
    await sendMailFn({ to, subject, html }); // ✅ call it the way config/mailer actually expects
  } catch (err) {
    console.error("Email Error:", err);
  }
};

const sendPush = async (token, title, body) => {
  try {
    if (token) await admin.messaging().send({ token, notification: { title, body } });
  } catch (err) {
    console.error("FCM Error:", err);
  }
};
/* ─────────────────────────────────────────────────────────────────────────────
   SQL MIGRATION HELPER — run once on startup to add new columns if missing.
   Safe to call repeatedly (IF NOT EXISTS guards each column).
───────────────────────────────────────────────────────────────────────────── */
const runMigrations = async () => {
  const columns = [
    {
      name: "last_available_at",
      sql: "ALTER TABLE caretaker_profiles ADD COLUMN last_available_at DATETIME NULL",
    },
    {
      name: "last_unavailable_at",
      sql: "ALTER TABLE caretaker_profiles ADD COLUMN last_unavailable_at DATETIME NULL",
    },
    {
      name: "availability_locked",
      sql: "ALTER TABLE caretaker_profiles ADD COLUMN availability_locked TINYINT(1) NOT NULL DEFAULT 0",
    },
  ];

  for (const col of columns) {
    const [exists] = await db.query(
      `SELECT COLUMN_NAME
       FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE()
         AND TABLE_NAME = 'caretaker_profiles'
         AND COLUMN_NAME = ?`,
      [col.name]
    );

    if (exists.length === 0) {
      await db.query(col.sql);
      console.log(`✅ Added column: ${col.name}`);
    } else {
      console.log(`✔ Column already exists: ${col.name}`);
    }
  }

  await db.query(`
    CREATE TABLE IF NOT EXISTS caregiver_daily_status (
      id INT AUTO_INCREMENT PRIMARY KEY,
      caregiver_id INT NOT NULL,
      status_date DATE NOT NULL,
      is_available TINYINT(1) NOT NULL DEFAULT 0,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY uq_caregiver_date (caregiver_id, status_date),
      INDEX idx_caregiver (caregiver_id),
      INDEX idx_date (status_date)
    )
  `);

  console.log("✅ Caregiver availability migrations done.");
};

runMigrations();

/* ─────────────────────────────────────────────────────────────────────────────
   AUTO-INACTIVE JOB — mark caregivers inactive if unavailable > 30 days.
   Call this from a cron (e.g. node-cron daily at midnight).
   Also exported so you can wire it up in your main server file.
───────────────────────────────────────────────────────────────────────────── */
const autoInactiveJob = async () => {
  try {
    // Find caregivers who have been unavailable for > 30 days
    const [targets] = await db.query(`
      SELECT cp.user_id, u.email, u.first_name, u.fcm_token
      FROM   caretaker_profiles cp
      JOIN   users u ON u.id = cp.user_id
      WHERE  cp.is_available         = 0
        AND  cp.availability_locked  = 0
        AND  cp.last_unavailable_at IS NOT NULL
        AND  cp.last_unavailable_at <= DATE_SUB(NOW(), INTERVAL 30 DAY)
    `);

    for (const ct of targets) {
      await db.query(
        `UPDATE caretaker_profiles
            SET availability_locked = 1
          WHERE user_id = ?`,
        [ct.user_id]
      );

      await sendEmail(
        ct.email,
        "Your Medico account has been deactivated",
        `<h2>Account Deactivated</h2>
         <p>Dear ${ct.first_name},</p>
         <p>Your caregiver account has been automatically deactivated because you
         were marked unavailable for more than 30 days.</p>
         <p>Please contact admin to reactivate your account.</p>
         <p><strong>Medico Team</strong></p>`
      );

      await sendPush(
        ct.fcm_token,
        "Account Deactivated ⚠️",
        "Your account was deactivated after 30 days of inactivity. Contact admin to reactivate."
      );
    }

    console.log(`Auto-inactive job: ${targets.length} caregiver(s) locked.`);
  } catch (err) {
    console.error("Auto-inactive job error:", err);
  }
};

module.exports.autoInactiveJob = autoInactiveJob;

/* ─────────────────────────────────────────────────────────────────────────────
   DAILY SNAPSHOT HELPER — insert/update today's row for a caregiver.
   Call after any availability change.
───────────────────────────────────────────────────────────────────────────── */
const upsertDailyStatus = async (caregiverId, isAvailable) => {
  await db.query(
    `INSERT INTO caregiver_daily_status (caregiver_id, status_date, is_available)
     VALUES (?, CURDATE(), ?)
     ON DUPLICATE KEY UPDATE is_available = VALUES(is_available)`,
    [caregiverId, isAvailable ? 1 : 0]
  );
};

/* ─────────────────────────────────────────────────────────────────────────────
   GET ALL CAREGIVERS
───────────────────────────────────────────────────────────────────────────── */
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT u.id, u.first_name, u.last_name, u.mobile, u.profile_image,
             u.approval_status, u.is_blocked,
             cp.is_available, cp.availability_locked,
             cp.last_available_at, cp.last_unavailable_at
      FROM   users u
      LEFT JOIN caretaker_profiles cp ON cp.user_id = u.id
      WHERE  u.role = 'care_taker'
      ORDER  BY u.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Failed to fetch caregivers" });
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   GET CAREGIVER FULL DETAILS  (includes availability + daily history)
───────────────────────────────────────────────────────────────────────────── */
router.get("/:id", async (req, res) => {
  const { id } = req.params;
  try {
    /* --- user row --- */
    const [user] = await db.query(
      `SELECT id, first_name, last_name, mobile, email, profile_image,
              approval_status, is_blocked, fcm_token, created_at
       FROM   users WHERE id = ?`,
      [id]
    );
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    /* --- profile (with availability cols) --- */
    const [profile] = await db.query(
      `SELECT caregiver_type, services, experience, availability, profile_image,
              is_available, availability_locked, last_available_at, last_unavailable_at
       FROM   caretaker_profiles WHERE user_id = ?`,
      [id]
    );

    /* --- documents --- */
    const [documents] = await db.query(
      `SELECT aadhaar_front, aadhaar_back, pan_card, certificate
       FROM   caretaker_documents WHERE user_id = ?`,
      [id]
    );

    /* --- job statistics --- */
    const [[stats]] = await db.query(
      `SELECT
         COUNT(*) AS total_orders,
         SUM(status = 'COMPLETED')                              AS completed_orders,
         SUM(status IN ('CANCELLED','CARETAKER_CANCELLED'))     AS cancelled_orders,
         SUM(status IN ('ACCEPTED','IN_PROGRESS'))              AS active_orders
       FROM orders WHERE assigned_caretaker_id = ?`,
      [id]
    );

    /* --- earnings summary --- */
    const [[earnings]] = await db.query(
      `SELECT
         IFNULL(SUM(caretaker_amount), 0)                                      AS total_earned,
         IFNULL(SUM(CASE WHEN status='paid'    THEN caretaker_amount ELSE 0 END),0) AS paid_earnings,
         IFNULL(SUM(CASE WHEN status='pending' THEN caretaker_amount ELSE 0 END),0) AS pending_earnings,
         COUNT(*) AS earnings_jobs
       FROM earnings WHERE caretaker_id = ?`,
      [id]
    );

    /* --- recent orders --- */
    const [recentOrders] = await db.query(
      `SELECT id, order_code, category, date, slot, total, status,
              payment_status, location, cancel_reason, created_at
       FROM   orders WHERE assigned_caretaker_id = ?
       ORDER  BY created_at DESC LIMIT 10`,
      [id]
    );

    /* --- recent earnings --- */
    const [recentEarnings] = await db.query(
      `SELECT id, order_id, total_amount, commission, caretaker_amount, status, created_at
       FROM   earnings WHERE caretaker_id = ?
       ORDER  BY created_at DESC LIMIT 10`,
      [id]
    );

    /* --- daily availability history (last 30 days) --- */
    const [dailyHistory] = await db.query(
      `SELECT status_date, is_available
       FROM   caregiver_daily_status
       WHERE  caregiver_id = ?
         AND  status_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
       ORDER  BY status_date DESC`,
      [id]
    );

    /* --- inactive days calculation --- */
    const prof = profile[0] || {};
    let inactiveDays = 0;
    if (!prof.is_available && prof.last_unavailable_at) {
      const diff = Date.now() - new Date(prof.last_unavailable_at).getTime();
      inactiveDays = Math.floor(diff / (1000 * 60 * 60 * 24));
    }

    return res.json({
      success: true,
      user:       user[0],
      profile:    prof || null,
      documents:  documents[0] || null,
      statistics: {
        total_orders:     Number(stats.total_orders     || 0),
        completed_orders: Number(stats.completed_orders || 0),
        cancelled_orders: Number(stats.cancelled_orders || 0),
        active_orders:    Number(stats.active_orders    || 0),
      },
      earnings: {
        total_earned:     Number(earnings.total_earned     || 0),
        paid_earnings:    Number(earnings.paid_earnings    || 0),
        pending_earnings: Number(earnings.pending_earnings || 0),
        earnings_jobs:    Number(earnings.earnings_jobs    || 0),
      },
      availability: {
        is_available:        prof.is_available         ?? 0,
        availability_locked: prof.availability_locked  ?? 0,
        last_available_at:   prof.last_available_at    ?? null,
        last_unavailable_at: prof.last_unavailable_at  ?? null,
        inactive_days:       inactiveDays,
      },
      daily_history:   dailyHistory,
      recent_orders:   recentOrders,
      recent_earnings: recentEarnings,
    });
  } catch (err) {
    console.error("GET CAREGIVER DETAILS ERROR:", err);
    res.status(500).json({ success: false, message: "Failed to fetch caregiver details" });
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   APPROVE
───────────────────────────────────────────────────────────────────────────── */
router.post("/approve/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [user] = await db.query(
      "SELECT email, first_name, fcm_token FROM users WHERE id = ?",
      [id]
    );
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query("UPDATE users SET approval_status = 'approved' WHERE id = ?", [id]);

    await sendEmail(
      user[0].email,
      "Account Approved ✅",
      `<h2>Account Approved ✅</h2>
       <p>Dear ${user[0].first_name}, your caregiver account is approved.
       You can now start accepting jobs.</p>
       <p><strong>Medico Team</strong></p>`
    );
    await sendPush(
      user[0].fcm_token,
      "Account Approved ✅",
      "Your caregiver account is approved. You can start working now."
    );

    res.json({ success: true, message: "Approved successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Approval failed" });
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   REJECT
───────────────────────────────────────────────────────────────────────────── */
router.post("/reject/:id", async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  if (!reason?.trim())
    return res.status(400).json({ success: false, message: "Reject reason is required" });

  try {
    const [user] = await db.query(
      "SELECT email, first_name, fcm_token FROM users WHERE id = ?",
      [id]
    );
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query(
      "UPDATE users SET approval_status = 'rejected', reject_reason = ? WHERE id = ?",
      [reason, id]
    );

    await sendEmail(
      user[0].email,
      "Account Rejected ❌",
      `<h2>Account Rejected ❌</h2>
       <p>Dear ${user[0].first_name}, your account was rejected.</p>
       <p><strong>Reason:</strong> ${reason}</p>
       <p><strong>Medico Team</strong></p>`
    );
    await sendPush(user[0].fcm_token, "Account Rejected ❌", `Reason: ${reason}`);

    res.json({ success: true, message: "Rejected successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Rejection failed" });
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   BLOCK
───────────────────────────────────────────────────────────────────────────── */
router.post("/block/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [user] = await db.query(
      "SELECT email, first_name, fcm_token FROM users WHERE id = ?",
      [id]
    );
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query("UPDATE users SET is_blocked = 1 WHERE id = ?", [id]);

    await sendEmail(
      user[0].email,
      "Account Blocked 🚫",
      `<h2>Account Blocked 🚫</h2>
       <p>Dear ${user[0].first_name}, your account has been blocked. Contact support.</p>
       <p><strong>Medico Team</strong></p>`
    );
    await sendPush(
      user[0].fcm_token,
      "Account Blocked 🚫",
      "Your account has been blocked. Please contact support."
    );

    res.json({ success: true, message: "Caregiver blocked successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Block failed" });
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   UNBLOCK
───────────────────────────────────────────────────────────────────────────── */
router.post("/unblock/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [user] = await db.query(
      "SELECT email, first_name, fcm_token FROM users WHERE id = ?",
      [id]
    );
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query("UPDATE users SET is_blocked = 0 WHERE id = ?", [id]);

    await sendEmail(
      user[0].email,
      "Account Unblocked ✅",
      `<h2>Account Unblocked ✅</h2>
       <p>Dear ${user[0].first_name}, your account has been unblocked.
       You can now use Medico as usual.</p>
       <p><strong>Medico Team</strong></p>`
    );
    await sendPush(
      user[0].fcm_token,
      "Account Unblocked ✅",
      "Your account has been unblocked. You can continue using Medico as usual."
    );

    res.json({ success: true, message: "Caregiver unblocked successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unblock failed" });
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   SET AVAILABILITY (ADMIN)
   Admin can:
     • Force caregiver available   → is_available=1, locked=0
     • Force caregiver unavailable → is_available=0, locked=1
       (caregiver must contact admin to come back online)
───────────────────────────────────────────────────────────────────────────── */
router.post("/set-availability/:id", async (req, res) => {
  const { id }          = req.params;
  const { is_available } = req.body; // 1 = available, 0 = unavailable+locked

  if (is_available === undefined)
    return res.status(400).json({ success: false, message: "is_available is required (1 or 0)" });

  const makeAvailable = Number(is_available) === 1;

  try {
    const [user] = await db.query(
      "SELECT email, first_name, fcm_token FROM users WHERE id = ?",
      [id]
    );
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    if (makeAvailable) {
      // Admin re-enables the caregiver
      await db.query(
        `UPDATE caretaker_profiles
            SET is_available        = 1,
                availability_locked = 0,
                last_available_at   = NOW()
          WHERE user_id = ?`,
        [id]
      );

      await sendPush(
        user[0].fcm_token,
        "Account Reactivated ✅",
        "Your account has been reactivated by admin. You can now receive jobs."
      );
      await sendEmail(
        user[0].email,
        "Account Reactivated ✅",
        `<h2>Account Reactivated ✅</h2>
         <p>Dear ${user[0].first_name}, your account has been reactivated by admin.
         You can now start receiving jobs.</p>
         <p><strong>Medico Team</strong></p>`
      );
    } else {
      // Admin marks unavailable + locks it
      await db.query(
        `UPDATE caretaker_profiles
            SET is_available        = 0,
                availability_locked = 1,
                last_unavailable_at = NOW()
          WHERE user_id = ?`,
        [id]
      );

      await sendPush(
        user[0].fcm_token,
        "Marked Unavailable ⚠️",
        "Admin has marked you unavailable. Contact admin to go online again."
      );
      await sendEmail(
        user[0].email,
        "Marked Unavailable ⚠️",
        `<h2>Marked Unavailable ⚠️</h2>
         <p>Dear ${user[0].first_name}, admin has marked your account as unavailable.
         Please contact admin to be made available again.</p>
         <p><strong>Medico Team</strong></p>`
      );
    }

    // Record today's snapshot
    await upsertDailyStatus(id, makeAvailable);

    res.json({
      success:      true,
      message:      makeAvailable ? "Caregiver marked available" : "Caregiver marked unavailable (locked)",
      is_available: makeAvailable ? 1 : 0,
      locked:       makeAvailable ? 0 : 1,
    });
  } catch (err) {
    console.error("SET AVAILABILITY ERROR:", err);
    res.status(500).json({ success: false, message: "Failed to update availability" });
  }
});

module.exports = router;