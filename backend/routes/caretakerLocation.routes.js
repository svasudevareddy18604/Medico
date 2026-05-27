const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================
   GET DEFAULT ADDRESS (FOR HOME SCREEN)
========================================= */

router.get("/default/:userId", async (req, res) => {

  try {

    const { userId } = req.params;

    const [rows] = await db.query(
      `SELECT address_line, area, landmark, pincode
       FROM addresses
       WHERE user_id=? AND is_default=1
       LIMIT 1`,
      [userId]
    );

    if (rows.length === 0) {
      return res.json({
        success: false,
        message: "No address found"
      });
    }

    return res.json({
      success: true,
      address: rows[0]   // ✅ IMPORTANT: use "address" not "location"
    });

  } catch (err) {

    console.error("GET DEFAULT ADDRESS ERROR:", err);

    return res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});

/* =========================================
   CHECK IF CARETAKER LOCATION EXISTS
========================================= */

router.get("/check/:userId", async (req, res) => {

  try {

    const { userId } = req.params;

    const [rows] = await db.query(
      `SELECT id FROM addresses WHERE user_id=? AND is_default=1 LIMIT 1`,
      [userId]
    );

    return res.json({
      success: true,
      location_added: rows.length > 0 ? 1 : 0
    });

  } catch (err) {

    console.error("CHECK LOCATION ERROR:", err);

    return res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   SAVE CARETAKER LOCATION (FIXED)
========================================= */

router.post("/", async (req, res) => {

  try {

    const {
      user_id,
      address_line,
      area,
      landmark,
      pincode,
      latitude,
      longitude
    } = req.body;

    if (!user_id || latitude == null || longitude == null) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields"
      });
    }

    /* Remove previous default */

    await db.query(
      "UPDATE addresses SET is_default=0 WHERE user_id=?",
      [user_id]
    );

    /* Insert new location */

    const [result] = await db.query(
      `INSERT INTO addresses
      (user_id, address_line, area, landmark, pincode, latitude, longitude, is_default)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        user_id,
        address_line,
        area,
        landmark,
        pincode,
        latitude,
        longitude
      ]
    );

    return res.json({
      success: true,
      message: "Location saved successfully",
      address_id: result.insertId
    });

  } catch (err) {

    console.error("SAVE LOCATION ERROR:", err);

    return res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   GET CARETAKER LOCATION
========================================= */

router.get("/details/:userId", async (req, res) => {

  try {

    const { userId } = req.params;

    const [rows] = await db.query(
      `SELECT address_line, area, landmark, pincode, latitude, longitude
       FROM addresses
       WHERE user_id=? AND is_default=1 LIMIT 1`,
      [userId]
    );

    if (rows.length === 0) {
      return res.json({
        success: false,
        message: "Location not found"
      });
    }

    return res.json({
      success: true,
      location: rows[0]
    });

  } catch (err) {

    console.error("GET LOCATION ERROR:", err);

    return res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   DELETE LOCATION
========================================= */

router.delete("/delete/:userId", async (req, res) => {

  try {

    const { userId } = req.params;

    await db.query(
      "DELETE FROM addresses WHERE user_id=?",
      [userId]
    );

    return res.json({
      success: true,
      message: "Location deleted"
    });

  } catch (err) {

    console.error("DELETE LOCATION ERROR:", err);

    return res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


module.exports = router;