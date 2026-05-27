const express = require("express");
const router  = express.Router();
const db      = require("../config/db");
const transporter = require("../config/mailer");
const admin   = require("../utils/firebase");

/* ─── HELPERS ─────────────────────────────────────────────────────────────── */
const sendEmail = async (to, subject, html) => {
  try { await transporter.sendMail({ from: `"Medico Admin" <${process.env.EMAIL_USER}>`, to, subject, html }); }
  catch (err) { console.error("Email Error:", err); }
};

const sendPush = async (token, title, body) => {
  try { if (token) await admin.messaging().send({ token, notification: { title, body } }); }
  catch (err) { console.error("FCM Error:", err); }
};

/* ─── GET ALL CAREGIVERS ──────────────────────────────────────────────────── */
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT id, first_name, last_name, mobile, profile_image, approval_status, is_blocked
      FROM users WHERE role = 'care_taker' ORDER BY created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Failed to fetch caregivers" });
  }
});

/* ─── GET CAREGIVER FULL DETAILS ──────────────────────────────────────────── */
router.get("/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [user] = await db.query(`
      SELECT id, first_name, last_name, mobile, email, profile_image,
             approval_status, is_blocked, fcm_token, created_at
      FROM users WHERE id = ?
    `, [id]);

    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    const [profile]   = await db.query(`SELECT caregiver_type, services, experience, availability, profile_image FROM caretaker_profiles WHERE user_id = ?`, [id]);
    const [documents] = await db.query(`SELECT aadhaar_front, aadhaar_back, pan_card, certificate FROM caretaker_documents WHERE user_id = ?`, [id]);

    const [[stats]] = await db.query(`
      SELECT
        COUNT(*) AS total_orders,
        SUM(status = 'COMPLETED') AS completed_orders,
        SUM(status IN ('CANCELLED','CARETAKER_CANCELLED')) AS cancelled_orders,
        SUM(status IN ('ACCEPTED','IN_PROGRESS')) AS active_orders
      FROM orders WHERE assigned_caretaker_id = ?
    `, [id]);

    const [[earnings]] = await db.query(`
      SELECT
        IFNULL(SUM(caretaker_amount), 0) AS total_earned,
        IFNULL(SUM(CASE WHEN status = 'paid'    THEN caretaker_amount ELSE 0 END), 0) AS paid_earnings,
        IFNULL(SUM(CASE WHEN status = 'pending' THEN caretaker_amount ELSE 0 END), 0) AS pending_earnings,
        COUNT(*) AS earnings_jobs
      FROM earnings WHERE caretaker_id = ?
    `, [id]);

    const [recentOrders] = await db.query(`
      SELECT id, order_code, category, date, slot, total, status,
             payment_status, location, cancel_reason, created_at
      FROM orders WHERE assigned_caretaker_id = ? ORDER BY created_at DESC LIMIT 10
    `, [id]);

    const [recentEarnings] = await db.query(`
      SELECT id, order_id, total_amount, commission, caretaker_amount, status, created_at
      FROM earnings WHERE caretaker_id = ? ORDER BY created_at DESC LIMIT 10
    `, [id]);

    return res.json({
      success: true,
      user:       user[0],
      profile:    profile[0]   || null,
      documents:  documents[0] || null,
      statistics: {
        total_orders:     Number(stats.total_orders     || 0),
        completed_orders: Number(stats.completed_orders || 0),
        cancelled_orders: Number(stats.cancelled_orders || 0),
        active_orders:    Number(stats.active_orders    || 0),
      },
      earnings: {
        total_earned:    Number(earnings.total_earned    || 0),
        paid_earnings:   Number(earnings.paid_earnings   || 0),
        pending_earnings:Number(earnings.pending_earnings|| 0),
        earnings_jobs:   Number(earnings.earnings_jobs   || 0),
      },
      recent_orders:   recentOrders,
      recent_earnings: recentEarnings,
    });
  } catch (err) {
    console.error("GET CAREGIVER DETAILS ERROR:", err);
    res.status(500).json({ success: false, message: "Failed to fetch caregiver details" });
  }
});

/* ─── APPROVE ─────────────────────────────────────────────────────────────── */
router.post("/approve/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [user] = await db.query("SELECT email, first_name, fcm_token FROM users WHERE id = ?", [id]);
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query("UPDATE users SET approval_status = 'approved' WHERE id = ?", [id]);
    await sendEmail(user[0].email, "Account Approved ✅", `<h2>Account Approved ✅</h2><p>Dear ${user[0].first_name}, your caregiver account is approved. You can now start accepting jobs.</p><p><strong>Medico Team</strong></p>`);
    await sendPush(user[0].fcm_token, "Account Approved ✅", "Your caregiver account is approved. You can start working now.");

    res.json({ success: true, message: "Approved successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Approval failed" });
  }
});

/* ─── REJECT ──────────────────────────────────────────────────────────────── */
router.post("/reject/:id", async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  if (!reason?.trim()) return res.status(400).json({ success: false, message: "Reject reason is required" });

  try {
    const [user] = await db.query("SELECT email, first_name, fcm_token FROM users WHERE id = ?", [id]);
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query("UPDATE users SET approval_status = 'rejected', reject_reason = ? WHERE id = ?", [reason, id]);
    await sendEmail(user[0].email, "Account Rejected ❌", `<h2>Account Rejected ❌</h2><p>Dear ${user[0].first_name}, your account was rejected.</p><p><strong>Reason:</strong> ${reason}</p><p><strong>Medico Team</strong></p>`);
    await sendPush(user[0].fcm_token, "Account Rejected ❌", `Reason: ${reason}`);

    res.json({ success: true, message: "Rejected successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Rejection failed" });
  }
});

/* ─── BLOCK ───────────────────────────────────────────────────────────────── */
router.post("/block/:id", async (req, res) => {
  const { id } = req.params;
  try {
    const [user] = await db.query("SELECT email, first_name, fcm_token FROM users WHERE id = ?", [id]);
    if (!user.length) return res.status(404).json({ success: false, message: "User not found" });

    await db.query("UPDATE users SET is_blocked = 1 WHERE id = ?", [id]);
    await sendEmail(user[0].email, "Account Blocked 🚫", `<h2>Account Blocked 🚫</h2><p>Dear ${user[0].first_name}, your account has been blocked. Contact support.</p><p><strong>Medico Team</strong></p>`);
    await sendPush(user[0].fcm_token, "Account Blocked 🚫", "Your account has been blocked. Please contact support.");

    res.json({ success: true, message: "Caregiver blocked successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Block failed" });
  }
});

/* ─── UNBLOCK ─────────────────────────────────────────────────────────────── */
router.post("/unblock/:id", async (req, res) => {
  const { id } = req.params;
  try {
    await db.query("UPDATE users SET is_blocked = 0 WHERE id = ?", [id]);
    res.json({ success: true, message: "Caregiver unblocked successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Unblock failed" });
  }
});

module.exports = router;