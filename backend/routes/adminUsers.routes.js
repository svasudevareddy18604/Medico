const express = require("express");
const router = express.Router(); // ✅ MUST EXIST
const db = require("../config/db");

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

    res.json({
      message: is_blocked ? "User blocked" : "User unblocked"
    });

  } catch (err) {
    console.log(err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router; // ✅ MUST EXPORT ROUTER