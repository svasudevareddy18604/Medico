/**
 * ADMIN DASHBOARD SUMMARY ROUTE
 * -----------------------------
 * Mount this in your main app (e.g. app.js / server.js):
 *
 *   const adminDashboardRoutes = require("./routes/admin_dashboard.routes");
 *   app.use("/api/admin/dashboard", adminDashboardRoutes);
 *
 * This exposes: GET /api/admin/dashboard/summary
 * which matches Api.adminDashboardSummary in the Flutter app.
 */

const router = require("express").Router();
const db = require("../config/db");

router.get("/summary", async (req, res) => {
  try {
    // ---- TODAY'S NUMBERS ----
    const [[today]] = await db.query(
      `SELECT
         COUNT(*) AS today_bookings,
         COALESCE(SUM(CASE WHEN status != 'CANCELLED' THEN total ELSE 0 END), 0) AS today_revenue,
         COALESCE(SUM(CASE WHEN payment_status = 'PAID' THEN total ELSE 0 END), 0) AS today_collected,
         COALESCE(SUM(CASE WHEN status = 'CONFIRMED' THEN 1 ELSE 0 END), 0) AS confirmed_count,
         COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END), 0) AS completed_count,
         COALESCE(SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END), 0) AS cancelled_count,
         COALESCE(SUM(CASE WHEN payment_method = 'COD' AND status != 'CANCELLED' THEN 1 ELSE 0 END), 0) AS cod_count
       FROM orders
       WHERE DATE(created_at) = CURDATE()`
    );

    // ---- ALL-TIME NUMBERS (for context / trend) ----
    const [[allTime]] = await db.query(
      `SELECT
         COUNT(*) AS total_bookings,
         COALESCE(SUM(CASE WHEN status != 'CANCELLED' THEN total ELSE 0 END), 0) AS total_revenue
       FROM orders`
    );

    // ---- YESTERDAY (so the UI can show a trend arrow vs today) ----
    const [[yesterday]] = await db.query(
      `SELECT
         COUNT(*) AS bookings,
         COALESCE(SUM(CASE WHEN status != 'CANCELLED' THEN total ELSE 0 END), 0) AS revenue
       FROM orders
       WHERE DATE(created_at) = CURDATE() - INTERVAL 1 DAY`
    );

    // ---- TODAY'S BOOKING LIST (for the feed under the stat cards) ----
    const [todayOrders] = await db.query(
      `SELECT o.id, o.order_code, o.category, o.total, o.status,
              o.payment_status, o.payment_method, o.slot, o.date,
              o.created_at, o.location,
              GROUP_CONCAT(DISTINCT s.name SEPARATOR ', ') AS service_names
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       LEFT JOIN services s ON s.id = oi.service_id
       WHERE DATE(o.created_at) = CURDATE()
       GROUP BY o.id
       ORDER BY o.created_at DESC`
    );

    return res.json({
      success: true,
      today,
      yesterday,
      allTime,
      todayOrders,
    });
  } catch (err) {
    console.error("DASHBOARD SUMMARY ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load dashboard summary" });
  }
});

module.exports = router;