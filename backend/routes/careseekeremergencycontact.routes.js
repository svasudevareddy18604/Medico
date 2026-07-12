const express = require("express");
const router = express.Router();
const db = require("../config/db"); // adjust path to your mysql2 pool/connection module

// ─────────────────────────────────────────────────────────────
// GET /api/emergency-contact/:userId
// Returns the saved emergency contact for a user.
// 404 if none exists yet (matches your Flutter "no contact saved" handling)
// ─────────────────────────────────────────────────────────────
router.get("/:userId", async (req, res) => {
  const { userId } = req.params;

  if (!userId || isNaN(userId)) {
    return res.status(400).json({ error: "Valid userId is required" });
  }

  try {
    const [rows] = await db.query(
      "SELECT id, user_id, name, relationship, phone, alt_phone FROM careseeker_emergency_contact WHERE user_id = ? LIMIT 1",
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "No emergency contact found" });
    }

    return res.status(200).json(rows[0]);
  } catch (err) {
    console.error("GET EMERGENCY CONTACT ERROR:", err);
    return res.status(500).json({ error: "Failed to fetch emergency contact" });
  }
});

// ─────────────────────────────────────────────────────────────
// POST /api/emergency-contact/save
// Creates or updates the emergency contact (upsert on user_id)
// ─────────────────────────────────────────────────────────────
router.post("/save", async (req, res) => {
  const { user_id, name, relationship, phone, alt_phone } = req.body;

  if (!user_id || !name || !relationship || !phone) {
    return res.status(400).json({
      error: "user_id, name, relationship, and phone are required",
    });
  }

  if (!/^\d{10}$/.test(phone)) {
    return res.status(400).json({ error: "Phone must be exactly 10 digits" });
  }

  if (alt_phone && !/^\d{10}$/.test(alt_phone)) {
    return res.status(400).json({ error: "Alternate phone must be exactly 10 digits" });
  }

  try {
    await db.query(
      `INSERT INTO careseeker_emergency_contact
        (user_id, name, relationship, phone, alt_phone)
       VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        relationship = VALUES(relationship),
        phone = VALUES(phone),
        alt_phone = VALUES(alt_phone),
        updated_at = CURRENT_TIMESTAMP`,
      [user_id, name.trim(), relationship.trim(), phone.trim(), (alt_phone || "").trim() || null]
    );

    return res.status(200).json({ message: "Emergency contact saved successfully" });
  } catch (err) {
    console.error("SAVE EMERGENCY CONTACT ERROR:", err);
    return res.status(500).json({ error: "Failed to save emergency contact" });
  }
});

// ─────────────────────────────────────────────────────────────
// DELETE /api/emergency-contact/:userId
// Optional: lets user remove their emergency contact entirely
// ─────────────────────────────────────────────────────────────
router.delete("/:userId", async (req, res) => {
  const { userId } = req.params;

  try {
    const [result] = await db.query(
      "DELETE FROM careseeker_emergency_contact WHERE user_id = ?",
      [userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "No emergency contact to delete" });
    }

    return res.status(200).json({ message: "Emergency contact deleted" });
  } catch (err) {
    console.error("DELETE EMERGENCY CONTACT ERROR:", err);
    return res.status(500).json({ error: "Failed to delete emergency contact" });
  }
});

module.exports = router;