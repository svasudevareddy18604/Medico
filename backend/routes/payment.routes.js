const express = require("express");
const router = express.Router();
const axios = require("axios");
const db = require("../config/db");
const transporter = require("../config/mailer");
const { sendPushNotification } = require("../services/pushNotification.service");

const IS_SANDBOX = (process.env.CASHFREE_ENV || "SANDBOX").toUpperCase() !== "PRODUCTION";
const CF_BASE = IS_SANDBOX
  ? "https://sandbox.cashfree.com/pg"
  : "https://api.cashfree.com/pg";

const CF_CHECKOUT_BASE = IS_SANDBOX
  ? "https://sandbox.cashfree.com/checkout"
  : "https://payments.cashfree.com/order";

console.log("🔑 Cashfree ENV check:", {
  CASHFREE_ENV: process.env.CASHFREE_ENV || "(not set → defaulting to SANDBOX)",
  base: CF_BASE,
  app_id: process.env.CASHFREE_APP_ID
    ? `${process.env.CASHFREE_APP_ID.slice(0, 6)}…` : "❌ MISSING",
  secret: process.env.CASHFREE_SECRET_KEY
    ? `${process.env.CASHFREE_SECRET_KEY.slice(0, 4)}…` : "❌ MISSING",
});

const CF_HEADERS = () => ({
  "x-client-id":     process.env.CASHFREE_APP_ID,
  "x-client-secret": process.env.CASHFREE_SECRET_KEY,
  "x-api-version":   "2025-01-01",
  "Content-Type":    "application/json",
});

const ok  = (res, msg, data = {}) => res.json({ success: true,  message: msg, ...data });
const err = (res, msg, status = 500) => res.status(status).json({ success: false, message: msg });

// ── CREATE ORDER ─────────────────────────────────────────────────────────────
router.post("/create-order", async (req, res) => {
  const { amount, customer_id, customer_name, customer_email, customer_phone } = req.body;
  console.log("📦 create-order →", { amount, customer_id, env: process.env.NODE_ENV });

  if (!amount || Number(amount) <= 0) return err(res, "Invalid amount", 400);

  if (!process.env.CASHFREE_APP_ID || !process.env.CASHFREE_SECRET_KEY) {
    console.error("❌ Cashfree credentials missing!");
    return err(res, "Payment gateway not configured");
  }

  const orderId = `order_${Date.now()}`;
  const payload = {
    order_id:       orderId,
    order_amount:   Number(amount),
    order_currency: "INR",
    customer_details: {
      customer_id:    String(customer_id),
      customer_name:  customer_name  || "Medico User",
      customer_email: customer_email || "user@medico.in",
      customer_phone: customer_phone || "9999999999",
    },
    order_meta: {},
  };

  console.log("📤 Cashfree request →", CF_BASE, JSON.stringify(payload));

  try {
    const response = await axios.post(`${CF_BASE}/orders`, payload, {
      headers: CF_HEADERS(),
    });

    console.log("🔴 RAW CASHFREE RESPONSE:", JSON.stringify(response.data));

    const { payment_session_id, order_id } = response.data;

    if (!payment_session_id) {
      console.error("❌ No payment_session_id:", response.data);
      return err(res, "No payment session returned by gateway");
    }

    // Strip Cashfree sandbox bug suffix
    const cleanSession = payment_session_id
      .replace(/paymentpayment$/, "")
      .replace(/payment$/, "");

    const payment_url = `${CF_CHECKOUT_BASE}/#${cleanSession}`;
    console.log("🔗 Checkout URL:", payment_url);

    return ok(res, "Order created", { payment_session_id: cleanSession, order_id, payment_url });
  } catch (e) {
    const cfErr = e.response?.data;
    console.error("❌ CREATE ORDER ERROR:", cfErr || e.message);
    if (cfErr?.code === "authentication_error") {
      console.error("👉 Check CASHFREE_APP_ID and CASHFREE_SECRET_KEY");
    }
    return err(res, "Order creation failed");
  }
});

// ── VERIFY PAYMENT ───────────────────────────────────────────────────────────
router.post("/verify", async (req, res) => {
  const { cashfree_order_id, order_id, fcm_token } = req.body;
  console.log("🔍 verify →", { cashfree_order_id, order_id });

  if (!cashfree_order_id) return err(res, "cashfree_order_id required", 400);

  try {
    const response = await axios.get(`${CF_BASE}/orders/${cashfree_order_id}`, {
      headers: CF_HEADERS(),
    });

    const status = response.data.order_status;
    console.log("📊 Cashfree order status:", status);

    if (status !== "PAID") {
      console.log("⚠️ Payment not PAID, status:", status);
      return ok(res, "Payment not completed", { paid: false });
    }

    if (order_id && order_id !== 0) {
      await db.query(
        `UPDATE orders SET payment_id=?, status='CONFIRMED', payment_status='PAID' WHERE id=?`,
        [cashfree_order_id, order_id]
      );
    }

    ok(res, "Payment verified", { paid: true });

    setImmediate(async () => {
      try {
        if (!order_id || order_id === 0) return;
        const [[order]]    = await db.query("SELECT latitude, longitude FROM orders WHERE id=?", [order_id]);
        const [[setting]]  = await db.query("SELECT radius_km FROM settings LIMIT 1");
        const [caretakers] = await db.query(
          `SELECT u.fcm_token, u.email FROM users u
           JOIN caretaker_profiles cp ON cp.user_id = u.id
           WHERE u.role='caretaker'
           AND (6371 * acos(
             cos(radians(?)) * cos(radians(cp.latitude)) *
             cos(radians(cp.longitude) - radians(?)) +
             sin(radians(?)) * sin(radians(cp.latitude))
           )) <= ?`,
          [order.latitude, order.longitude, order.latitude, setting.radius_km]
        );

        await Promise.all([
          ...caretakers.filter(c => c.fcm_token).map(c =>
            sendPushNotification(c.fcm_token, "New Care Request", "New booking near you")),
          ...caretakers.filter(c => c.email).map(c =>
            transporter.sendMail({ to: c.email, subject: "New Booking", text: "New care request near you." })),
        ]);

        if (fcm_token) await sendPushNotification(fcm_token, "Booking Confirmed", "Your service is confirmed");
        console.log("✅ Notifications sent");
      } catch (e) { console.error("⚠️ Notification error:", e.message); }
    });
  } catch (e) {
    console.error("❌ VERIFY ERROR:", e.response?.data || e.message);
    return err(res, "Verification failed");
  }
});

// ── COD NOTIFICATION ─────────────────────────────────────────────────────────
router.post("/cod-notification", async (req, res) => {
  const { order_id, fcm_token } = req.body;
  console.log("💵 COD notification →", order_id);
  try {
    await db.query(`UPDATE orders SET status='CONFIRMED', payment_status='PENDING' WHERE id=?`, [order_id]);
    ok(res, "COD confirmed");
    setImmediate(async () => {
      if (fcm_token) await sendPushNotification(fcm_token, "Booking Confirmed", "Your booking is confirmed");
    });
  } catch (e) {
    console.error("❌ COD ERROR:", e.message);
    err(res, "COD failed");
  }
});

// ── CONFIRM PAYMENT ───────────────────────────────────────────────────────────
router.post("/confirm-payment", async (req, res) => {
  try {
    await db.query("UPDATE orders SET payment_status='PAID' WHERE id=?", [req.body.order_id]);
    return ok(res, "Payment confirmed");
  } catch (e) { return err(res, "Failed"); }
});

// ── COMPLETE ORDER ────────────────────────────────────────────────────────────
router.post("/complete-order", async (req, res) => {
  try {
    await db.query("UPDATE orders SET status='COMPLETED' WHERE id=?", [req.body.order_id]);
    return ok(res, "Service completed");
  } catch (e) { return err(res, "Failed"); }
});

module.exports = router;