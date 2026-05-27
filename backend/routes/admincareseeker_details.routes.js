// routes/admincareseeker_details.routes.js
const express = require("express");
const router  = express.Router();
const db      = require("../config/db"); // adjust to your db import

// GET /api/admin/careseeker/:id/details
router.get("/:id/details", async (req, res) => {
  const { id } = req.params;
  try {
    // ── User ──────────────────────────────────────────────────
    const [users] = await db.query(
      `SELECT id, first_name, last_name, mobile, email, created_at,
              verified, role, profile_image, is_blocked
       FROM users WHERE id = ? AND role = 'care_seeker'`,
      [id]
    );
    if (!users.length) return res.status(404).json({ message: "User not found" });

    // ── Orders ────────────────────────────────────────────────
    const [orders] = await db.query(
      `SELECT o.id, o.order_code, o.status, o.total, o.payment_method,
              o.payment_status, o.cancel_reason, o.refund_amount,
              o.created_at, o.completed_at, o.cancelled_at,
              o.category, o.date, o.slot,
              GROUP_CONCAT(s.name SEPARATOR ', ') AS services
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       LEFT JOIN services s     ON s.id = oi.service_id
       WHERE o.user_id = ?
       GROUP BY o.id
       ORDER BY o.created_at DESC`,
      [id]
    );

    // ── Stats aggregation ────────────────────────────────────
    const [agg] = await db.query(
      `SELECT
         COUNT(*)                                          AS total_orders,
         SUM(status = 'COMPLETED')                        AS completed,
         SUM(status = 'CANCELLED')                        AS cancelled,
         SUM(status = 'PENDING')                          AS pending,
         SUM(status = 'ASSIGNED')                         AS assigned,
         COALESCE(SUM(CASE WHEN payment_status='PAID' THEN total ELSE 0 END), 0)    AS total_spent,
         COALESCE(SUM(refund_amount), 0)                  AS total_refunded,
         SUM(payment_method = 'COD')                      AS cod_orders,
         SUM(payment_method = 'RAZORPAY')                 AS online_orders
       FROM orders WHERE user_id = ?`,
      [id]
    );

    res.json({
      user:   users[0],
      stats:  agg[0],
      orders,
    });
  } catch (err) {
    console.error("CARESEEKER DETAIL ERROR:", err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;