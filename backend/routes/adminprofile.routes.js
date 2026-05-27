const express = require("express");

const router = express.Router();

const db = require("../config/db");

const multer = require("multer");

const bcrypt = require("bcrypt");

const cloudinary = require("../config/cloudinary");

const {
  CloudinaryStorage
} = require("multer-storage-cloudinary");

/* =========================================
   CLOUDINARY STORAGE
========================================= */

const storage = new CloudinaryStorage({

  cloudinary,

  params: async (req, file) => {

    return {

      folder: "medico/profile",

      allowed_formats: [
        "jpg",
        "jpeg",
        "png"
      ],

      public_id:
        "profile-" + Date.now()

    };

  }

});

/* =========================================
   MULTER CONFIG
========================================= */

const upload = multer({

  storage,

  limits: {

    fileSize: 5 * 1024 * 1024

  }

});

/* =========================================
   GET ADMIN PROFILE
========================================= */

router.get("/profile/:id", async (req, res) => {

  try {

    const { id } = req.params;

    const [rows] = await db.query(

      `
      SELECT
        id,
        first_name,
        last_name,
        mobile,
        email,
        role,
        profile_image
      FROM users
      WHERE id = ?
      AND role = 'admin'
      `,

      [id]

    );

    if (!rows.length) {

      return res.status(404).json({

        success: false,

        message: "Admin not found"

      });

    }

    res.json(rows[0]);

  }

  catch (err) {

    console.log(err);

    res.status(500).json({

      success: false,

      message: "Server error"

    });

  }

});

/* =========================================
   CHANGE PASSWORD
========================================= */

router.post("/change-password", async (req, res) => {

  try {

    const {
      user_id,
      password
    } = req.body;

    /*
    =====================================
    VALIDATION
    =====================================
    */

    if (!user_id || !password) {

      return res.json({

        success: false,

        message:
          "User ID and password required"

      });

    }

    if (password.length < 4) {

      return res.json({

        success: false,

        message: "Password too short"

      });

    }

    /*
    =====================================
    HASH PASSWORD
    =====================================
    */

    const hashedPassword =
      await bcrypt.hash(password, 10);

    /*
    =====================================
    UPDATE PASSWORD
    =====================================
    */

    await db.query(

      `
      UPDATE users
      SET password = ?
      WHERE id = ?
      `,

      [
        hashedPassword,
        user_id
      ]

    );

    res.json({

      success: true,

      message:
        "Password updated successfully"

    });

  }

  catch (err) {

    console.log(
      "CHANGE PASSWORD ERROR:",
      err
    );

    res.json({

      success: false,

      message: "Server error"

    });

  }

});

/* =========================================
   UPLOAD PROFILE IMAGE
========================================= */

router.post(

  "/upload-profile/:id",

  upload.single("image"),

  async (req, res) => {

    try {

      const { id } = req.params;

      /*
      =====================================
      FILE VALIDATION
      =====================================
      */

      if (!req.file) {

        return res.status(400).json({

          success: false,

          message: "No image uploaded"

        });

      }

      /*
      =====================================
      CLOUDINARY IMAGE URL
      =====================================
      */

      const imageUrl = req.file.path;

      /*
      =====================================
      UPDATE DATABASE
      =====================================
      */

      await db.query(

        `
        UPDATE users
        SET profile_image = ?
        WHERE id = ?
        `,

        [
          imageUrl,
          id
        ]

      );

      /*
      =====================================
      SUCCESS RESPONSE
      =====================================
      */

      res.json({

        success: true,

        message:
          "Profile image uploaded successfully",

        profile_image: imageUrl

      });

    }

    catch (err) {

      console.log(
        "UPLOAD PROFILE ERROR:",
        err
      );

      res.status(500).json({

        success: false,

        message: "Server error"

      });

    }

  }

);

/* =========================================
   REMOVE PROFILE IMAGE
========================================= */

router.delete(
  "/remove-profile/:id",
  async (req, res) => {

    try {

      const { id } = req.params;

      /*
      =====================================
      GET EXISTING IMAGE
      =====================================
      */

      const [rows] = await db.query(

        `
        SELECT profile_image
        FROM users
        WHERE id = ?
        `,

        [id]

      );

      if (!rows.length) {

        return res.status(404).json({

          success: false,

          message: "User not found"

        });

      }

      const imageUrl =
        rows[0].profile_image;

      /*
      =====================================
      DELETE FROM CLOUDINARY
      =====================================
      */

      if (imageUrl) {

        try {

          const splitUrl =
            imageUrl.split("/");

          const fileName =
            splitUrl[splitUrl.length - 1];

          const publicId =
            "medico/profile/" +
            fileName.split(".")[0];

          await cloudinary.uploader.destroy(
            publicId
          );

        }

        catch (cloudErr) {

          console.log(
            "CLOUDINARY DELETE ERROR:",
            cloudErr
          );

        }

      }

      /*
      =====================================
      REMOVE IMAGE FROM DATABASE
      =====================================
      */

      await db.query(

        `
        UPDATE users
        SET profile_image = NULL
        WHERE id = ?
        `,

        [id]

      );

      /*
      =====================================
      SUCCESS RESPONSE
      =====================================
      */

      res.json({

        success: true,

        message:
          "Profile image removed successfully"

      });

    }

    catch (err) {

      console.log(
        "REMOVE PROFILE ERROR:",
        err
      );

      res.status(500).json({

        success: false,

        message: "Server error"

      });

    }

  }

);

module.exports = router;