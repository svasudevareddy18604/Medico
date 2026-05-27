// routes/adminnotification.routes.js
const express = require("express");
const router = express.Router();
const db = require("../config/db");
const multer = require("multer");
const schedule = require("node-schedule");
const cloudinary = require("cloudinary").v2;
const { sendPushNotification } = require("../utils/push");

/* ── CLOUDINARY CONFIG ── */
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/* ── MULTER (memory) ── */
const upload = multer({ storage: multer.memoryStorage() });

/* ── UPLOAD HELPER ── */
async function uploadToCloudinary(buffer) {
  return new Promise((resolve, reject) => {
    cloudinary.uploader
      .upload_stream({ folder: "notifications" }, (err, result) =>
        err ? reject(err) : resolve(result.secure_url)
      )
      .end(buffer);
  });
}

/* ── JOB STORE ── */
const scheduledJobs = {};

/* ── SEND HELPER ── */
async function sendToAudience(n) {
  try {
    // normalize audience to avoid case issues
    const audience = (n.audience || "ALL").toUpperCase();

    const audienceMap = {
      ALL: `
        SELECT DISTINCT fcm_token 
        FROM users 
        WHERE fcm_token IS NOT NULL 
        AND fcm_token != ''
      `,

      CARESEEKERS: `
        SELECT DISTINCT fcm_token 
        FROM users 
        WHERE role = 'care_seeker'
        AND fcm_token IS NOT NULL 
        AND fcm_token != ''
      `,

      CAREGIVERS: `
        SELECT DISTINCT fcm_token 
        FROM users 
        WHERE role = 'care_taker'
        AND fcm_token IS NOT NULL 
        AND fcm_token != ''
      `,
    };

    const sql = audienceMap[audience] || audienceMap.ALL;

    const [users] = await db.query(sql);

    console.log(`🚀 Sending "${n.title}" to ${users.length} ${audience} user(s)`);

    if (users.length === 0) {
      console.log("⚠️ No users found. Check roles / FCM tokens.");
    }

    let success = 0;
    let failed = 0;

    for (const u of users) {
      try {
        if (!u.fcm_token) continue;

        console.log("📤 Sending to:", u.fcm_token.substring(0, 25) + "...");

        await sendPushNotification(
          u.fcm_token,
          n.title,
          n.message,
          n.image_url
        );

        success++;
      } catch (e) {
        failed++;
        console.error("❌ Push failed:", e.message);
      }
    }

    console.log(`✅ Success: ${success}, ❌ Failed: ${failed}`);

    await db.query(
      "UPDATE notifications SET sent=1 WHERE id=?",
      [n.id]
    );

    console.log("✅ Notification marked as sent:", n.id);

  } catch (err) {
    console.error("❌ sendToAudience ERROR:", err);
  }
}

/* ── SCHEDULER ── */
function scheduleJob(id, scheduledAt) {
  // scheduledAt stored as UTC ISO string
  const date = new Date(scheduledAt);

  if (scheduledJobs[id]) {
    scheduledJobs[id].cancel();
    delete scheduledJobs[id];
  }

  if (date <= new Date()) {
    console.log("⏭ Past — skip scheduling:", id);
    return;
  }

  console.log(`⏳ Scheduled #${id} at ${date.toISOString()}`);

  scheduledJobs[id] = schedule.scheduleJob(date, async () => {
    const [rows] = await db.query("SELECT * FROM notifications WHERE id=?", [id]);
    if (rows.length) await sendToAudience(rows[0]);
  });
}

/* ── RESTORE JOBS ON STARTUP ── */
(async () => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM notifications WHERE sent=0 AND scheduled_at > NOW()"
    );
    rows.forEach((n) => scheduleJob(n.id, n.scheduled_at));
    console.log(`🔄 Restored ${rows.length} pending job(s)`);
  } catch (e) {
    console.error("Restore error:", e);
  }
})();

/* ══════════════════════════════════════════
   GET ALL
══════════════════════════════════════════ */
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM notifications ORDER BY id DESC"
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: "Failed to fetch" });
  }
});

/* ══════════════════════════════════════════
   CREATE
   Body: title, message, audience, scheduled_at (UTC ISO), timezone
   File: image (optional)
══════════════════════════════════════════ */
router.post("/", upload.single("image"), async (req, res) => {
  try {
    const { title, message, audience = "ALL", scheduled_at, timezone = "UTC" } = req.body;
    if (!title || !message || !scheduled_at)
      return res.status(400).json({ error: "Missing required fields" });

    // scheduled_at must arrive as UTC ISO string from client
    const utcDate = new Date(scheduled_at);

    let image_url = null;
    if (req.file) image_url = await uploadToCloudinary(req.file.buffer);

    const [result] = await db.query(
      `INSERT INTO notifications (title, message, audience, scheduled_at, timezone, image_url, sent)
       VALUES (?, ?, ?, ?, ?, ?, 0)`,
      [title, message, audience, utcDate, timezone, image_url]
    );

    scheduleJob(result.insertId, utcDate);
    res.json({ success: true, id: result.insertId, image_url });
  } catch (e) {
    console.error("CREATE:", e);
    res.status(500).json({ error: "Failed to create" });
  }
});

/* ══════════════════════════════════════════
   UPDATE (reschedule)
══════════════════════════════════════════ */
router.put("/:id", upload.single("image"), async (req, res) => {
  try {
    const { title, message, audience, scheduled_at, timezone = "UTC" } = req.body;
    const id = req.params.id;

    const utcDate = new Date(scheduled_at);

    let extra = "";
    const params = [title, message, audience, utcDate, timezone];

    if (req.file) {
      const url = await uploadToCloudinary(req.file.buffer);
      extra = ", image_url=?";
      params.push(url);
    }

    params.push(id);
    await db.query(
      `UPDATE notifications SET title=?, message=?, audience=?, scheduled_at=?, timezone=?, sent=0${extra} WHERE id=?`,
      params
    );

    scheduleJob(id, utcDate);       // cancel old + reschedule
    res.json({ success: true });
  } catch (e) {
    console.error("UPDATE:", e);
    res.status(500).json({ error: "Failed to update" });
  }
});

/* ══════════════════════════════════════════
   DELETE
══════════════════════════════════════════ */
router.delete("/:id", async (req, res) => {
  try {
    const id = req.params.id;
    if (scheduledJobs[id]) { scheduledJobs[id].cancel(); delete scheduledJobs[id]; }
    await db.query("DELETE FROM notifications WHERE id=?", [id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: "Failed to delete" });
  }
});

/* ══════════════════════════════════════════
   SEND NOW (manual trigger)
══════════════════════════════════════════ */
router.post("/:id/send-now", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM notifications WHERE id=?", [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: "Not found" });
    await sendToAudience(rows[0]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: "Send failed" });
  }
});

module.exports = router;