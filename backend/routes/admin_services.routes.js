const express = require("express");
const router = express.Router();

const db = require("../config/db");

const multer = require("multer");

const cloudinary = require("../config/cloudinary");

const {
  CloudinaryStorage,
} = require("multer-storage-cloudinary");

/* =========================================
   CLOUDINARY STORAGE
========================================= */

const storage = new CloudinaryStorage({
  cloudinary,

  params: {
    folder: "services",

    allowed_formats: [
      "jpg",
      "png",
      "jpeg",
      "webp",
    ],

    public_id: () =>
      "service_" + Date.now(),
  },
});

const upload = multer({
  storage,
});

/* =========================================
   SAFE VALUE
========================================= */

const safe = (v) =>
  v === undefined || v === null
    ? ""
    : v;

/* =========================================
   FORMAT ROW
========================================= */

const fmt = (s) => ({
  id: s.id,

  name: s.name,

  category: s.category,

  service_type: s.service_type,

  price: s.price,

  price_type: s.price_type,

  description:
    s.description || "",

  includes:
    s.includes || "",

  excludes:
    s.excludes || "",

  requirements:
    s.requirements || "",

  duration:
    s.duration || "",

  image:
    s.image || "",

  recommended:
    s.recommended === 1 ||
    s.recommended === true,

  active: s.active,

  requires_documents:
    s.requires_documents === 1 ||
    s.requires_documents === true,
});

/* =========================================
   GET ALL ACTIVE SERVICES
========================================= */

router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(
      `
      SELECT *
      FROM services
      WHERE active = 1
      ORDER BY id DESC
      `
    );

    return res.json(
      rows.map(fmt)
    );
  } catch (err) {
    console.error(
      "GET /services:",
      err
    );

    return res.status(500).json({
      message: "DB error",
    });
  }
});

/* =========================================
   GET RECOMMENDED
========================================= */

router.get(
  "/recommended",
  async (req, res) => {
    try {
      const [rows] = await db.query(
        `
        SELECT *
        FROM services
        WHERE active = 1
        AND recommended = 1
        ORDER BY id DESC
        `
      );

      return res.json({
        services:
          rows.map(fmt),
      });
    } catch (err) {
      console.error(
        "GET /services/recommended:",
        err
      );

      return res.status(500).json({
        message: "DB error",
      });
    }
  }
);

/* =========================================
   ADD SERVICE
========================================= */

router.post(
  "/",

  upload.single("image"),

  async (req, res) => {
    try {
      const imageUrl =
        req.file
          ? req.file.path
          : null;

      const cloudinaryId =
        req.file
          ? req.file.filename
          : null;

      await db.query(
        `
        INSERT INTO services
        (
          name,
          category,
          service_type,
          price,
          price_type,
          description,
          duration,
          includes,
          excludes,
          requirements,
          image,
          cloudinary_id,
          recommended,
          requires_documents,
          active
        )
        VALUES
        (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        `,
        [
          safe(req.body.name),

          safe(req.body.category),

          safe(req.body.service_type),

          safe(req.body.price),

          safe(req.body.price_type),

          safe(req.body.description),

          safe(req.body.duration),

          safe(req.body.includes),

          safe(req.body.excludes),

          safe(req.body.requirements),

          imageUrl,

          cloudinaryId,

          req.body.recommended == "1"
            ? 1
            : 0,

          req.body
            .requires_documents ==
          "1"
            ? 1
            : 0,
        ]
      );

      return res.json({
        success: true,

        message:
          "Service added successfully",
      });
    } catch (err) {
      console.error(
        "POST /services:",
        err
      );

      return res.status(500).json({
        message: "DB error",
      });
    }
  }
);

/* =========================================
   UPDATE SERVICE
========================================= */

router.put(
  "/:id",

  upload.single("image"),

  async (req, res) => {
    try {
      const { id } =
        req.params;

      let imageUrl = null;

      let cloudinaryId = null;

      /* =========================================
         NEW IMAGE
      ========================================= */

      if (req.file) {
        imageUrl =
          req.file.path;

        cloudinaryId =
          req.file.filename;

        const [old] =
          await db.query(
            `
            SELECT cloudinary_id
            FROM services
            WHERE id = ?
            `,
            [id]
          );

        if (
          old.length &&
          old[0].cloudinary_id
        ) {
          await cloudinary.uploader.destroy(
            old[0]
              .cloudinary_id
          );
        }
      }

      /* =========================================
         UPDATE
      ========================================= */

      await db.query(
        `
        UPDATE services
        SET

        name = ?,

        category = ?,

        service_type = ?,

        price = ?,

        price_type = ?,

        description = ?,

        duration = ?,

        includes = ?,

        excludes = ?,

        requirements = ?,

        recommended = ?,

        requires_documents = ?,

        image = IFNULL(?, image),

        cloudinary_id = IFNULL(?, cloudinary_id)

        WHERE id = ?
        `,
        [
          safe(req.body.name),

          safe(req.body.category),

          safe(req.body.service_type),

          safe(req.body.price),

          safe(req.body.price_type),

          safe(req.body.description),

          safe(req.body.duration),

          safe(req.body.includes),

          safe(req.body.excludes),

          safe(req.body.requirements),

          req.body.recommended ==
          "1"
            ? 1
            : 0,

          req.body
            .requires_documents ==
          "1"
            ? 1
            : 0,

          imageUrl,

          cloudinaryId,

          id,
        ]
      );

      return res.json({
        success: true,

        message:
          "Service updated successfully",
      });
    } catch (err) {
      console.error(
        "PUT /services/:id:",
        err
      );

      return res.status(500).json({
        message: "DB error",
      });
    }
  }
);

/* =========================================
   TOGGLE ACTIVE
========================================= */

router.put(
  "/toggle/:id",

  async (req, res) => {
    try {
      await db.query(
        `
        UPDATE services
        SET active =
          IF(active = 1, 0, 1)
        WHERE id = ?
        `,
        [req.params.id]
      );

      return res.json({
        success: true,

        message:
          "Service status updated",
      });
    } catch (err) {
      console.error(
        "TOGGLE:",
        err
      );

      return res.status(500).json({
        message: "DB error",
      });
    }
  }
);

/* =========================================
   DELETE
========================================= */

router.delete(
  "/:id",

  async (req, res) => {
    try {
      const [rows] =
        await db.query(
          `
          SELECT cloudinary_id
          FROM services
          WHERE id = ?
          `,
          [req.params.id]
        );

      if (
        rows.length &&
        rows[0]
          .cloudinary_id
      ) {
        await cloudinary.uploader.destroy(
          rows[0]
            .cloudinary_id
        );
      }

      await db.query(
        `
        DELETE FROM services
        WHERE id = ?
        `,
        [req.params.id]
      );

      return res.json({
        success: true,

        message:
          "Deleted successfully",
      });
    } catch (err) {
      console.error(
        "DELETE:",
        err
      );

      return res.status(500).json({
        message: "DB error",
      });
    }
  }
);

module.exports = router;