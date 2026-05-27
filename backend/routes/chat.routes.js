const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================================
   GET ALL USERS WHO HAVE CHAT MESSAGES
========================================================= */

router.get("/admin/users", async (req, res) => {
  try {
    const [users] = await db.query(`
      SELECT
        u.id,
        u.first_name,
        u.last_name,
        u.profile_image,
        u.role,

        (
          SELECT message
          FROM support_messages
          WHERE user_id = u.id
          ORDER BY created_at DESC
          LIMIT 1
        ) AS last_message,

        (
          SELECT created_at
          FROM support_messages
          WHERE user_id = u.id
          ORDER BY created_at DESC
          LIMIT 1
        ) AS last_time,

        (
          SELECT COUNT(*)
          FROM support_messages
          WHERE user_id = u.id
          AND sender = 'user'
          AND is_read = 0
        ) AS unread_count

      FROM users u

      WHERE EXISTS (
        SELECT 1
        FROM support_messages
        WHERE user_id = u.id
      )

      ORDER BY last_time DESC
    `);

    res.json({
      success: true,
      data: users,
    });

  } catch (err) {
    console.error("❌ Admin users:", err);

    res.status(500).json({
      success: false,
      message: "Failed to fetch users",
    });
  }
});

/* =========================================================
   GET ALL USERS GROUPED BY ROLE
========================================================= */

router.get("/admin/all-users", async (req, res) => {
  try {
    const [users] = await db.query(`
      SELECT
        id,
        first_name,
        last_name,
        role,
        profile_image
      FROM users
      WHERE role != 'admin'
      ORDER BY role
    `);

    res.json({
      success: true,

      care_seekers: users.filter(
        (u) => u.role === "care_seeker"
      ),

      care_takers: users.filter(
        (u) => u.role === "care_taker"
      ),
    });

  } catch (err) {
    console.error("❌ All users:", err);

    res.status(500).json({
      success: false,
      message: "Failed",
    });
  }
});

/* =========================================================
   GET UNREAD COUNT
========================================================= */

router.get("/admin/unread/:userId", async (req, res) => {
  try {

    const [[row]] = await db.query(`
      SELECT COUNT(*) AS unread
      FROM support_messages
      WHERE user_id = ?
      AND sender = 'user'
      AND is_read = 0
    `, [req.params.userId]);

    res.json({
      success: true,
      unread: row.unread,
    });

  } catch (err) {
    console.error("❌ Unread:", err);

    res.status(500).json({
      success: false,
      message: "Failed",
    });
  }
});

/* =========================================================
   MARK AS READ
========================================================= */

router.put("/admin/read/:userId", async (req, res) => {
  try {

    await db.query(`
      UPDATE support_messages
      SET is_read = 1
      WHERE user_id = ?
      AND sender = 'user'
    `, [req.params.userId]);

    res.json({
      success: true,
    });

  } catch (err) {
    console.error("❌ Mark read:", err);

    res.status(500).json({
      success: false,
      message: "Failed",
    });
  }
});

/* =========================================================
   SEND MESSAGE
========================================================= */

router.post("/send", async (req, res) => {
  try {

    const {
      userId,
      role,
      message,
      sender,
    } = req.body;

    // ================= VALIDATION =================

    if (!userId || !message || !sender) {
      return res.status(400).json({
        success: false,
        message: "Missing fields",
      });
    }

    // ================= INSERT =================

    const [result] = await db.query(`
      INSERT INTO support_messages
      (
        user_id,
        role,
        sender,
        message,
        is_read
      )
      VALUES (?, ?, ?, ?, 0)
    `, [
      userId,
      role || "care_seeker",
      sender,
      message,
    ]);

    res.json({
      success: true,
      id: result.insertId,
    });

  } catch (err) {
    console.error("❌ Send:", err);

    res.status(500).json({
      success: false,
      message: "Failed to send",
    });
  }
});

/* =========================================================
   GET CHAT HISTORY
========================================================= */

router.get("/:userId", async (req, res) => {
  try {

    const [messages] = await db.query(`
      SELECT
        id,
        user_id,
        role,
        sender,
        message,
        created_at,
        is_read
      FROM support_messages
      WHERE user_id = ?
      ORDER BY created_at ASC
    `, [req.params.userId]);

    res.json({
      success: true,
      data: messages,
    });

  } catch (err) {
    console.error("❌ Fetch chat:", err);

    res.status(500).json({
      success: false,
      message: "Failed",
    });
  }
});

module.exports = router;