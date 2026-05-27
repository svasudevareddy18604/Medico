const express = require("express");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const router = express.Router();

const db = require("../config/db");
const transporter = require("../config/mailer");
const { sendPushNotification } = require("../services/pushNotification.service");

/* =====================================================
   RAZORPAY CONFIG
===================================================== */

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET
});

/* =====================================================
   COMMON RESPONSE
===================================================== */

const sendResponse = (res, success, message, data = {}) => {
  return res.json({ success, message, ...data });
};

/* =====================================================
   CREATE RAZORPAY ORDER
===================================================== */

router.post("/create-order", async (req, res) => {
  try {
    const { amount } = req.body;

    if (!amount || amount <= 0) {
      return sendResponse(res, false, "Invalid amount");
    }

    const order = await razorpay.orders.create({
      amount: amount,
      currency: "INR",
      receipt: "rcpt_" + Date.now()
    });

    return sendResponse(res, true, "Order created", {
      key: process.env.RAZORPAY_KEY_ID,
      order
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   VERIFY RAZORPAY PAYMENT (ONLINE)
===================================================== */

router.post("/verify", async (req, res) => {
  try {

    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      order_id,
      fcm_token
    } = req.body;

    /* ===== SIGNATURE VERIFY ===== */

    const body = razorpay_order_id + "|" + razorpay_payment_id;

    const expected = crypto
      .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest("hex");

    if (expected !== razorpay_signature) {
      return sendResponse(res, false, "Invalid payment");
    }

    /* ===== UPDATE ORDER (ONLINE = PAID) ===== */

    await db.query(
      `UPDATE orders 
       SET payment_id=?, status='CONFIRMED', payment_status='PAID' 
       WHERE id=?`,
      [razorpay_payment_id, order_id]
    );

    /* ===== GET ORDER DETAILS ===== */

    const [[order]] = await db.query(
      "SELECT latitude, longitude, category FROM orders WHERE id=?",
      [order_id]
    );

    const { latitude: lat, longitude: lng, category } = order;

    /* ===== GET RADIUS ===== */

    const [[setting]] = await db.query(
      "SELECT radius_km FROM settings LIMIT 1"
    );

    const radius = setting.radius_km;

    /* ===== FIND NEARBY CARETAKERS ===== */

    const [caretakers] = await db.query(
      `
      SELECT u.fcm_token, u.email
      FROM users u
      JOIN caretaker_profiles cp ON cp.user_id = u.id
      WHERE u.role='caretaker'
      
      AND (
        6371 * acos(
          cos(radians(?)) *
          cos(radians(cp.latitude)) *
          cos(radians(cp.longitude) - radians(?)) +
          sin(radians(?)) *
          sin(radians(cp.latitude))
        )
      ) <= ?
      `,
      [category, lat, lng, lat, radius]
    );

    sendResponse(res, true, "Payment verified");

    /* ===== BACKGROUND NOTIFICATIONS ===== */

    setImmediate(async () => {
      try {

        await Promise.all([
          ...caretakers
            .filter(c => c.fcm_token)
            .map(c =>
              sendPushNotification(
                c.fcm_token,
                "New Care Request",
                "New booking near you"
              )
            ),

          ...caretakers
            .filter(c => c.email)
            .map(c =>
              transporter.sendMail({
                to: c.email,
                subject: "New Booking",
                text: "A new care request is available"
              })
            )
        ]);

        if (fcm_token) {
          await sendPushNotification(
            fcm_token,
            "Booking Confirmed",
            "Your service is confirmed"
          );
        }

        console.log("✅ Notifications sent");

      } catch (err) {
        console.error("Notification error:", err);
      }
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   COD BOOKING (🔥 FIXED HERE)
===================================================== */

router.post("/cod-notification", async (req, res) => {
  try {

    const { order_id, fcm_token } = req.body;

    /* ✅ IMPORTANT FIX */
    await db.query(
      `UPDATE orders 
       SET status='CONFIRMED', payment_status='PENDING' 
       WHERE id=?`,
      [order_id]
    );

    sendResponse(res, true, "COD confirmed");

    setImmediate(async () => {
      if (fcm_token) {
        await sendPushNotification(
          fcm_token,
          "Booking Confirmed",
          "Your booking is confirmed"
        );
      }
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   CONFIRM PAYMENT (FOR COD BY CARETAKER)
===================================================== */

router.post("/confirm-payment", async (req, res) => {
  try {

    const { order_id } = req.body;

    await db.query(
      "UPDATE orders SET payment_status='PAID' WHERE id=?",
      [order_id]
    );

    return sendResponse(res, true, "Payment confirmed");

  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   COMPLETE SERVICE
===================================================== */

router.post("/complete-order", async (req, res) => {
  try {

    const { order_id } = req.body;

    await db.query(
      "UPDATE orders SET status='COMPLETED' WHERE id=?",
      [order_id]
    );

    return sendResponse(res, true, "Service completed");

  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false });
  }
});

module.exports = router;