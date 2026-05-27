// Run this file locally with: node debug_cashfree.js
// It will tell you exactly what's wrong

require("dotenv").config();
const axios = require("axios");

const appId     = process.env.CASHFREE_APP_ID;
const secretKey = process.env.CASHFREE_SECRET_KEY;
const nodeEnv   = process.env.NODE_ENV;

console.log("=== CASHFREE ENV CHECK ===");
console.log("NODE_ENV         :", nodeEnv || "(not set — defaults to sandbox)");
console.log("CASHFREE_APP_ID  :", appId     ? `"${appId}"` : "❌ MISSING");
console.log("CASHFREE_SECRET_KEY:", secretKey ? `"${secretKey.slice(0, 6)}..."` : "❌ MISSING");

if (!appId || !secretKey) {
  console.log("\n❌ STOP — one or both keys are missing from your .env file.");
  console.log("Make sure your .env has:\n  CASHFREE_APP_ID=your_app_id\n  CASHFREE_SECRET_KEY=your_secret_key");
  process.exit(1);
}

const CF_BASE = nodeEnv === "production"
  ? "https://api.cashfree.com/pg"
  : "https://sandbox.cashfree.com/pg";

console.log("\nHitting:", CF_BASE + "/orders");

async function test() {
  try {
    const res = await axios.post(
      `${CF_BASE}/orders`,
      {
        order_id:       "test_" + Date.now(),
        order_amount:   1,
        order_currency: "INR",
        customer_details: {
          customer_id:    "test_user",
          customer_name:  "Test User",
          customer_email: "test@test.com",
          customer_phone: "9999999999",
        },
        order_meta: {
          return_url: "https://medico-1-qk02.onrender.com",
        },
      },
      {
        headers: {
          "x-client-id":     appId,
          "x-client-secret": secretKey,
          "x-api-version":   "2023-08-01",
          "Content-Type":    "application/json",
        },
      }
    );
    console.log("\n✅ SUCCESS! Cashfree responded:");
    console.log("  order_id          :", res.data.order_id);
    console.log("  payment_session_id:", res.data.payment_session_id);
    console.log("  payment_link      :", res.data.payment_link);
  } catch (err) {
    console.log("\n❌ CASHFREE ERROR:");
    console.log(JSON.stringify(err.response?.data || err.message, null, 2));

    const data = err.response?.data;
    if (data?.code === "authentication_error" || data?.message?.includes("authentication")) {
      console.log("\n👉 FIX: Your App ID or Secret Key is wrong.");
      console.log("   Go to: https://merchant.cashfree.com/merchants/pg-dashboard");
      console.log("   → Credentials → copy the correct Sandbox keys.");
      console.log("   Make sure you are using SANDBOX keys (not production) when NODE_ENV != 'production'.");
    }
  }
}

test();