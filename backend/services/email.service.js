const nodemailer = require("nodemailer");
const dns = require("dns");

// ✅ Prefer IPv4
dns.setDefaultResultOrder("ipv4first");

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 587,
  secure: false,
  family: 4, // ✅ critical fix
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  tls: {
    minVersion: "TLSv1.2", // ✅ secure fix
  },
});

const sendEmail = async (to, subject, html) => {
  try {
    await transporter.sendMail({
      from: `"Medico App" <${process.env.EMAIL_USER}>`,
      to,
      subject,
      html,
    });
    console.log(`✅ Email sent → ${to}`);
  } catch (err) {
    console.error(`❌ Email failed → ${to}:`, err.message);
  }
};

module.exports = { sendEmail };