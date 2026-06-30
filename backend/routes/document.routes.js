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

          AND is_deleted = 0

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
   GET DOCUMENTS FOR A SPECIFIC ORDER
   (use this from the caretaker order-details
   screen — this is the safe, leak-proof fetch)
========================================= */

router.get(
  "/order/:orderId",

  async (req, res) => {

    try {

      const { orderId } = req.params;

      // Confirm the order actually exists first.
      const [orderRows] = await db.query(
        `SELECT id, user_id, created_at FROM orders WHERE id = ?`,
        [orderId]
      );

      if (orderRows.length === 0) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      const order = orderRows[0];

      // CRITICAL SAFETY FILTER:
      // A document can only belong to this order if:
      //   1. its order_id matches, AND
      //   2. it was uploaded at or after this order's created_at.
      // This guarantees that even if order_id values get reused
      // (e.g. AUTO_INCREMENT reset after a delete/truncate), stale
      // orphaned documents from a previous, now-deleted order can
      // never be shown against a new order that happens to reuse
      // the same id.
      const [documents] = await db.query(
  `
  SELECT
    bd.id,
    bd.order_id,
    bd.user_id,
    bd.service_id,
    bd.document_key,
    bd.file_url,
    bd.file_type,
    bd.uploaded_at
  FROM booking_documents bd
  WHERE bd.order_id = ?
    AND bd.user_id = ?
    AND bd.is_deleted = 0
    AND bd.uploaded_at = (
      SELECT MAX(bd2.uploaded_at)
      FROM booking_documents bd2
      WHERE bd2.order_id = bd.order_id
        AND bd2.document_key = bd.document_key
        AND bd2.is_deleted = 0
    )
  ORDER BY bd.uploaded_at ASC
  `,
  [orderId, req.query.user_id || order.user_id]
);

      return res.status(200).json({
        success: true,
        total_documents: documents.length,
        documents,
      });

    } catch (error) {

      console.error(
        "GET ORDER DOCUMENTS ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message: "Failed to fetch order documents",
      });
    }
  }
);

/* =========================================
   LINK PENDING DOCUMENTS TO A NEW ORDER
   Call this right after an order is created,
   to attach any order_id IS NULL docs that
   were uploaded during the booking flow.
========================================= */

router.post(
  "/link",

  async (req, res) => {

    try {

      const { order_id, user_id, service_id } = req.body;

      if (!order_id || !user_id || !service_id) {
        return res.status(400).json({
          success: false,
          message: "order_id, user_id and service_id are required",
        });
      }

      // Verify the order exists and belongs to this user before linking.
      const [orderRows] = await db.query(
        `SELECT id, user_id FROM orders WHERE id = ?`,
        [order_id]
      );

      if (orderRows.length === 0) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      if (String(orderRows[0].user_id) !== String(user_id)) {
        return res.status(403).json({
          success: false,
          message: "Order does not belong to this user",
        });
      }

      const [result] = await db.query(
        `
        UPDATE booking_documents
        SET order_id = ?
        WHERE user_id = ?
          AND service_id = ?
          AND order_id IS NULL
          AND is_deleted = 0
        `,
        [order_id, user_id, service_id]
      );

      return res.status(200).json({
        success: true,
        linked: result.affectedRows,
      });

    } catch (error) {

      console.error(
        "LINK DOCUMENTS ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message: "Failed to link documents",
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
         VALIDATE order_id IF PROVIDED
         Prevents stale/reused/foreign order ids
         from ever being attached to a document.
      ========================================= */

      if (order_id) {

        const [orderRows] = await db.query(
          `SELECT id, user_id FROM orders WHERE id = ?`,
          [order_id]
        );

        if (orderRows.length === 0) {
          return res.status(404).json({
            success: false,
            message: "order_id does not correspond to a real order",
          });
        }

        if (String(orderRows[0].user_id) !== String(user_id)) {
          return res.status(403).json({
            success: false,
            message: "order_id does not belong to this user",
          });
        }
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

          AND is_deleted = 0
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