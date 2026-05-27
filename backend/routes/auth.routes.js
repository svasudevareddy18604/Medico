const express = require("express");
const router = express.Router();

const auth = require("../controllers/auth.controller");

/* =========================
   SEND OTP
========================= */
router.post("/send-otp", async (req, res, next) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required"
      });
    }

    next();
  } catch (err) {
    next(err);
  }
}, auth.sendOTP);


/* =========================
   VERIFY OTP
========================= */
router.post("/verify-otp", async (req, res, next) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Email and OTP required"
      });
    }

    next();
  } catch (err) {
    next(err);
  }
}, auth.verifyOTP);


/* =========================
   RESET PASSWORD (🔥 YOU WERE MISSING THIS)
========================= */
router.post("/reset-password", async (req, res, next) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Email, OTP and new password required"
      });
    }

    // 🔥 basic password validation
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters"
      });
    }

    next();
  } catch (err) {
    next(err);
  }
}, auth.resetPassword);


/* =========================
   REGISTER
========================= */
router.post("/register", async (req, res, next) => {
  try {
    const {
      first_name,
      last_name,
      mobile,
      email,
      password,
      role
    } = req.body;

    if (!first_name || !last_name || !mobile || !email || !password || !role) {
      return res.status(400).json({
        success: false,
        message: "All fields are mandatory"
      });
    }

    if (!["care_seeker", "care_taker"].includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role"
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters"
      });
    }

    next();
  } catch (err) {
    next(err);
  }
}, auth.register);


/* =========================
   LOGIN
========================= */
router.post("/login", async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password required"
      });
    }

    next();
  } catch (err) {
    next(err);
  }
}, auth.login);


/* =========================
   GET USER PROFILE
========================= */
router.get("/user/:id", async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({
        success: false,
        message: "User id required"
      });
    }

    next();
  } catch (err) {
    next(err);
  }
}, auth.getUserProfile);


/* =========================
   GLOBAL ERROR HANDLER (🔥 IMPORTANT)
========================= */
router.use((err, req, res, next) => {
  console.error("ROUTE ERROR:", err);

  res.status(500).json({
    success: false,
    message: "Internal Server Error"
  });
});

module.exports = router;