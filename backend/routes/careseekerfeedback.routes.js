const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================================
   SUBMIT FEEDBACK
========================================================= */

router.post("/", async (req, res) => {
  try {
    const { caregiver_id, order_id, rating, feedback, user_id } = req.body;

    console.log("BODY RECEIVED:", req.body);

    /* ================= VALIDATION ================= */

    if (
      caregiver_id == null ||
      order_id == null ||
      rating == null ||
      user_id == null
    ) {
      return res.json({
        success: false,
        message: "Missing required fields",
      });
    }

    if (rating < 1 || rating > 5) {
      return res.json({
        success: false,
        message: "Rating must be between 1 and 5",
      });
    }

    /* ================= GET ORDER ================= */

    const [orderRows] = await db.query(
      "SELECT * FROM orders WHERE id = ?",
      [order_id]
    );

    if (orderRows.length === 0) {
      return res.json({
        success: false,
        message: "Order not found",
      });
    }

    const order = orderRows[0];

    /* ================= SECURITY CHECK ================= */

    if (order.user_id !== user_id) {
      return res.json({
        success: false,
        message: "This order does not belong to you",
      });
    }

    /* ================= STATUS CHECK ================= */

    if (order.status !== "COMPLETED") {
      return res.json({
        success: false,
        message: "Order not completed yet",
      });
    }

    /* ================= CARETAKER VALIDATION ================= */

    const actualCaretakerId = order.caretaker_id;

    if (!actualCaretakerId || actualCaretakerId === 0) {
      return res.json({
        success: false,
        message: "Invalid caretaker",
      });
    }

    /* ================= DUPLICATE CHECK ================= */

    const [existing] = await db.query(
      "SELECT id FROM feedback WHERE order_id = ?",
      [order_id]
    );

    if (existing.length > 0) {
      return res.json({
        success: false,
        message: "Feedback already submitted",
      });
    }

    /* ================= INSERT FEEDBACK ================= */

    await db.query(
      `INSERT INTO feedback 
       (order_id, caregiver_id, user_id, rating, feedback)
       VALUES (?, ?, ?, ?, ?)`,
      [
        order_id,
        actualCaretakerId, // ✅ always correct
        user_id,
        rating,
        feedback || "",
      ]
    );

    return res.json({
      success: true,
      message: "Feedback submitted successfully",
    });

  } catch (err) {
    console.error("FEEDBACK ERROR:", err);
    return res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});


/* =========================================================
   ⭐ IMPORTANT: SUMMARY ROUTE MUST BE FIRST
   GET /api/feedback/summary/:caregiverId
========================================================= */

router.get("/summary/:caregiverId", async (req, res) => {
  try {
    const { caregiverId } = req.params;

    const [rows] = await db.query(
      `SELECT 
         ROUND(AVG(rating),1) AS avgRating,
         COUNT(*) AS total
       FROM feedback
       WHERE caregiver_id = ?`,
      [caregiverId]
    );

    return res.json({
      success: true,
      avgRating: rows[0].avgRating || 0,
      total: rows[0].total || 0
    });

  } catch (err) {
    console.error("SUMMARY ERROR:", err);
    return res.status(500).json({ success: false });
  }
});


/* =========================================================
   GET CAREGIVER FULL FEEDBACK LIST
   GET /api/feedback/:caregiverId
   ✅ FIXED: joins `orders` so each feedback row carries the
   real order_code (e.g. "ORD-A1B2C3") instead of just the
   internal numeric order_id. This is what the Flutter
   RatingsReviewsScreen reads as r["order_code"].
========================================================= */

router.get("/:caregiverId", async (req, res) => {
  try {
    const { caregiverId } = req.params;

    const [rows] = await db.query(
      `SELECT 
         f.*, 
         o.order_code,
         u.first_name, 
         u.last_name
       FROM feedback f
       JOIN users  u ON f.user_id  = u.id
       JOIN orders o ON f.order_id = o.id
       WHERE f.caregiver_id = ?
       ORDER BY f.created_at DESC`,
      [caregiverId]
    );

    const [avg] = await db.query(
      `SELECT 
         ROUND(AVG(rating),1) as avgRating,
         COUNT(*) as total
       FROM feedback
       WHERE caregiver_id = ?`,
      [caregiverId]
    );

    return res.json({
      success: true,
      feedback: rows,
      avgRating: avg[0].avgRating || 0,
      total: avg[0].total || 0,
    });

  } catch (err) {
    console.error("FEEDBACK LIST ERROR:", err);
    return res.status(500).json({ success: false });
  }
});

module.exports = router;