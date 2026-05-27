const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================
   CREATE SLOT
========================================= */

router.post("/create", async (req, res) => {

  try {

    const { slot_date, slot_time } = req.body;

    if (!slot_date || !slot_time) {
      return res.status(400).json({
        success: false,
        message: "slot_date and slot_time required"
      });
    }

    const sql = `
      INSERT INTO service_slots
      (slot_date, slot_time, status)
      VALUES (?, ?, 'available')
    `;

    const [result] = await db.query(sql, [slot_date, slot_time]);

    res.json({
      success: true,
      message: "Slot created",
      id: result.insertId
    });

  } catch (err) {

    if (err.code === "ER_DUP_ENTRY") {
      return res.json({
        success: false,
        message: "Slot already exists"
      });
    }

    console.error("CREATE SLOT ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   UPDATE SLOT
========================================= */

router.put("/update/:id", async (req, res) => {

  try {

    const { id } = req.params;
    const { slot_time } = req.body;

    if (!slot_time) {
      return res.status(400).json({
        success: false,
        message: "slot_time required"
      });
    }

    const sql = `
      UPDATE service_slots
      SET slot_time = ?
      WHERE id = ?
    `;

    await db.query(sql, [slot_time, id]);

    res.json({
      success: true,
      message: "Slot updated"
    });

  } catch (err) {

    if (err.code === "ER_DUP_ENTRY") {
      return res.json({
        success: false,
        message: "Another slot exists at same time"
      });
    }

    console.error("UPDATE SLOT ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   GET SLOTS BY DATE
========================================= */

router.get("/date/:date", async (req, res) => {

  try {

    const { date } = req.params;

    const sql = `
      SELECT id, slot_date, slot_time, status
      FROM service_slots
      WHERE slot_date = ?
      ORDER BY slot_time ASC
    `;

    const [rows] = await db.query(sql, [date]);

    res.json({
      success: true,
      slots: rows
    });

  } catch (err) {

    console.error("GET SLOTS BY DATE ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   GET ALL SLOTS
========================================= */

router.get("/all", async (req, res) => {

  try {

    const sql = `
      SELECT id, slot_date, slot_time, status
      FROM service_slots
      ORDER BY slot_date ASC, slot_time ASC
    `;

    const [rows] = await db.query(sql);

    res.json({
      success: true,
      slots: rows
    });

  } catch (err) {

    console.error("GET ALL SLOTS ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


/* =========================================
   DELETE SLOT
========================================= */

router.delete("/delete/:id", async (req, res) => {

  try {

    const { id } = req.params;

    const sql = `
      DELETE FROM service_slots
      WHERE id = ?
    `;

    await db.query(sql, [id]);

    res.json({
      success: true,
      message: "Slot deleted"
    });

  } catch (err) {

    console.error("DELETE SLOT ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Database error"
    });

  }

});


module.exports = router;