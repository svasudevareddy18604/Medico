const express = require("express");
const router = express.Router();
const db = require("../config/db");

const multer = require("multer");

const { CloudinaryStorage } = require("multer-storage-cloudinary");

const cloudinary = require("../config/cloudinary");

/*
=====================================
FILE TYPE VALIDATION
=====================================
*/

const allowedTypes = [
  "image/jpeg",
  "image/png",
  "image/jpg"
];

const fileFilter = (req, file, cb) => {

  if (!allowedTypes.includes(file.mimetype)) {

    return cb(
      new Error("Only JPG and PNG images allowed"),
      false
    );

  }

  cb(null, true);

};

/*
=====================================
CLOUDINARY STORAGE
=====================================
*/

const storage = new CloudinaryStorage({

  cloudinary,

  params: async (req, file) => {

    let folderName = "documents";

    if (
      file.fieldname === "aadhaar_front" ||
      file.fieldname === "aadhaar_back"
    ) {

      folderName = "aadhaar";

    }

    else if (file.fieldname === "pan_card") {

      folderName = "pan";

    }

    else if (file.fieldname === "certificate") {

      folderName = "certificate";

    }

    return {

      folder: `medico/${folderName}`,

      allowed_formats: ["jpg", "jpeg", "png"],

      public_id:
        file.fieldname +
        "-" +
        Date.now()

    };

  }

});

/*
=====================================
MULTER CONFIG
=====================================
*/

const upload = multer({

  storage,

  fileFilter,

  limits: {

    fileSize: 5 * 1024 * 1024

  }

});

/*
=====================================
UPLOAD DOCUMENTS
POST /api/caretaker/upload-documents
=====================================
*/

router.post(

  "/upload-documents",

  upload.fields([

    { name: "aadhaar_front", maxCount: 1 },

    { name: "aadhaar_back", maxCount: 1 },

    { name: "pan_card", maxCount: 1 },

    { name: "certificate", maxCount: 1 }

  ]),

  async (req, res) => {

    try {

      const { user_id } = req.body;

      /*
      =====================================
      USER VALIDATION
      =====================================
      */

      if (!user_id) {

        return res.status(400).json({

          success: false,

          message: "User ID required"

        });

      }

      /*
      =====================================
      CHECK CARETAKER PROFILE
      =====================================
      */

      const [profile] = await db.query(

        `
        SELECT caregiver_type
        FROM caretaker_profiles
        WHERE user_id = ?
        `,

        [user_id]

      );

      if (profile.length === 0) {

        return res.status(404).json({

          success: false,

          message: "Caretaker profile not found"

        });

      }

      const caregiverType =
        profile[0].caregiver_type;

      /*
      =====================================
      CLOUDINARY IMAGE URLS
      =====================================
      */

      const aadhaarFront =
        req.files["aadhaar_front"]?.[0]?.path || null;

      const aadhaarBack =
        req.files["aadhaar_back"]?.[0]?.path || null;

      const panCard =
        req.files["pan_card"]?.[0]?.path || null;

      const certificate =
        req.files["certificate"]?.[0]?.path || null;

      /*
      =====================================
      REQUIRED VALIDATION
      =====================================
      */

      if (
        !aadhaarFront ||
        !aadhaarBack ||
        !panCard
      ) {

        return res.status(400).json({

          success: false,

          message: "Aadhaar and PAN are mandatory"

        });

      }

      /*
      =====================================
      CERTIFICATE VALIDATION
      =====================================
      */

      if (
        (
          caregiverType === "Nurse" ||
          caregiverType === "Physiotherapy"
        ) &&
        !certificate
      ) {

        return res.status(400).json({

          success: false,

          message: "Professional certificate required"

        });

      }

      /*
      =====================================
      CHECK EXISTING DOCUMENTS
      =====================================
      */

      const [existing] = await db.query(

        `
        SELECT id
        FROM caretaker_documents
        WHERE user_id = ?
        `,

        [user_id]

      );

      /*
      =====================================
      UPDATE EXISTING
      =====================================
      */

      if (existing.length > 0) {

        await db.query(

          `
          UPDATE caretaker_documents
          SET
            aadhaar_front = ?,
            aadhaar_back = ?,
            pan_card = ?,
            certificate = ?
          WHERE user_id = ?
          `,

          [
            aadhaarFront,
            aadhaarBack,
            panCard,
            certificate,
            user_id
          ]

        );

      }

      /*
      =====================================
      INSERT NEW
      =====================================
      */

      else {

        await db.query(

          `
          INSERT INTO caretaker_documents
          (
            user_id,
            aadhaar_front,
            aadhaar_back,
            pan_card,
            certificate
          )
          VALUES (?,?,?,?,?)
          `,

          [
            user_id,
            aadhaarFront,
            aadhaarBack,
            panCard,
            certificate
          ]

        );

      }

      /*
      =====================================
      RESET APPROVAL STATUS
      =====================================
      */

      await db.query(

        `
        UPDATE users
        SET
          documents_uploaded = 1,
          approval_status = 'pending',
          reject_reason = NULL
        WHERE id = ?
        `,

        [user_id]

      );

      /*
      =====================================
      SUCCESS RESPONSE
      =====================================
      */

      res.json({

        success: true,

        message: "Documents uploaded successfully",

        data: {

          aadhaar_front: aadhaarFront,

          aadhaar_back: aadhaarBack,

          pan_card: panCard,

          certificate: certificate

        }

      });

    }

    catch (err) {

      console.error(
        "UPLOAD ERROR:",
        err
      );

      res.status(500).json({

        success: false,

        message: err.message || "Server error"

      });

    }

  }

);

/*
=====================================
GET UPLOADED DOCUMENTS
GET /api/caretaker/documents/:user_id
=====================================
*/
router.get("/:user_id", async (req, res) => {

  try {

    const { user_id } = req.params;

    const [docRows] = await db.query(
      `
      SELECT
        aadhaar_front,
        aadhaar_back,
        pan_card,
        certificate,
        created_at
      FROM caretaker_documents
      WHERE user_id = ?
      `,
      [user_id]
    );

    if (docRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No documents uploaded yet"
      });
    }

    const [userRows] = await db.query(
      `
      SELECT approval_status, reject_reason
      FROM users
      WHERE id = ?
      `,
      [user_id]
    );

    res.json({
      success: true,
      data: {
        ...docRows[0],
        approval_status: userRows[0]?.approval_status || "pending",
        reject_reason: userRows[0]?.reject_reason || null
      }
    });

  } catch (err) {
    console.error("FETCH DOCUMENTS ERROR:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Server error"
    });
  }

});

module.exports = router;