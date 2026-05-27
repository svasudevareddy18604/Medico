const express = require("express");
const router = express.Router();
const db = require("../config/db");
const multer = require("multer");
const path = require("path");

/* ================= MULTER SETUP ================= */

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/promotions/");
  },
  filename: (req, file, cb) => {
    const unique =
      Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  },
});

const upload = multer({ storage });

/* ================= CREATE ================= */

router.post("/", upload.single("media"), async (req, res) => {
  try {
    const { title } = req.body;

    let media = null;
    let type = null;

    if (req.file) {
      media = "/uploads/promotions/" + req.file.filename;

      if (req.file.mimetype.startsWith("image")) {
        type = "image";
      } else if (req.file.mimetype.startsWith("video")) {
        type = "video";
      }
    }

    const [result] = await db.query(
      "INSERT INTO admin_promotions (title, media, type) VALUES (?, ?, ?)",
      [title || null, media, type]
    );

    res.json({
      message: "Promotion created",
      id: result.insertId,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

/* ================= GET ALL ================= */

router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM admin_promotions ORDER BY id DESC"
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: "Server error" });
  }
});

/* ================= UPDATE ================= */

router.put("/:id", upload.single("media"), async (req, res) => {
  try {
    const { title } = req.body;
    const { id } = req.params;

    let media = null;
    let type = null;

    if (req.file) {
      media = "/uploads/promotions/" + req.file.filename;

      if (req.file.mimetype.startsWith("image")) {
        type = "image";
      } else if (req.file.mimetype.startsWith("video")) {
        type = "video";
      }

      await db.query(
        "UPDATE admin_promotions SET title=?, media=?, type=? WHERE id=?",
        [title || null, media, type, id]
      );
    } else {
      await db.query(
        "UPDATE admin_promotions SET title=? WHERE id=?",
        [title || null, id]
      );
    }

    res.json({ message: "Promotion updated" });
  } catch (err) {
    res.status(500).json({ error: "Server error" });
  }
});

/* ================= DELETE ================= */

router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    await db.query(
      "DELETE FROM admin_promotions WHERE id=?",
      [id]
    );

    res.json({ message: "Promotion deleted" });
  } catch (err) {
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;