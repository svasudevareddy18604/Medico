const express = require("express");
const router = express.Router();
const db = require("../config/db"); // adjust to your actual db/pool path

/* =========================================
   GET /api/caretaker/performance/:caretakerId
========================================= */
router.get("/:caretakerId", async (req, res) => {
  try {
    const { caretakerId } = req.params;

    const [[jobStats]] = await db.query(`
      SELECT
        COUNT(*) AS total_jobs,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_jobs,
        SUM(CASE WHEN status IN ('CANCELLED','CARETAKER_CANCELLED') THEN 1 ELSE 0 END) AS cancelled_jobs,
        SUM(CASE WHEN status IN ('ACCEPTED','CONFIRMED','IN_PROGRESS') THEN 1 ELSE 0 END) AS active_jobs
      FROM orders
      WHERE caretaker_id = ?
    `, [caretakerId]);

    const totalJobs     = Number(jobStats.total_jobs || 0);
    const completedJobs = Number(jobStats.completed_jobs || 0);
    const cancelledJobs = Number(jobStats.cancelled_jobs || 0);
    const activeJobs    = Number(jobStats.active_jobs || 0);
    const completionRate = totalJobs > 0
      ? Number(((completedJobs / totalJobs) * 100).toFixed(1))
      : 0;

    const [[earningStats]] = await db.query(`
      SELECT
        COALESCE(SUM(caretaker_amount), 0) AS total_earnings,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN caretaker_amount ELSE 0 END), 0) AS pending_earnings,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN caretaker_amount ELSE 0 END), 0) AS paid_earnings
      FROM earnings
      WHERE caretaker_id = ?
    `, [caretakerId]);

    const [[thisMonth]] = await db.query(`
      SELECT
        COALESCE(SUM(e.caretaker_amount), 0) AS this_month_earnings,
        COUNT(DISTINCT o.id) AS this_month_jobs
      FROM orders o
      LEFT JOIN earnings e ON e.order_id = o.id AND e.caretaker_id = o.caretaker_id
      WHERE o.caretaker_id = ?
        AND o.status = 'COMPLETED'
        AND MONTH(o.completed_at) = MONTH(CURDATE())
        AND YEAR(o.completed_at) = YEAR(CURDATE())
    `, [caretakerId]);

    const [[ratingStats]] = await db.query(`
      SELECT
        COALESCE(AVG(rating), 0) AS avg_rating,
        COUNT(*) AS total_reviews,
        SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) AS five_star,
        SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) AS four_star,
        SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) AS three_star,
        SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) AS two_star,
        SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) AS one_star
      FROM feedback
      WHERE caregiver_id = ?
    `, [caretakerId]);

    const [monthlyTrend] = await db.query(`
      SELECT
        DATE_FORMAT(o.completed_at, '%Y-%m') AS month_key,
        DATE_FORMAT(o.completed_at, '%b') AS month_label,
        COUNT(DISTINCT o.id) AS jobs,
        COALESCE(SUM(e.caretaker_amount), 0) AS earnings
      FROM orders o
      LEFT JOIN earnings e ON e.order_id = o.id AND e.caretaker_id = o.caretaker_id
      WHERE o.caretaker_id = ?
        AND o.status = 'COMPLETED'
        AND o.completed_at >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
      GROUP BY month_key, month_label
      ORDER BY month_key ASC
    `, [caretakerId]);

    const [categoryBreakdown] = await db.query(`
      SELECT category, COUNT(*) AS count
      FROM orders
      WHERE caretaker_id = ? AND status = 'COMPLETED'
      GROUP BY category
      ORDER BY count DESC
    `, [caretakerId]);

    return res.json({
      success: true,
      data: {
        total_jobs: totalJobs,
        completed_jobs: completedJobs,
        cancelled_jobs: cancelledJobs,
        active_jobs: activeJobs,
        completion_rate: completionRate,

        total_earnings: Number(earningStats.total_earnings),
        pending_earnings: Number(earningStats.pending_earnings),
        paid_earnings: Number(earningStats.paid_earnings),
        this_month_earnings: Number(thisMonth.this_month_earnings),
        this_month_jobs: Number(thisMonth.this_month_jobs),

        avg_rating: Number(Number(ratingStats.avg_rating).toFixed(1)),
        total_reviews: Number(ratingStats.total_reviews),
        rating_breakdown: {
          5: Number(ratingStats.five_star),
          4: Number(ratingStats.four_star),
          3: Number(ratingStats.three_star),
          2: Number(ratingStats.two_star),
          1: Number(ratingStats.one_star),
        },

        monthly_trend: monthlyTrend.map(m => ({
          month: m.month_label,
          jobs: Number(m.jobs),
          earnings: Number(m.earnings),
        })),

        category_breakdown: categoryBreakdown.map(c => ({
          category: c.category,
          count: Number(c.count),
        })),
      },
    });

  } catch (err) {
    console.error("🔥 PERFORMANCE ANALYTICS ERROR:", err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;