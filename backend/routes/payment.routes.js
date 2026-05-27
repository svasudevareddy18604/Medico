const express = require("express");
const router = express.Router();

const { Cashfree } = require("cashfree-pg");

const db = require("../config/db");
const transporter = require("../config/mailer");
const { sendPushNotification } = require("../services/pushNotification.service");

/* =====================================================
   CASHFREE CONFIG
===================================================== */

Cashfree.XClientId = process.env.CASHFREE_APP_ID;
Cashfree.XClientSecret = process.env.CASHFREE_SECRET_KEY;
Cashfree.XEnvironment =
  process.env.NODE_ENV === "production" ? "PRODUCTION" : "SANDBOX";

/* =====================================================
   COMMON RESPONSE
===================================================== */

const sendResponse = (res, success, message, data = {}) =>
  res.json({ success, message, ...data });

/* =====================================================
   CREATE CASHFREE ORDER
===================================================== */

router.post("/create-order", async (req, res) => {
  try {
    const { amount, customer_id, customer_name, customer_email, customer_phone } =
      req.body;

    if (!amount || amount <= 0) {
      return sendResponse(res, false, "Invalid amount");
    }

    const orderId = "order_" + Date.now();

    const request = {
      order_amount: Number(amount),
      order_currency: "INR",
      order_id: orderId,
      customer_details: {
        customer_id: String(customer_id),
        customer_name,
        customer_email,
        customer_phone,
      },
      order_meta: {
        // Cashfree redirects here after payment — user returns to app via this URL
        return_url: "https://medico-1-qk02.onrender.com",
      },
    };

    const response = await Cashfree.PG.orders.create("2023-08-01", request);

    return sendResponse(res, true, "Order created", {
      payment_session_id: response.data.payment_session_id,
      payment_link:       response.data.payment_link,
      order_id:           response.data.order_id,
    });
  } catch (err) {
    console.error("CREATE ORDER ERROR:", err?.response?.data || err.message);
    return res.status(500).json({ success: false, message: "Order creation failed" });
  }
});

/* =====================================================
   VERIFY CASHFREE PAYMENT
===================================================== */

router.post("/verify", async (req, res) => {
  try {
    const { cashfree_order_id, order_id, fcm_token } = req.body;

    const response = await Cashfree.PG.orders.get("2023-08-01", cashfree_order_id);

    if (response.data.order_status !== "PAID") {
      return sendResponse(res, false, "Payment not completed");
    }

    await db.query(
      `UPDATE orders SET payment_id=?, status='CONFIRMED', payment_status='PAID' WHERE id=?`,
      [cashfree_order_id, order_id]
    );

    const [[order]] = await db.query(
      "SELECT latitude, longitude FROM orders WHERE id=?",
      [order_id]
    );

    const [[setting]] = await db.query(
      "SELECT radius_km FROM settings LIMIT 1"
    );

    const [caretakers] = await db.query(
      `SELECT u.fcm_token, u.email
       FROM users u
       JOIN caretaker_profiles cp ON cp.user_id = u.id
       WHERE u.role = 'caretaker'
       AND (
         6371 * acos(
           cos(radians(?)) * cos(radians(cp.latitude)) *
           cos(radians(cp.longitude) - radians(?)) +
           sin(radians(?)) * sin(radians(cp.latitude))
         )
       ) <= ?`,
      [order.latitude, order.longitude, order.latitude, setting.radius_km]
    );

    sendResponse(res, true, "Payment verified");

    setImmediate(async () => {
      try {
        await Promise.all([
          ...caretakers
            .filter((c) => c.fcm_token)
            .map((c) =>
              sendPushNotification(c.fcm_token, "New Care Request", "New booking near you")
            ),
          ...caretakers
            .filter((c) => c.email)
            .map((c) =>
              transporter.sendMail({
                to: c.email,
                subject: "New Booking",
                text: "A new care request is available near you.",
              })
            ),
        ]);
        if (fcm_token) {
          await sendPushNotification(fcm_token, "Booking Confirmed", "Your service is confirmed");
        }
        console.log("✅ Notifications sent");
      } catch (err) {
        console.error("Notification error:", err);
      }
    });
  } catch (err) {
    console.error("VERIFY ERROR:", err?.response?.data || err.message);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   COD BOOKING
===================================================== */

router.post("/cod-notification", async (req, res) => {
  try {
    const { order_id, fcm_token } = req.body;

    await db.query(
      `UPDATE orders SET status='CONFIRMED', payment_status='PENDING' WHERE id=?`,
      [order_id]
    );

    sendResponse(res, true, "COD confirmed");

    setImmediate(async () => {
      if (fcm_token) {
        await sendPushNotification(fcm_token, "Booking Confirmed", "Your booking is confirmed");
      }
    });
  } catch (err) {
    console.error("COD ERROR:", err.message);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   CONFIRM PAYMENT (COD — caretaker marks paid)
===================================================== */

router.post("/confirm-payment", async (req, res) => {
  try {
    const { order_id } = req.body;
    await db.query("UPDATE orders SET payment_status='PAID' WHERE id=?", [order_id]);
    return sendResponse(res, true, "Payment confirmed");
  } catch (err) {
    console.error("CONFIRM PAYMENT ERROR:", err.message);
    return res.status(500).json({ success: false });
  }
});

/* =====================================================
   COMPLETE SERVICE
===================================================== */

router.post("/complete-order", async (req, res) => {
  try {
    const { order_id } = req.body;
    await db.query("UPDATE orders SET status='COMPLETED' WHERE id=?", [order_id]);
    return sendResponse(res, true, "Service completed");
  } catch (err) {
    console.error("COMPLETE ORDER ERROR:", err.message);
    return res.status(500).json({ success: false });
  }
});

module.exports = router;