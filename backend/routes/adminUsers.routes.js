const express = require("express");
const router = express.Router(); // ✅ MUST EXIST
const db = require("../config/db");

const {
  sendPushNotification,
} = require("../services/pushNotification.service");

/* ================= GET CARE SEEKERS ================= */
router.get("/care-seekers", async (req, res) => {
  try {
    const [users] = await db.query(`
      SELECT id, first_name, last_name, mobile, email, is_blocked
      FROM users
      WHERE role = 'care_seeker'
    `);

    res.json(users);
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: "Server error" });
  }
});

/* ================= BLOCK / UNBLOCK ================= */
router.put("/block/:id", async (req, res) => {
  try {
    const { is_blocked } = req.body;
    const { id } = req.params;

    await db.query(
      "UPDATE users SET is_blocked = ? WHERE id = ?",
      [is_blocked, id]
    );

    // Respond immediately, notify in the background
    res.json({
      message: is_blocked ? "User blocked" : "User unblocked",
    });

    notifyUserOfBlockStatus(id, is_blocked);
  } catch (err) {
    console.log(err);
    res.status(500).json({ error: "Server error" });
  }
});

/* =========================================
   NOTIFY USER OF BLOCK / UNBLOCK STATUS
========================================= */
const notifyUserOfBlockStatus = async (userId, isBlocked) => {
  try {
    const [rows] = await db.query(
      `
      SELECT fcm_token, first_name
      FROM users
      WHERE id = ?
      `,
      [userId]
    );

    if (!rows.length || !rows[0].fcm_token) {
      console.log(
        `ℹ️ No valid FCM token for user ${userId}, skipping block/unblock notification.`
      );
      return;
    }

    const { fcm_token, first_name } = rows[0];

    const title = isBlocked
      ? "Account Restricted"
      : "Account Restored";

    const body = isBlocked
      ? `Hi ${first_name || "there"}, your Medico account has been temporarily restricted. Please contact support for assistance.`
      : `Hi ${first_name || "there"}, your Medico account access has been restored. You can continue using the app as usual.`;

    await sendPushNotification(fcm_token, title, body);

    console.log(
      `📣 Sent ${isBlocked ? "block" : "unblock"} notification to user ${userId}`
    );
  } catch (err) {
    // Notification failure should never break the block/unblock flow
    console.error("Error sending block/unblock notification:", err);
  }
};

/* ═══════════════════════════════════════════════════════════
   GET /users/session-status/:id
   🔥 Generic, role-agnostic status check used by the app's
   background SessionStatusMonitor for EVERY logged-in role
   (care_taker, care_seeker, admin). Single lightweight query —
   no joins needed. approval_status/allow_reupload will simply
   be null/irrelevant for non-caretaker roles, which is fine.
═══════════════════════════════════════════════════════════ */
router.get("/session-status/:id", async (req, res) => {
  try {
    const [[row]] = await db.query(
      `SELECT id, role, is_blocked, is_deleted, approval_status, allow_reupload
       FROM users
       WHERE id = ?`,
      [req.params.id]
    );

    if (!row)
      return res.status(404).json({ success: false, message: "User not found" });

    res.json({ success: true, ...row });
  } catch (err) {
    console.error("SESSION STATUS ERROR:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});
module.exports = router; // ✅ MUST EXPORT ROUTER