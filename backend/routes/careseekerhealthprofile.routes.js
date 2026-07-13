const express = require("express");
const router = express.Router();
const db = require("../config/db"); // mysql2 promise pool — adjust path/export if different in your project

/* =========================================
   HELPER: format DATE for MySQL / null-safe
========================================= */
const nullable = (val) => (val === undefined || val === "" ? null : val);

/* =========================================
   POST /api/health-profile
   Create or update (upsert) a careseeker's
   health profile
========================================= */
router.post("/", async (req, res) => {
  try {
    const {
      user_id,
      date_of_birth,
      gender,
      height,
      weight,
      blood_group,
      medical_conditions,
      allergies,
      current_medications,
      mobility,
      assistance_required,
      emergency_contact_name,
      emergency_contact_relationship,
      emergency_contact_phone,
      smoking,
      alcohol,
      special_instructions,
    } = req.body;

    if (!user_id) {
      return res.status(400).json({
        success: false,
        message: "user_id is required",
      });
    }

    if (!emergency_contact_name || !emergency_contact_phone) {
      return res.status(400).json({
        success: false,
        message: "Emergency contact name and phone are required",
      });
    }

    const [existing] = await db.query(
      "SELECT id FROM health_profiles WHERE user_id = ? LIMIT 1",
      [user_id]
    );

    if (existing.length > 0) {
      // UPDATE
      await db.query(
        `UPDATE health_profiles SET
          date_of_birth = ?,
          gender = ?,
          height = ?,
          weight = ?,
          blood_group = ?,
          medical_conditions = ?,
          allergies = ?,
          current_medications = ?,
          mobility = ?,
          assistance_required = ?,
          emergency_contact_name = ?,
          emergency_contact_relationship = ?,
          emergency_contact_phone = ?,
          smoking = ?,
          alcohol = ?,
          special_instructions = ?
        WHERE user_id = ?`,
        [
          nullable(date_of_birth),
          nullable(gender),
          nullable(height),
          nullable(weight),
          blood_group || "Unknown",
          nullable(medical_conditions),
          nullable(allergies),
          nullable(current_medications),
          nullable(mobility),
          nullable(assistance_required),
          emergency_contact_name,
          nullable(emergency_contact_relationship),
          emergency_contact_phone,
          nullable(smoking),
          nullable(alcohol),
          nullable(special_instructions),
          user_id,
        ]
      );

      await db.query(
        "UPDATE users SET health_profile_completed = 1, health_profile_skipped = 0 WHERE id = ?",
        [user_id]
      );

      return res.json({
        success: true,
        message: "Health profile updated successfully",
      });
    }

    // INSERT
    await db.query(
      `INSERT INTO health_profiles (
        user_id,
        date_of_birth,
        gender,
        height,
        weight,
        blood_group,
        medical_conditions,
        allergies,
        current_medications,
        mobility,
        assistance_required,
        emergency_contact_name,
        emergency_contact_relationship,
        emergency_contact_phone,
        smoking,
        alcohol,
        special_instructions
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        user_id,
        nullable(date_of_birth),
        nullable(gender),
        nullable(height),
        nullable(weight),
        blood_group || "Unknown",
        nullable(medical_conditions),
        nullable(allergies),
        nullable(current_medications),
        nullable(mobility),
        nullable(assistance_required),
        emergency_contact_name,
        nullable(emergency_contact_relationship),
        emergency_contact_phone,
        nullable(smoking),
        nullable(alcohol),
        nullable(special_instructions),
      ]
    );

    await db.query(
      "UPDATE users SET health_profile_completed = 1, health_profile_skipped = 0 WHERE id = ?",
      [user_id]
    );

    return res.json({
      success: true,
      message: "Health profile saved successfully",
    });
  } catch (err) {
    console.error("🔥 HEALTH PROFILE SAVE ERROR:", err.message);
    return res.status(500).json({
      success: false,
      message: "Server error while saving health profile",
    });
  }
});

/* =========================================
   POST /api/health-profile/skip
   Log that the user skipped profile setup
========================================= */
router.post("/skip", async (req, res) => {
  try {
    const { user_id } = req.body;

    if (!user_id) {
      return res.status(400).json({
        success: false,
        message: "user_id is required",
      });
    }

    const [existing] = await db.query(
      "SELECT id FROM health_profiles WHERE user_id = ? LIMIT 1",
      [user_id]
    );

    if (existing.length === 0) {
      // Create a bare row so we know the user was prompted and skipped
      await db.query(
        "INSERT INTO health_profiles (user_id) VALUES (?)",
        [user_id]
      );
    }

    await db.query(
      "UPDATE users SET health_profile_skipped = 1 WHERE id = ?",
      [user_id]
    );

    return res.json({
      success: true,
      message: "Health profile setup skipped",
    });
  } catch (err) {
    console.error("🔥 HEALTH PROFILE SKIP ERROR:", err.message);
    return res.status(500).json({
      success: false,
      message: "Server error while skipping health profile",
    });
  }
});

/* =========================================
   GET /api/health-profile/:userId
   Fetch a careseeker's health profile
========================================= */
router.get("/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    const [rows] = await db.query(
      "SELECT * FROM health_profiles WHERE user_id = ? LIMIT 1",
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Health profile not found",
      });
    }

    return res.json({
      success: true,
      data: rows[0],
    });
  } catch (err) {
    console.error("🔥 HEALTH PROFILE FETCH ERROR:", err.message);
    return res.status(500).json({
      success: false,
      message: "Server error while fetching health profile",
    });
  }
});

module.exports = router;