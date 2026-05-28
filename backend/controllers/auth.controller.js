const db        = require("../config/db");
const sendEmail = require("../config/mailer");
const bcrypt    = require("bcrypt");

/* ─── HELPERS ─────────────────────────────────────────────────────────────── */
const generateOTP = () => Math.floor(100000 + Math.random() * 900000);

/* ─── EMAIL BASE ──────────────────────────────────────────────────────────── */
const emailBase = (content) => `
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:#f0f2f5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased}
  .wrap{max-width:520px;margin:40px auto;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 16px rgba(0,0,0,.07)}
  .head{background:linear-gradient(135deg,#1B7F6E 0%,#25A98F 100%);padding:28px 32px;text-align:center}
  .head h1{color:#fff;font-size:17px;font-weight:600;letter-spacing:.3px;margin:0}
  .head p{color:rgba(255,255,255,.72);font-size:11.5px;margin-top:5px;letter-spacing:.2px}
  .body{padding:28px 32px}
  .note{font-size:13px;color:#4b5563;line-height:1.65;margin-bottom:6px}
  .card{background:#f8fffe;border:1px solid #d4f0ea;border-radius:10px;padding:18px 20px;margin:18px 0}
  .row{display:flex;justify-content:space-between;align-items:center;padding:7px 0;border-bottom:1px solid #e8f6f2;font-size:12.5px}
  .row:last-child{border-bottom:none}
  .row .l{color:#6b7280;font-weight:500}.row .v{color:#111827;font-weight:600;text-align:right}
  .otp-box{background:#f0fdf9;border:1.5px dashed #25A98F;border-radius:10px;padding:22px;margin:20px 0;text-align:center}
  .otp-code{font-size:34px;font-weight:700;letter-spacing:10px;color:#1B7F6E;font-family:'Courier New',monospace}
  .otp-hint{font-size:11.5px;color:#6b7280;margin-top:8px}
  .badge{display:inline-block;padding:3px 11px;border-radius:20px;font-size:11px;font-weight:700}
  .green{background:#e6f5f0;color:#1B7F6E}.red{background:#fde8e8;color:#c0392b}
  .divider{height:1px;background:#f3f4f6;margin:18px 0}
  .footer{background:#f9fafb;padding:18px 32px;text-align:center;border-top:1px solid #eeeeee}
  .footer p{color:#9ca3af;font-size:11px;margin:3px 0;line-height:1.6}
  .footer a{color:#1B7F6E;text-decoration:none;font-weight:600}
  .warn{background:#fffbeb;border-left:3px solid #f59e0b;border-radius:0 6px 6px 0;padding:10px 14px;font-size:12px;color:#92400e;margin-top:14px;line-height:1.6}
</style></head><body><div class="wrap">${content}</div></body></html>`;

const footer = `<div class="footer">
  <p>Questions? <a href="mailto:support@medico.com">support@medico.com</a></p>
  <p>© ${new Date().getFullYear()} Medico. All rights reserved. · <a href="#">Privacy Policy</a></p>
</div>`;

/* ─── OTP EMAIL TEMPLATE ──────────────────────────────────────────────────── */
const otpEmail = ({ otp, email }) => emailBase(`
  <div class="head"><h1>Password Reset Request</h1><p>Action required — verify your identity</p></div>
  <div class="body">
    <p class="note">We received a request to reset the password for <strong>${email}</strong>.</p>
    <p class="note" style="margin-top:6px">Use the one-time code below to proceed:</p>
    <div class="otp-box">
      <div class="otp-code">${otp}</div>
      <p class="otp-hint">Valid for <strong>5 minutes</strong> · Do not share this code</p>
    </div>
    <div class="warn">⚠️ If you didn't request this, you can safely ignore this email. Your password will not change.</div>
  </div>${footer}`);

/* ─── SEND OTP ────────────────────────────────────────────────────────────── */
exports.sendOTP = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ success: false, message: "Email required" });

    const otp    = generateOTP();
    const expiry = new Date(Date.now() + 5 * 60000);

    await db.query(
      "INSERT INTO otp_codes (email, otp, expires_at) VALUES (?, ?, ?)",
      [email, otp, expiry]
    );

    await sendEmail({
      to: email,
      subject: "Your Medico Password Reset OTP",
      html: otpEmail({ otp, email })
    });

    res.json({ success: true, message: "OTP sent" });

  } catch (err) {
    console.error("SEND OTP ERROR:", err);
    res.status(500).json({ success: false, message: "OTP sending failed" });
  }
};

/* ─── VERIFY OTP ──────────────────────────────────────────────────────────── */
exports.verifyOTP = async (req, res) => {
  try {
    const { email, otp } = req.body;

    const [rows] = await db.query(
      "SELECT * FROM otp_codes WHERE email = ? AND otp = ? AND expires_at > NOW()",
      [email, otp]
    );

    if (rows.length === 0)
      return res.status(400).json({ success: false, message: "Invalid or expired OTP" });

    await db.query("DELETE FROM otp_codes WHERE email = ?", [email]);

    res.json({ success: true, message: "OTP verified" });

  } catch (err) {
    console.error("OTP VERIFY ERROR:", err);
    res.status(500).json({ success: false, message: "Database error" });
  }
};

/* ─── RESET PASSWORD ──────────────────────────────────────────────────────── */
exports.resetPassword = async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword)
      return res.status(400).json({ success: false, message: "Email, OTP and new password required" });

    const [rows] = await db.query(
      "SELECT * FROM otp_codes WHERE email = ? AND otp = ? AND expires_at > NOW()",
      [email, otp]
    );

    if (rows.length === 0)
      return res.status(400).json({ success: false, message: "Invalid or expired OTP" });

    const hashedPassword = await bcrypt.hash(newPassword, 10);

    const [updateResult] = await db.query(
      "UPDATE users SET password = ? WHERE email = ?",
      [hashedPassword, email]
    );

    if (updateResult.affectedRows === 0)
      return res.status(404).json({ success: false, message: "User not found" });

    await db.query("DELETE FROM otp_codes WHERE email = ?", [email]);

    res.json({ success: true, message: "Password reset successful" });

  } catch (err) {
    console.error("RESET PASSWORD ERROR:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

/* ─── REGISTER ────────────────────────────────────────────────────────────── */
exports.register = async (req, res) => {
  try {
    const { first_name, last_name, mobile, email, password, role } = req.body;

    if (!role || !email || !password)
      return res.status(400).json({ success: false, message: "Required fields missing" });

    const hash = await bcrypt.hash(password, 10);

    await db.query(
      `INSERT INTO users
       (first_name, last_name, mobile, email, password, role, verified, profile_completed, approval_status, is_blocked)
       VALUES (?, ?, ?, ?, ?, ?, true, 0, 'pending', 0)`,
      [first_name, last_name, mobile, email, hash, role]
    );

    res.json({ success: true, message: "Account created" });

  } catch (err) {
    console.error("REGISTER ERROR:", err);
    if (err.code === "ER_DUP_ENTRY")
      return res.status(400).json({ success: false, message: "User already exists" });
    res.status(500).json({ success: false, message: "Database error" });
  }
};

/* ─── LOGIN ───────────────────────────────────────────────────────────────── */
exports.login = async (req, res) => {
  try {
    const { email, password, fcm_token } = req.body;

    if (!email || !password)
      return res.status(400).json({ success: false, message: "Email and password required" });

    // FIX 1: Split into two targeted queries instead of one heavy LEFT JOIN.
    //
    // The original single query always joined caretaker_profiles + ran a
    // correlated subquery COUNT(*) on caretaker_documents for EVERY login —
    // even for admins and care-seekers who never need that data.
    // Now we fetch only what every role needs first (lightweight), then fetch
    // caretaker-specific data only when the role actually requires it.
    //
    // FIX 2: SELECT only the columns we actually use.
    // Selecting * or unused columns forces MySQL to read and transmit extra
    // data over the connection. We now list exactly what the login response
    // needs, keeping the result row as small as possible.
    //
    // FIX 3: Ensure users.email has an index (add this to your DB if missing):
    //   ALTER TABLE users ADD INDEX idx_users_email (email);
    // Without an index, every login triggers a full table scan.
    const [rows] = await db.query(
      `SELECT id, first_name, last_name, email, role, password,
              profile_completed, approval_status, is_blocked
       FROM users
       WHERE email = ?
       LIMIT 1`,
      [email]
    );

    if (rows.length === 0)
      return res.status(404).json({ success: false, message: "User not found" });

    const user = rows[0];

    // FIX 4: Run bcrypt.compare and the is_blocked check in parallel with
    // nothing — bcrypt is the dominant cost (~100-300 ms CPU). We can't
    // avoid it, but we make sure nothing else waits before or after it
    // unnecessarily.
    if (user.is_blocked === 1)
      return res.status(403).json({
        success: false,
        message: "Account blocked. Please contact our support team for the reason.",
      });

    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch)
      return res.status(401).json({ success: false, message: "Wrong password" });

    // FIX 5: Fire the FCM token update WITHOUT awaiting it.
    // Waiting for a DB UPDATE that the client doesn't need in the response
    // adds 20-80 ms to every login for zero user-facing benefit.
    // We fire-and-forget it and let it complete in the background.
    if (fcm_token) {
      db.query("UPDATE users SET fcm_token = ? WHERE id = ?", [fcm_token, user.id])
        .catch((err) => console.error("FCM token update failed:", err));
    }

    // FIX 6: Fetch caretaker-specific fields only for care_taker role.
    // admins and care_seekers never need caregiver_type or documents_uploaded,
    // so we skip this query entirely for them — saving one round-trip.
    let caregiver_type      = null;
    let documents_uploaded  = 0;

    if (user.role === "care_taker") {
      const [ctRows] = await db.query(
        `SELECT cp.caregiver_type,
                (SELECT COUNT(*) FROM caretaker_documents cd WHERE cd.user_id = ?) AS doc_count
         FROM caretaker_profiles cp
         WHERE cp.user_id = ?
         LIMIT 1`,
        [user.id, user.id]
      );
      if (ctRows.length > 0) {
        caregiver_type     = ctRows[0].caregiver_type;
        documents_uploaded = ctRows[0].doc_count > 0 ? 1 : 0;
      }
    }

    return res.json({
      success:           true,
      id:                user.id,
      role:              user.role,
      email:             user.email,
      first_name:        user.first_name,
      last_name:         user.last_name,
      profile_completed: user.profile_completed,
      documents_uploaded,
      approval_status:   user.approval_status,
      caregiver_type,
    });

  } catch (err) {
    console.error("LOGIN ERROR:", err);
    res.status(500).json({ success: false, message: "Database error" });
  }
};

/* ─── GET USER PROFILE ────────────────────────────────────────────────────── */
exports.getUserProfile = async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT first_name, last_name, email FROM users WHERE id = ? LIMIT 1",
      [req.params.id]
    );

    if (rows.length === 0)
      return res.status(404).json({ success: false, message: "User not found" });

    res.json({ success: true, data: rows[0] });

  } catch (err) {
    console.error("PROFILE ERROR:", err);
    res.status(500).json({ success: false, message: "Database error" });
  }
};