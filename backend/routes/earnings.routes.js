const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* ================= GET EARNINGS ================= */
router.get("/:caretaker_id", async (req, res) => {
  try {
    const { caretaker_id } = req.params;

    const [rows] = await db.query(`
      SELECT 
        COALESCE(SUM(caretaker_amount), 0) AS total,

        COALESCE(SUM(
          CASE 
            WHEN LOWER(status) = 'pending' 
            THEN caretaker_amount 
            ELSE 0 
          END
        ), 0) AS pending,

        COALESCE(SUM(
          CASE 
            WHEN LOWER(status) = 'paid' 
            THEN caretaker_amount 
            ELSE 0 
          END
        ), 0) AS paid

      FROM earnings
      WHERE caretaker_id = ?
    `, [caretaker_id]);

    console.log("=== EARNINGS DEBUG ===");
    console.log("Caretaker ID:", caretaker_id);
    console.log("DB Result:", rows[0]);

    res.json({
      success: true,
      data: {
        total: Number(rows[0].total) || 0,
        pending: Number(rows[0].pending) || 0,
        paid: Number(rows[0].paid) || 0
      }
    });

  } catch (err) {
    console.error("EARNINGS ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Server error"
    });
  }
});

/* ================= HISTORY ================= */
router.get("/history/:caretaker_id", async (req, res) => {
  try {
    const { caretaker_id } = req.params;

    const [rows] = await db.query(`
      SELECT 
        e.*,
        o.order_code
      FROM earnings e
      LEFT JOIN orders o ON o.id = e.order_id
      WHERE e.caretaker_id = ?
      ORDER BY e.created_at DESC
    `, [caretaker_id]);

    console.log("=== HISTORY DEBUG ===");
    console.log("Rows count:", rows.length);

    res.json({
      success: true,
      data: rows
    });

  } catch (err) {
    console.error("HISTORY ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Server error"
    });
  }
});

module.exports = router;