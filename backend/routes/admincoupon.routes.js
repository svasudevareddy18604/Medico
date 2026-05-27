const express = require("express");
const router = express.Router();
const db = require("../config/db");
const multer = require("multer");
const path = require("path");

/* ================= MULTER ================= */

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/coupons");
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  },
});

const upload = multer({ storage });

/* ================= HELPER ================= */

const normalizeCouponData = (body, file) => {
  return {
    title: body.title || "",
    code: body.code || "",
    discount: Number(body.discount) || 0,
    discount_type: body.discount_type || "percentage",
    image: file ? `/uploads/coupons/${file.filename}` : null,
    is_active: body.is_active !== undefined ? body.is_active : 1,

    is_first_order: Number(body.is_first_order) || 0,
    min_services: Number(body.min_services) || 0,
    user_type: body.user_type || "all",

    service_id: body.service_id || null,
    category: body.category || null,

    min_order: Number(body.min_order) || 0,
    max_discount: body.max_discount ? Number(body.max_discount) : null,

    usage_limit: body.usage_limit ? Number(body.usage_limit) : null,
    per_user_limit: Number(body.per_user_limit) || 1,

    start_time: body.start_time || null,
    end_time: body.end_time || null,
  };
};

/* ================= CREATE ================= */

router.post("/", upload.single("image"), async (req, res) => {
  try {
    const data = normalizeCouponData(req.body, req.file);

    if (!data.code || data.discount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Code and valid discount required",
      });
    }

    await db.query(
      `INSERT INTO coupons (
        title, code, discount, discount_type, image, is_active,
        is_first_order, min_services, user_type,
        service_id, category,
        min_order, max_discount,
        usage_limit, per_user_limit,
        start_time, end_time
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        data.title,
        data.code,
        data.discount,
        data.discount_type,
        data.image,
        data.is_active,

        data.is_first_order,
        data.min_services,
        data.user_type,

        data.service_id,
        data.category,

        data.min_order,
        data.max_discount,

        data.usage_limit,
        data.per_user_limit,

        data.start_time,
        data.end_time,
      ]
    );

    res.json({ success: true, message: "Coupon created" });
  } catch (err) {
    console.error("CREATE ERROR:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ================= GET ALL ================= */

router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM coupons ORDER BY id DESC"
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ================= GET ONE ================= */

router.get("/:id", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM coupons WHERE id = ?",
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: "Not found" });
    }

    res.json({ success: true, data: rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ================= UPDATE ================= */

router.put("/:id", upload.single("image"), async (req, res) => {
  try {
    const [existing] = await db.query(
      "SELECT * FROM coupons WHERE id = ?",
      [req.params.id]
    );

    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: "Not found" });
    }

    const old = existing[0];
    const data = normalizeCouponData(req.body, req.file);

    const updatedImage = data.image || old.image;

    await db.query(
      `UPDATE coupons SET
        title=?, code=?, discount=?, discount_type=?, image=?, is_active=?,
        is_first_order=?, min_services=?, user_type=?,
        service_id=?, category=?,
        min_order=?, max_discount=?,
        usage_limit=?, per_user_limit=?,
        start_time=?, end_time=?
      WHERE id=?`,
      [
        data.title,
        data.code,
        data.discount,
        data.discount_type,
        updatedImage,
        data.is_active,

        data.is_first_order,
        data.min_services,
        data.user_type,

        data.service_id,
        data.category,

        data.min_order,
        data.max_discount,

        data.usage_limit,
        data.per_user_limit,

        data.start_time,
        data.end_time,

        req.params.id,
      ]
    );

    res.json({ success: true, message: "Coupon updated" });
  } catch (err) {
    console.error("UPDATE ERROR:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ================= DELETE ================= */

router.delete("/:id", async (req, res) => {
  try {
    const [result] = await db.query(
      "DELETE FROM coupons WHERE id = ?",
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: "Not found" });
    }

    res.json({ success: true, message: "Deleted successfully" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

/* ================= TOGGLE STATUS ================= */

router.patch("/:id/status", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT is_active FROM coupons WHERE id = ?",
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: "Not found" });
    }

    const newStatus = rows[0].is_active === 1 ? 0 : 1;

    await db.query(
      "UPDATE coupons SET is_active = ? WHERE id = ?",
      [newStatus, req.params.id]
    );

    res.json({ success: true, is_active: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;