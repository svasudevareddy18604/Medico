const express = require("express");
const router  = express.Router();
const auth    = require("../controllers/auth.controller");

// ── FIX: Remove the useless middleware wrapper that added latency.
// The try/catch around a bare next() call serves no purpose — errors from
// auth.login are already caught inside the controller. Every login was paying
// the cost of an extra async function call + microtask tick for zero benefit.
router.post("/login",           auth.login);
router.post("/register",        auth.register);
router.post("/send-otp",        auth.sendOTP);
router.post("/verify-otp",      auth.verifyOTP);
router.post("/reset-password",  auth.resetPassword);
router.get( "/profile/:id",     auth.getUserProfile);

module.exports = router;