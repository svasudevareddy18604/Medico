const express = require("express");
const router = express.Router();
const db = require("../config/db");

const multer = require("multer");
const cloudinary = require("cloudinary").v2;
const { CloudinaryStorage } = require("multer-storage-cloudinary");

/* =========================================================
   CLOUDINARY CONFIG
========================================================= */

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/* =========================================================
   STORAGE
========================================================= */

const storage = new CloudinaryStorage({
  cloudinary,

  params: async () => ({
    folder: "medico_profiles",
    allowed_formats: ["jpg", "jpeg", "png"],
  }),
});

const upload = multer({
  storage,

  limits: {
    fileSize: 5 * 1024 * 1024,
  },
});

/* =========================================================
   GET CARETAKER PROFILE
========================================================= */

router.get("/:userId", async (req, res) => {
  try {

    const { userId } = req.params;

    const [rows] = await db.query(
      `
      SELECT
        u.id,
        u.first_name,
        u.last_name,
        u.mobile,

        cp.caregiver_type,
        cp.experience,
        cp.availability,
        cp.services,
        cp.profile_image,

        cp.is_available

      FROM users u

      LEFT JOIN caretaker_profiles cp
      ON cp.id = (
        SELECT id
        FROM caretaker_profiles
        WHERE user_id = u.id
        ORDER BY id DESC
        LIMIT 1
      )

      WHERE u.id = ?
      `,
      [userId]
    );

    if (rows.length === 0) {
      return res.json({
        success: false,
        message: "Profile not found",
      });
    }

    const p = rows[0];

    return res.json({
      success: true,

      id: p.id,

      first_name: p.first_name || "",
      last_name: p.last_name || "",

      mobile: p.mobile || "",

      caregiver_type: p.caregiver_type || "",

      experience: p.experience || "",

      availability: p.availability || "",

      services: p.services || "",

      profile_image: p.profile_image || "",

      // ================= NEW =================

      is_available:
        p.is_available === 0 ? 0 : 1,
    });

  } catch (err) {

    console.error(
      "❌ GET PROFILE ERROR:",
      err
    );

    return res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

/* =========================================================
   UPDATE AVAILABILITY STATUS
========================================================= */

router.put("/availability/:userId", async (req, res) => {
  try {

    const { userId } = req.params;

    const { is_available } = req.body;

    // ================= VALIDATION =================

    if (
      is_available !== 0 &&
      is_available !== 1
    ) {
      return res.status(400).json({
        success: false,
        message:
          "is_available must be 0 or 1",
      });
    }

    // ================= CHECK PROFILE =================

    const [rows] = await db.query(
      `
      SELECT id
      FROM caretaker_profiles
      WHERE user_id = ?
      ORDER BY id DESC
      LIMIT 1
      `,
      [userId]
    );

    // ================= INSERT IF NOT EXISTS =================

    if (rows.length === 0) {

      await db.query(
        `
        INSERT INTO caretaker_profiles
        (
          user_id,
          is_available
        )
        VALUES (?, ?)
        `,
        [
          userId,
          is_available,
        ]
      );

    } else {

      // ================= UPDATE =================

      await db.query(
        `
        UPDATE caretaker_profiles
        SET is_available = ?
        WHERE id = ?
        `,
        [
          is_available,
          rows[0].id,
        ]
      );
    }

    return res.json({
      success: true,

      is_available,

      message:
        is_available === 1
          ? "Caretaker is now available"
          : "Caretaker is now unavailable",
    });

  } catch (err) {

    console.error(
      "❌ AVAILABILITY ERROR:",
      err
    );

    return res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

/* =========================================================
   UPLOAD / UPDATE PROFILE IMAGE
========================================================= */

router.post(
  "/upload/:userId",
  upload.single("image"),

  async (req, res) => {
    try {

      const { userId } = req.params;

      if (!req.file) {
        return res.json({
          success: false,
          message: "NO_FILE_RECEIVED",
        });
      }

      const imagePath = req.file.path;

      console.log(
        "✅ Uploaded Image:",
        imagePath
      );

      // ================= CHECK PROFILE =================

      const [rows] = await db.query(
        `
        SELECT id
        FROM caretaker_profiles
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT 1
        `,
        [userId]
      );

      // ================= UPDATE =================

      if (rows.length > 0) {

        await db.query(
          `
          UPDATE caretaker_profiles
          SET profile_image = ?
          WHERE id = ?
          `,
          [
            imagePath,
            rows[0].id,
          ]
        );

      } else {

        // ================= INSERT =================

        await db.query(
          `
          INSERT INTO caretaker_profiles
          (
            user_id,
            profile_image
          )
          VALUES (?, ?)
          `,
          [
            userId,
            imagePath,
          ]
        );
      }

      return res.json({
        success: true,
        image: imagePath,
      });

    } catch (err) {

      console.error(
        "❌ UPLOAD ERROR:",
        err
      );

      return res.status(500).json({
        success: false,
        error: err.message,
      });
    }
  }
);

module.exports = router;