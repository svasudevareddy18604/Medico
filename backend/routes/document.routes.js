const router = require("express").Router();

const fs = require("fs");

const db = require("../config/db");

const cloudinary =
  require("../config/cloudinary");

const uploadMedicalDocuments =
  require("../middleware/uploadMedicalDocuments");

/* =========================================
   TEST ROUTE
========================================= */

router.get(
  "/test",

  (req, res) => {

    return res.json({
      success: true,

      message:
        "Document route working",
    });
  }
);

/* =========================================
   GET PENDING DOCUMENTS
   PREVENT DUPLICATE UPLOADS
========================================= */

router.get(
  "/pending/:userId/:serviceId",

  async (req, res) => {

    try {

      const {
        userId,
        serviceId,
      } = req.params;

      const [documents] =
        await db.query(
          `
          SELECT

            id,

            document_key,

            file_url,

            file_type

          FROM booking_documents

          WHERE user_id = ?

          AND service_id = ?

          AND order_id IS NULL

          ORDER BY id DESC
          `,
          [
            userId,
            serviceId,
          ]
        );

      return res.status(200).json({

        success: true,

        already_uploaded:
          documents.length > 0,

        total_documents:
          documents.length,

        documents,
      });

    } catch (error) {

      console.error(
        "GET PENDING DOCUMENTS ERROR:",
        error
      );

      return res.status(500).json({

        success: false,

        message:
          "Failed to fetch pending documents",
      });
    }
  }
);

/* =========================================
   UPLOAD DOCUMENTS
========================================= */

router.post(

  "/upload",

  (req, res, next) => {

    uploadMedicalDocuments.array(
      "documents",
      5
    )(req, res, (err) => {

      if (err) {

        return res.status(400).json({

          success: false,

          message:
            err.message,
        });
      }

      next();
    });
  },

  async (req, res) => {

    try {

      const {
        order_id,
        user_id,
        service_id,
        document_key,
      } = req.body;

      /* =========================================
         VALIDATION
      ========================================= */

      if (!user_id) {

        return res.status(400).json({

          success: false,

          message:
            "user_id is required",
        });
      }

      if (!service_id) {

        return res.status(400).json({

          success: false,

          message:
            "service_id is required",
        });
      }

      if (!document_key) {

        return res.status(400).json({

          success: false,

          message:
            "document_key is required",
        });
      }

      if (
        !req.files ||
        req.files.length === 0
      ) {

        return res.status(400).json({

          success: false,

          message:
            "No files uploaded",
        });
      }

      /* =========================================
         CHECK EXISTING DOCS
      ========================================= */

      const [existingDocs] =
        await db.query(
          `
          SELECT *

          FROM booking_documents

          WHERE user_id = ?

          AND service_id = ?

          AND order_id IS NULL
          `,
          [
            user_id,
            service_id,
          ]
        );

      if (existingDocs.length > 0) {

        return res.status(200).json({

          success: true,

          already_uploaded: true,

          message:
            "Documents already uploaded",

          documents:
            existingDocs,
        });
      }

      /* =========================================
         UPLOAD FILES
      ========================================= */

      const uploadedDocuments = [];

      for (const file of req.files) {

        console.log(
          "UPLOADED MIME TYPE:",
          file.mimetype
        );

        const isPdf =
          file.mimetype ===
          "application/pdf";

        try {

          /* =========================================
             CLOUDINARY UPLOAD
          ========================================= */

          const cloudinaryResult =
            await cloudinary.uploader.upload(
              file.path,
              {
                folder:
                  "medical-documents",

                resource_type:
                  isPdf
                    ? "raw"
                    : "image",
              }
            );

          /* =========================================
             SAVE DATABASE
          ========================================= */

          const [result] =
            await db.query(
              `
              INSERT INTO booking_documents
              (
                order_id,
                user_id,
                service_id,
                document_key,
                file_url,
                cloudinary_public_id,
                file_type
              )
              VALUES (?, ?, ?, ?, ?, ?, ?)
              `,
              [
                order_id || null,

                user_id,

                service_id,

                document_key,

                cloudinaryResult.secure_url,

                cloudinaryResult.public_id,

                isPdf
                  ? "pdf"
                  : "image",
              ]
            );

          uploadedDocuments.push({

            id:
              result.insertId,

            document_key,

            file_name:
              file.originalname,

            file_type:
              isPdf
                ? "pdf"
                : "image",

            file_url:
              cloudinaryResult.secure_url,

            cloudinary_public_id:
              cloudinaryResult.public_id,
          });

        } catch (cloudinaryError) {

          console.error(
            "CLOUDINARY ERROR:",
            cloudinaryError
          );

          return res.status(400).json({

            success: false,

            message:
              isPdf
                ? "Password protected or invalid PDF not supported"
                : "Image upload failed",
          });
        }

        /* =========================================
           DELETE LOCAL FILE
        ========================================= */

        if (
          fs.existsSync(file.path)
        ) {

          fs.unlinkSync(file.path);
        }
      }

      /* =========================================
         SUCCESS RESPONSE
      ========================================= */

      return res.status(200).json({

        success: true,

        already_uploaded: false,

        message:
          "Documents uploaded successfully",

        total_uploaded:
          uploadedDocuments.length,

        documents:
          uploadedDocuments,
      });

    } catch (error) {

      console.error(
        "DOCUMENT UPLOAD ERROR:",
        error
      );

      return res.status(500).json({

        success: false,

        message:
          "Document upload failed",

        error:
          error.message ||
          "Unknown server error",
      });
    }
  }
);

module.exports = router;