const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================
   GET CURRENT RADIUS
========================= */

router.get("/radius", async (req, res) => {

  try {

    const [rows] = await db.query("SELECT * FROM settings LIMIT 1");

    if (rows.length === 0) {

      await db.query(
        "INSERT INTO settings (radius_km) VALUES (10)"
      );

      return res.json({ radius_km: 10 });
    }

    res.json({ radius_km: rows[0].radius_km });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

});

/* =========================
   UPDATE RADIUS
========================= */

router.post("/radius", async (req, res) => {

  try {

    const { radius_km } = req.body;

    if (!radius_km) {
      return res.status(400).json({
        message: "Radius required"
      });
    }

    const [rows] = await db.query("SELECT * FROM settings LIMIT 1");

    if (rows.length === 0) {

      await db.query(
        "INSERT INTO settings (radius_km) VALUES (?)",
        [radius_km]
      );

    } else {

      await db.query(
        "UPDATE settings SET radius_km=? WHERE id=?",
        [radius_km, rows[0].id]
      );

    }

    res.json({
      success: true,
      message: "Radius updated successfully"
    });

  } catch (err) {

    console.error(err);

    res.status(500).json({
      message: "Server error"
    });

  }

});

module.exports = router;