const express = require("express");
const router = express.Router();

const { Cashfree, CFEnvironment } = require("cashfree-pg");

const db = require("../config/db");
const transporter = require("../config/mailer");
const { sendPushNotification } = require("../services/pushNotification.service");

/* =====================================================
   CASHFREE CONFIG
===================================================== */

Cashfree.XClientId = process.env.CASHFREE_APP_ID;
Cashfree.XClientSecret = process.env.CASHFREE_SECRET_KEY;
Cashfree.XEnvironment =
  process.env.NODE_ENV === "production"
    ? CFEnvironment.PRODUCTION
    : CFEnvironment.SANDBOX;

/* =====================================================
   COMMON RESPONSE
===================================================== */

const sendResponse = (res, success, message, data = {}) => {
  return res.json({ success, message, ...data });
};

/* =====================================================
   CREATE CASHFREE ORDER
===================================================== */

router.post("/create-order", async (req, res) => {
  try {
    const {
      amount,
      customer_id,
      customer_name,
      customer_email,
      customer_phone
    } = req.body;

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
        customer_phone
      },
      order_meta: {
        return_url:
          "https://yourdomain.com/payment-success?order_id={order_id}"
      }
    };

    const response = await Cashfree.PGCreateOrder("2023-08-01", request);

    return sendResponse(res, true, "Order created", {
      payment_session_id: response.data.payment_session_id,
      order_id: orderId
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: "Order creation failed" });
  }
});

/* =====================================================
   VERIFY CASHFREE PAYMENT (ONLINE)
===================================================== */

router.post("/verify", async (req, res) => {
  try {
    const { cashfree_order_id, order_id, fcm_token } = req.body;

    const response = await Cashfree.PGFetchOrder("2023-08-01", cashfree_order_id);

    const orderStatus = response.data.order_status;

    if (orderStatus !== "PAID") {
      return sendResponse(res, false, "Payment not completed");
    }

    /* ===== UPDATE ORDER ===== */

    await db.query(
      `UPDATE orders 
       SET payment_id=?, status='CONFIRMED', payment_status='PAID' 
       WHERE id=?`,
      [cashfree_order_id, order_id]
    );

    /* ===== GET ORDER DETAILS ===== */

    const [[order]] = await db.query(
      "SELECT latitude, longitude, category FROM orders WHERE id=?",
      [order_id]
    );

    const { latitude: lat, longitude: lng } = order;

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
      WHERE u.role = 'caretaker'
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
      [lat, lng, lat, radius]
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
   COD BOOKING
===================================================== */

router.post("/cod-notification", async (req, res) => {
  try {
    const { order_id, fcm_token } = req.body;

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