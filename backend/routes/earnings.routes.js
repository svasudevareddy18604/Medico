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

/* ================= NEW: DAY / MONTH BREAKDOWN ================= */
// GET /caretaker/earnings/breakdown/:caretaker_id?period=day   (default)
// GET /caretaker/earnings/breakdown/:caretaker_id?period=month
router.get("/breakdown/:caretaker_id", async (req, res) => {
  try {
    const { caretaker_id } = req.params;
    const period = (req.query.period || "day").toLowerCase();

    if (!["day", "month"].includes(period)) {
      return res.status(400).json({
        success: false,
        message: "period must be 'day' or 'month'"
      });
    }

    const groupFormat = period === "month" ? "%Y-%m" : "%Y-%m-%d";
    const labelFormat = period === "month" ? "%b %Y" : "%d %b %Y";
    const rowLimit = period === "month" ? 12 : 30; // last 12 months / 30 days

    const [rows] = await db.query(
      `
      SELECT 
        DATE_FORMAT(created_at, ?) AS period_key,
        DATE_FORMAT(created_at, ?) AS period_label,
        COALESCE(SUM(caretaker_amount), 0) AS total,
        COALESCE(SUM(CASE WHEN LOWER(status) = 'pending' THEN caretaker_amount ELSE 0 END), 0) AS pending,
        COALESCE(SUM(CASE WHEN LOWER(status) = 'paid' THEN caretaker_amount ELSE 0 END), 0) AS paid,
        COUNT(*) AS order_count
      FROM earnings
      WHERE caretaker_id = ?
      GROUP BY period_key, period_label
      ORDER BY period_key DESC
      LIMIT ?
      `,
      [groupFormat, labelFormat, caretaker_id, rowLimit]
    );

    res.json({
      success: true,
      period,
      data: rows.map((r) => ({
        period_key: r.period_key,
        period_label: r.period_label,
        total: Number(r.total) || 0,
        pending: Number(r.pending) || 0,
        paid: Number(r.paid) || 0,
        order_count: Number(r.order_count) || 0
      }))
    });

  } catch (err) {
    console.error("BREAKDOWN ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Server error"
    });
  }
});

module.exports = router;