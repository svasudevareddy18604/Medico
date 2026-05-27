const express = require("express");
const router = express.Router();
const db = require("../config/db");
const multer = require("multer");
const cloudinary = require("../config/cloudinary");
const { CloudinaryStorage } = require("multer-storage-cloudinary");

/* ======================================
   MULTER + CLOUDINARY STORAGE (FIXED)
====================================== */

const storage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => {
    // 🔥 Extract extension safely
    let ext = "jpg"; // default fallback

    if (file.originalname && file.originalname.includes(".")) {
      ext = file.originalname.split(".").pop().toLowerCase();
    }

    return {
      folder: "profile_images",
      format: ext, // 🔥 FIXED (no more octet-stream issue)
      public_id: "user_" + Date.now(),
    };
  },
});

const upload = multer({ storage });

/* ======================================
   HELPER → EXTRACT PUBLIC ID
====================================== */

function getPublicIdFromUrl(url) {
  try {
    const parts = url.split("/");
    const fileName = parts.pop();
    const folder = parts.pop();

    return `${folder}/${fileName.split(".")[0]}`;
  } catch (err) {
    console.error("❌ PUBLIC ID ERROR:", err.message);
    return null;
  }
}

/* ======================================
   GET USER PROFILE
====================================== */

router.get("/profile/:id", async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, first_name, last_name, mobile, email, role, profile_image 
       FROM users WHERE id = ?`,
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(rows[0]);

  } catch (err) {
    console.error("❌ PROFILE ERROR:", err.message);
    res.status(500).json({ message: err.message });
  }
});

/* ======================================
   UPLOAD / UPDATE PROFILE IMAGE
====================================== */

router.post(
  "/upload-profile/:id",
  upload.single("image"),
  async (req, res) => {
    try {
      const userId = req.params.id;

      console.log("📌 USER ID:", userId);
      console.log("📌 FILE:", req.file);

      if (!req.file) {
        return res.status(400).json({ message: "No image uploaded" });
      }

      const imageUrl = req.file.path;

      console.log("✅ CLOUDINARY URL:", imageUrl);

      // 🔥 Fetch old image
      const [rows] = await db.query(
        "SELECT profile_image FROM users WHERE id = ?",
        [userId]
      );

      if (rows.length === 0) {
        return res.status(404).json({ message: "User not found" });
      }

      // 🔥 Delete old image
      if (rows[0].profile_image) {
        const publicId = getPublicIdFromUrl(rows[0].profile_image);

        if (publicId) {
          console.log("🗑 Deleting old image:", publicId);
          await cloudinary.uploader.destroy(publicId);
        }
      }

      // 🔥 Update DB
      const result = await db.query(
        "UPDATE users SET profile_image = ? WHERE id = ?",
        [imageUrl, userId]
      );

      console.log("✅ DB RESULT:", result);

      res.status(200).json({
        message: "Profile image updated successfully",
        image: imageUrl,
      });

    } catch (err) {
      console.error("❌ UPLOAD ERROR FULL:", err);
      console.error("❌ MESSAGE:", err.message);

      res.status(500).json({
        message: err.message || "Server error",
      });
    }
  }
);

/* ======================================
   REMOVE PROFILE IMAGE
====================================== */

router.delete("/remove-profile/:id", async (req, res) => {
  try {
    const userId = req.params.id;

    const [rows] = await db.query(
      "SELECT profile_image FROM users WHERE id = ?",
      [userId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    const imageUrl = rows[0].profile_image;

    if (imageUrl) {
      const publicId = getPublicIdFromUrl(imageUrl);

      if (publicId) {
        console.log("🗑 Removing image:", publicId);
        await cloudinary.uploader.destroy(publicId);
      }
    }

    await db.query(
      "UPDATE users SET profile_image = NULL WHERE id = ?",
      [userId]
    );

    res.json({ message: "Profile image removed" });

  } catch (err) {
    console.error("❌ REMOVE ERROR:", err.message);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;