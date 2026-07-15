const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const db = require("../config/db"); // mysql2/promise pool — adjust path if yours differs

// ── Multer setup for complaint images ──────────────────────────────
const uploadDir = path.join(__dirname, "..", "uploads", "complaints");
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, unique);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024, files: 5 }, // 5MB/file, max 5 files
  fileFilter: (req, file, cb) => {
    const allowed = [".jpg", ".jpeg", ".png", ".webp"];
    if (!allowed.includes(path.extname(file.originalname).toLowerCase())) {
      return cb(new Error("Only image files are allowed"));
    }
    cb(null, true);
  },
});

// ══════════════════════════════════════════════════════════════════
//  CARE-SEEKER ENDPOINTS
// ══════════════════════════════════════════════════════════════════

// POST /api/complaints — submit a new complaint (multipart/form-data)
router.post("/complaints", upload.array("images", 5), async (req, res) => {
  try {
    const { user_id, category, description } = req.body;

    if (!user_id || !category || !description) {
      return res.status(400).json({
        success: false,
        message: "user_id, category and description are required.",
      });
    }

    const imagePaths = (req.files || []).map(
      (f) => `uploads/complaints/${f.filename}`
    );

    const [result] = await db.query(
      `INSERT INTO complaints (user_id, category, description, images, status)
       VALUES (?, ?, ?, ?, 'pending')`,
      [user_id, category, description, JSON.stringify(imagePaths)]
    );

    const [rows] = await db.query(`SELECT * FROM complaints WHERE id = ?`, [
      result.insertId,
    ]);

    return res.status(201).json({ success: true, complaint: rows[0] });
  } catch (err) {
    console.error("SUBMIT COMPLAINT ERROR:", err);
    return res.status(500).json({
      success: false,
      message: "Something went wrong. Please try again.",
    });
  }
});

// GET /api/complaints/user/:userId — care-seeker's own complaints
router.get("/complaints/user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const [rows] = await db.query(
      `SELECT * FROM complaints WHERE user_id = ? ORDER BY created_at DESC`,
      [userId]
    );
    return res.status(200).json({ success: true, complaints: rows });
  } catch (err) {
    console.error("FETCH USER COMPLAINTS ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load complaints." });
  }
});

// GET /api/complaints/:id — single complaint (used by user + admin)
router.get("/complaints/:id", async (req, res) => {
  try {
    const [rows] = await db.query(`SELECT * FROM complaints WHERE id = ?`, [
      req.params.id,
    ]);
    if (!rows.length) {
      return res.status(404).json({ success: false, message: "Complaint not found." });
    }
    return res.status(200).json({ success: true, complaint: rows[0] });
  } catch (err) {
    console.error("FETCH COMPLAINT ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load complaint." });
  }
});

// ══════════════════════════════════════════════════════════════════
//  ADMIN ENDPOINTS
// ══════════════════════════════════════════════════════════════════

// GET /api/admin/complaints — list ALL complaints, optional ?status=pending
router.get("/admin/complaints", async (req, res) => {
  try {
    const { status } = req.query;
    let sql = `
      SELECT c.*, u.first_name, u.last_name, u.email
      FROM complaints c
      LEFT JOIN users u ON u.id = c.user_id
    `;
    const params = [];
    if (status) {
      sql += ` WHERE c.status = ?`;
      params.push(status);
    }
    sql += ` ORDER BY c.created_at DESC`;

    const [rows] = await db.query(sql, params);
    return res.status(200).json({ success: true, complaints: rows });
  } catch (err) {
    console.error("ADMIN FETCH COMPLAINTS ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load complaints." });
  }
});

// PUT /api/admin/complaints/status/:id — admin updates status (+ optional reply)
router.put("/admin/complaints/status/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { status, admin_response } = req.body;

    const allowed = ["pending", "in_progress", "resolved", "rejected"];
    if (!allowed.includes(status)) {
      return res.status(400).json({ success: false, message: "Invalid status value." });
    }

    const resolvedAt = ["resolved", "rejected"].includes(status) ? new Date() : null;

    await db.query(
      `UPDATE complaints
       SET status = ?, admin_response = ?, resolved_at = ?
       WHERE id = ?`,
      [status, admin_response || null, resolvedAt, id]
    );

    const [rows] = await db.query(`SELECT * FROM complaints WHERE id = ?`, [id]);
    if (!rows.length) {
      return res.status(404).json({ success: false, message: "Complaint not found." });
    }

    return res.status(200).json({ success: true, complaint: rows[0] });
  } catch (err) {
    console.error("ADMIN UPDATE COMPLAINT STATUS ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to update complaint." });
  }
});

module.exports = router;