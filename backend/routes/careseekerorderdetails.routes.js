const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================================
   GET BOOKING DETAILS (order_code + live tracking + verified tick)
========================================================= */

router.get("/:orderId", async (req, res) => {
  try {
    const { orderId } = req.params;

    /* -----------------------------------------------------
       FETCH ORDER + CARETAKER DETAILS
       Now also pulls:
         - live coordinates (user + caretaker) for map tracking
         - caretaker's approval_status for the verified blue tick
         - subtotal / service_charge / discount / coupon / category
         - refund fields
    ----------------------------------------------------- */

    const query = `
      SELECT 
        o.id,
        o.order_code,
        o.location,
        o.date,
        o.slot,
        o.total,
        o.subtotal,
        o.service_charge,
        o.discount_amount,
        o.coupon_code,
        o.category,
        o.payment_method,
        o.payment_id,
        o.status,
        o.caretaker_response,
        o.accepted_at,
        o.completed_at,
        o.cancelled_at,
        o.cancel_reason,
        o.created_at,
        o.caretaker_id,

        -- live location columns used for the map
        o.latitude,
        o.longitude,
        o.caretaker_latitude,
        o.caretaker_longitude,

        -- refund info
        o.refund_status,
        o.refund_amount,

        u.first_name,
        u.last_name,
        u.mobile,
        u.profile_image        AS caretaker_profile_image,
        u.approval_status      AS caretaker_approval_status

      FROM orders o

      LEFT JOIN users u
      ON o.caretaker_id = u.id

      WHERE o.id = ?
    `;

    const [rows] = await db.query(query, [orderId]);

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Booking not found"
      });
    }

    const order = rows[0];

    /* -----------------------------------------------------
       CARETAKER DETAILS
    ----------------------------------------------------- */

    let caregiver_name = null;
    let caregiver_phone = null;
    let caregiver_verified = false;

    if (order.caretaker_id) {
      caregiver_name =
        ((order.first_name || "") + " " + (order.last_name || "")).trim();
      caregiver_phone = order.mobile;
      // "Professional (Verified)" tick maps directly to the caretaker's
      // admin-side approval status — approved caretakers get the blue tick.
      caregiver_verified = order.caretaker_approval_status === "approved";
    }

    /* -----------------------------------------------------
       PAYMENT STATUS LOGIC
    ----------------------------------------------------- */

    let payment_status = "Pending";

    if (order.payment_method === "RAZORPAY" && order.status !== "CANCELLED") {
      payment_status = "Paid";
    }

    if (order.payment_method === "COD" && order.status === "COMPLETED") {
      payment_status = "Paid";
    }

    if (order.status === "CANCELLED") {
      payment_status = "Cancelled";
    }

    /* -----------------------------------------------------
       BOOKING PROGRESS (RENAMED, display-only convenience field)
    ----------------------------------------------------- */

    let progress = "Booking Placed";

    if (order.status === "CANCELLED") {
      progress = "Cancelled";
    } else if (order.caretaker_response === "ACCEPTED") {
      progress = "Caretaker Accepted";
    } else if (order.status === "ON_THE_WAY") {
      progress = "On The Way";
    } else if (order.status === "COMPLETED") {
      progress = "Completed";
    }

    /* -----------------------------------------------------
       FINAL RESPONSE
    ----------------------------------------------------- */

    const response = {
      id: order.id,

      order_code: order.order_code,

      location: order.location,
      date: order.date,
      slot: order.slot,
      category: order.category,

      total: order.total,
      subtotal: order.subtotal,
      service_charge: order.service_charge,
      discount_amount: order.discount_amount,
      coupon_code: order.coupon_code,

      payment_method: order.payment_method,
      payment_status: payment_status,

      status: order.status,
      caretaker_response: order.caretaker_response,
      progress: progress,

      cancel_reason: order.cancel_reason || null,
      refund_status: order.refund_status,
      refund_amount: order.refund_amount,

      caretaker_id: order.caretaker_id,
      caregiver_name,
      caregiver_phone,
      caregiver_verified,          // ✅ drives the blue tick
      caretaker_profile_image: order.caretaker_profile_image,

      // ✅ these four drive the live map
      latitude: order.latitude,
      longitude: order.longitude,
      caretaker_latitude: order.caretaker_latitude,
      caretaker_longitude: order.caretaker_longitude,

      accepted_at: order.accepted_at,
      completed_at: order.completed_at,
      created_at: order.created_at
    };

    return res.json({
      success: true,
      order: response
    });

  } catch (error) {
    console.error("BOOKING DETAILS ERROR:", error);
    return res.status(500).json({
      success: false,
      message: "Server error"
    });
  }
});

module.exports = router;