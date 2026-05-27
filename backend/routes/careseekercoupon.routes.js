const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================
   GET AVAILABLE COUPONS FOR CARESEEKER
========================================= */
router.get("/", async (req, res) => {
  try {
    const { user_id } = req.query;

    let isFirstTimeUser = false;

    // Check if user has placed any previous order (using 'orders' table)
    if (user_id) {
      const [orderRows] = await db.query(
        "SELECT COUNT(*) as total_orders FROM orders WHERE user_id = ?",
        [user_id]
      );
      isFirstTimeUser = orderRows[0].total_orders === 0;
    }

    const query = `
      SELECT 
        id, 
        title, 
        code, 
        discount, 
        discount_type,
        min_order, 
        max_discount, 
        is_first_order,
        usage_limit, 
        per_user_limit,
        image
      FROM coupons 
      WHERE is_active = 1 
        AND (start_time IS NULL OR start_time <= NOW())
        AND (end_time IS NULL OR end_time >= NOW())
      ORDER BY discount DESC, min_order ASC
    `;

    const [coupons] = await db.query(query);

    // Filter first-order coupons
    const filteredCoupons = coupons.filter(coupon => {
      if (coupon.is_first_order === 1) {
        return isFirstTimeUser;
      }
      return true;
    });

    res.json({
      success: true,
      data: filteredCoupons,
      isFirstTimeUser: isFirstTimeUser
    });

  } catch (err) {
    console.error("Fetch Coupons Error:", err);
    res.status(500).json({
      success: false,
      message: "Failed to fetch coupons"
    });
  }
});

/* =========================================
   VALIDATE COUPON (Extra Safety)
========================================= */
router.post("/validate", async (req, res) => {
  try {
    const { user_id, code, total_amount } = req.body;

    if (!user_id || !code || total_amount == null) {
      return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    const [couponRows] = await db.query(
      `SELECT * FROM coupons 
       WHERE code = ? AND is_active = 1 
       AND (start_time IS NULL OR start_time <= NOW())
       AND (end_time IS NULL OR end_time >= NOW())`,
      [code]
    );

    if (couponRows.length === 0) {
      return res.status(400).json({ success: false, message: "Invalid or expired coupon" });
    }

    const coupon = couponRows[0];

    // First Order Check
    if (coupon.is_first_order === 1) {
      const [orderRows] = await db.query(
        "SELECT COUNT(*) as total FROM orders WHERE user_id = ?",
        [user_id]
      );

      if (orderRows[0].total > 0) {
        return res.status(400).json({
          success: false,
          message: "This coupon is valid only for first-time users"
        });
      }
    }

    // Minimum Order Check
    if (coupon.min_order && Number(total_amount) < Number(coupon.min_order)) {
      return res.status(400).json({
        success: false,
        message: `Minimum order amount is ₹${coupon.min_order}`
      });
    }

    // Calculate Discount
    let discountAmount = 0;
    if (coupon.discount_type === "percentage") {
      discountAmount = (Number(total_amount) * Number(coupon.discount)) / 100;
      if (coupon.max_discount) {
        discountAmount = Math.min(discountAmount, Number(coupon.max_discount));
      }
    } else {
      discountAmount = Number(coupon.discount);
    }

    res.json({
      success: true,
      message: "Coupon applied successfully",
      data: {
        code: coupon.code,
        discount: Math.round(discountAmount),
        discount_type: coupon.discount_type,
      }
    });

  } catch (err) {
    console.error("Coupon Validate Error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;