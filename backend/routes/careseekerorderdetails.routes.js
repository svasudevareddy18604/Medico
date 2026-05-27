const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================================================
   GET BOOKING DETAILS (WITH order_code SUPPORT)
========================================================= */

router.get("/:orderId", async (req, res) => {
  try {
    const { orderId } = req.params;

    /* -----------------------------------------------------
       FETCH ORDER + CARETAKER DETAILS
       (NOW INCLUDES order_code)
    ----------------------------------------------------- */

    const query = `
      SELECT 
        o.id,
        o.order_code,  -- ✅ IMPORTANT
        o.location,
        o.date,
        o.slot,
        o.total,
        o.payment_method,
        o.payment_id,
        o.status,
        o.caretaker_response,
        o.accepted_at,
        o.caretaker_id,
        o.cancel_reason,
        o.created_at,

        u.first_name,
        u.last_name,
        u.mobile

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

    if (order.caretaker_id) {
      caregiver_name =
        ((order.first_name || "") + " " + (order.last_name || "")).trim();
      caregiver_phone = order.mobile;
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
       BOOKING PROGRESS (RENAMED)
    ----------------------------------------------------- */

    let progress = "Booking Placed";

    if (order.status === "CANCELLED") {
      progress = "Cancelled";
    } else if (order.caretaker_response === "ACCEPTED") {
      progress = "Caretaker Accepted";
    } else if (order.status === "IN_PROGRESS") {
      progress = "On The Way";
    } else if (order.status === "COMPLETED") {
      progress = "Completed";
    }

    /* -----------------------------------------------------
       FINAL RESPONSE
    ----------------------------------------------------- */

    const response = {
      id: order.id, // internal use only

      // ✅ THIS is what frontend should show
      order_code: order.order_code,

      location: order.location,
      date: order.date,
      slot: order.slot,
      total: order.total,

      payment_method: order.payment_method,
      payment_status: payment_status,

      status: order.status,
      caretaker_response: order.caretaker_response,
      progress: progress,

      cancel_reason: order.cancel_reason || null,

      caretaker_id: order.caretaker_id,
      caregiver_name,
      caregiver_phone,

      accepted_at: order.accepted_at,
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