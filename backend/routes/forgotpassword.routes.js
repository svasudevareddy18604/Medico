const express = require("express");
const bcrypt = require("bcryptjs");
const db = require("../config/db");

const { sendEmail, otpTemplate } = require("../services/email.service");

const router = express.Router();

/* ================= PROMISE QUERY (WITH TIMEOUT) ================= */
const query = (sql, values) => {
  return new Promise((resolve, reject) => {

    const timer = setTimeout(() => {
      reject(new Error("DB TIMEOUT"));
    }, 5000);

    db.query(sql, values, (err, results) => {
      clearTimeout(timer);

      if (err) {
        console.error("❌ DB ERROR:", err);
        reject(err);
      } else {
        resolve(results);
      }
    });
  });
};

/* ================= SEND OTP ================= */
router.post("/send-otp", async (req, res) => {
  console.log("🔥 SEND OTP HIT:", req.body);

  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ message: "Email required" });
  }

  try {
    // 🔍 CHECK USER
    const users = await query(
      "SELECT * FROM users WHERE email = ?",
      [email]
    );

    if (users.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    // 🔥 GENERATE OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    // 🔥 DELETE OLD OTP (IMPORTANT)
    await query("DELETE FROM otp_codes WHERE email = ?", [email]);

    // 🔥 INSERT NEW OTP
    await query(
      "INSERT INTO otp_codes (email, otp, expires_at) VALUES (?, ?, ?)",
      [email, otp, expiresAt]
    );

    console.log("✅ OTP SAVED:", otp);

    // 🔥 SEND EMAIL WITH TIMEOUT
    await Promise.race([
      sendEmail(email, "Password Reset OTP", otpTemplate(otp)),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error("Email timeout")), 5000)
      )
    ]);

    return res.status(200).json({ message: "OTP sent successfully" });

  } catch (err) {
    console.error("❌ SEND OTP ERROR:", err);
    return res.status(500).json({ message: "Failed to send OTP" });
  }
});

/* ================= RESET PASSWORD ================= */
router.post("/reset-password", async (req, res) => {
  console.log("🔥 RESET PASSWORD HIT:", req.body);

  const { email, otp, newPassword } = req.body;

  if (!email || !otp || !newPassword) {
    return res.status(400).json({ message: "All fields required" });
  }

  try {
    // 🔥 STRICT OTP MATCH (FIXED)
    const results = await query(
      "SELECT * FROM otp_codes WHERE email = ? AND otp = ? LIMIT 1",
      [email, otp]
    );

    if (results.length === 0) {
      return res.status(400).json({ message: "Invalid OTP" });
    }

    const record = results[0];

    // 🔥 CHECK EXPIRY
    if (new Date() > new Date(record.expires_at)) {
      return res.status(400).json({ message: "OTP expired" });
    }

    // 🔐 HASH PASSWORD
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // 🔥 UPDATE PASSWORD
    await query(
      "UPDATE users SET password = ? WHERE email = ?",
      [hashedPassword, email]
    );

    // 🔥 DELETE OTP AFTER USE
    await query(
      "DELETE FROM otp_codes WHERE email = ?",
      [email]
    );

    console.log("✅ PASSWORD UPDATED");

    return res.status(200).json({
      message: "Password updated successfully"
    });

  } catch (err) {
    console.error("❌ RESET ERROR:", err);
    return res.status(500).json({
      message: err.message || "Server error"
    });
  }
});

module.exports = router;