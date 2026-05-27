const express = require("express");
const router  = express.Router();
const db      = require("../config/db");

/* ─── GET NEARBY CARETAKERS ───────────────────────────────────────────────── */
// GET /api/caretakers/:userId
router.get("/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    const [userLocation] = await db.query(
      `SELECT latitude, longitude FROM addresses WHERE user_id = ? AND is_default = 1 LIMIT 1`,
      [userId]
    );
    if (userLocation.length === 0) return res.json([]);

    const { latitude: lat, longitude: lng } = userLocation[0];

    const [settings] = await db.query("SELECT radius_km FROM settings LIMIT 1");
    const radius = settings[0].radius_km;

    const [rows] = await db.query(
      `SELECT u.id, u.first_name, u.last_name, u.mobile,
              a.latitude, a.longitude, cp.caregiver_type,
              cp.is_available,
              (6371 * acos(
                cos(radians(?)) * cos(radians(a.latitude)) *
                cos(radians(a.longitude) - radians(?)) +
                sin(radians(?)) * sin(radians(a.latitude))
              )) AS distance
       FROM users u
       JOIN addresses a ON u.id = a.user_id
       LEFT JOIN caretaker_profiles cp ON u.id = cp.user_id
       WHERE u.role = 'care_taker'
         AND u.approval_status = 'approved'
         AND u.is_blocked = 0
         AND cp.is_available = 1
         AND a.is_default = 1
       HAVING distance <= ?
       ORDER BY distance ASC`,
      [lat, lng, lat, radius]
    );

    res.json(rows.map(r => ({ ...r, user_latitude: lat, user_longitude: lng })));
  } catch (err) {
    console.error("❌ GET NEARBY CARETAKERS ERROR:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/* ─── CHECK AVAILABILITY FOR CATEGORY ────────────────────────────────────── */
// GET /api/caretakers/:userId/availability/:category
router.get("/:userId/availability/:category", async (req, res) => {
  try {
    const { userId, category } = req.params;

    const [userLocation] = await db.query(
      `SELECT latitude, longitude FROM addresses WHERE user_id = ? AND is_default = 1 LIMIT 1`,
      [userId]
    );
    if (userLocation.length === 0) return res.json({ available: false, reason: "no_address" });

    const { latitude: lat, longitude: lng } = userLocation[0];

    const [settings] = await db.query("SELECT radius_km FROM settings LIMIT 1");
    const radius = settings[0].radius_km;

    const [rows] = await db.query(
      `SELECT u.id,
              (6371 * acos(
                cos(radians(?)) * cos(radians(a.latitude)) *
                cos(radians(a.longitude) - radians(?)) +
                sin(radians(?)) * sin(radians(a.latitude))
              )) AS distance
       FROM users u
       JOIN addresses a ON u.id = a.user_id
       JOIN caretaker_profiles cp ON u.id = cp.user_id
       WHERE u.role = 'care_taker'
         AND u.approval_status = 'approved'
         AND u.is_blocked = 0
         AND cp.caregiver_type = ?
         AND cp.is_available = 1
         AND a.is_default = 1
       HAVING distance <= ?
       LIMIT 1`,
      [lat, lng, lat, category, radius]
    );

    res.json({ available: rows.length > 0 });
  } catch (err) {
    console.error("❌ CHECK AVAILABILITY ERROR:", err);
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;