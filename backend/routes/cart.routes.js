const express = require("express");

const router = express.Router();

const db = require("../config/db");

/* =========================================
   GET CART
========================================= */

router.get("/:userId", async (req, res) => {

  try {

    const [rows] = await db.query(
      `
      SELECT

        c.id AS cart_id,

        c.service_id,

        c.category,

        s.name,

        s.price,

        s.image,

        s.duration,

        s.requires_documents

      FROM cart c

      JOIN services s
      ON c.service_id = s.id

      WHERE c.user_id = ?
      `,
      [req.params.userId]
    );

    return res.json(rows || []);

  } catch (err) {

    console.error(
      "GET CART ERROR:",
      err
    );

    return res.status(500).json({
      message: "Server error",
    });
  }
});

/* =========================================
   ADD TO CART
========================================= */

router.post("/add", async (req, res) => {

  try {

    const {
      user_id,
      service_id,
      category,
    } = req.body;

    if (
      !user_id ||
      !service_id
    ) {
      return res.status(400).json({
        message:
          "user_id and service_id required",
      });
    }

    /* =========================================
       CHECK DUPLICATE
    ========================================= */

    const [existing] =
      await db.query(
        `
        SELECT id
        FROM cart
        WHERE user_id = ?
        AND service_id = ?
        `,
        [
          user_id,
          service_id,
        ]
      );

    if (existing.length > 0) {

      return res.status(400).json({
        success: false,

        message:
          "Item already in cart",
      });
    }

    /* =========================================
       INSERT
    ========================================= */

    await db.query(
      `
      INSERT INTO cart
      (
        user_id,
        service_id,
        category
      )
      VALUES (?, ?, ?)
      `,
      [
        user_id,
        service_id,
        category || "Nurse",
      ]
    );

    return res.json({
      success: true,

      message:
        "Added to cart successfully",
    });

  } catch (err) {

    console.error(
      "ADD TO CART ERROR:",
      err
    );

    return res.status(500).json({
      message: "Server error",
    });
  }
});

/* =========================================
   CLEAR CART
========================================= */

router.delete(
  "/:userId/clear",

  async (req, res) => {

    try {

      const [result] =
        await db.query(
          `
          DELETE FROM cart
          WHERE user_id = ?
          `,
          [req.params.userId]
        );

      return res.json({
        success: true,

        deletedItems:
          result.affectedRows,
      });

    } catch (err) {

      console.error(
        "CLEAR CART ERROR:",
        err
      );

      return res.status(500).json({
        message: "Server error",
      });
    }
  }
);

/* =========================================
   REMOVE SINGLE ITEM
========================================= */

router.delete(
  "/:userId/:cartId",

  async (req, res) => {

    try {

      const {
        userId,
        cartId,
      } = req.params;

      if (isNaN(cartId)) {

        return res.status(400).json({
          message:
            "Invalid cart ID",
        });
      }

      const [result] =
        await db.query(
          `
          DELETE FROM cart
          WHERE id = ?
          AND user_id = ?
          `,
          [
            cartId,
            userId,
          ]
        );

      if (
        result.affectedRows === 0
      ) {
        return res.status(404).json({
          message:
            "Item not found",
        });
      }

      return res.json({
        success: true,
      });

    } catch (err) {

      console.error(
        "REMOVE CART ERROR:",
        err
      );

      return res.status(500).json({
        message: "Server error",
      });
    }
  }
);

/* =========================================
   CART SUMMARY
========================================= */

router.get(
  "/:userId/summary",

  async (req, res) => {

    try {

      const [items] =
        await db.query(
          `
          SELECT
            s.price
          FROM cart c

          JOIN services s
          ON c.service_id = s.id

          WHERE c.user_id = ?
          `,
          [req.params.userId]
        );

      if (!items.length) {

        return res.json({
          subtotal: 0,

          serviceCharge: 0,

          total: 0,
        });
      }

      const subtotal =
        items.reduce(
          (sum, item) =>
            sum +
            Number(item.price),
          0
        );

      /* =========================================
         SERVICE CHARGE
      ========================================= */

      const [settingsRows] =
        await db.query(
          `
          SELECT *
          FROM service_charges
          LIMIT 1
          `
        );

      let serviceCharge = 0;

      if (
        settingsRows.length > 0
      ) {

        const s =
          settingsRows[0];

        if (s.is_enabled === 1) {

          if (
            s.charge_type ===
            "flat"
          ) {
            serviceCharge =
              Number(s.amount);
          }

          if (
            s.charge_type ===
            "per_km"
          ) {
            serviceCharge =
              Number(s.amount) * 5;
          }
        }
      }

      return res.json({

        subtotal,

        serviceCharge,

        total:
          subtotal +
          serviceCharge,
      });

    } catch (err) {

      console.error(
        "CART SUMMARY ERROR:",
        err
      );

      return res.status(500).json({
        message: "Server error",
      });
    }
  }
);

/* =========================================
   CHECKOUT
========================================= */

router.post(
  "/checkout",

  async (req, res) => {

    const connection =
      await db.getConnection();

    try {

      const { user_id } =
        req.body;

      await connection.beginTransaction();

      /* =========================================
         GET CART ITEMS
      ========================================= */

      const [items] =
        await connection.query(
          `
          SELECT
            service_id,
            category
          FROM cart
          WHERE user_id = ?
          `,
          [user_id]
        );

      if (
        items.length === 0
      ) {
        throw new Error(
          "Cart is empty"
        );
      }

      /* =========================================
         CREATE ORDER
      ========================================= */

      const [orderResult] =
        await connection.query(
          `
          INSERT INTO orders
          (
            user_id
          )
          VALUES (?)
          `,
          [user_id]
        );

      const orderId =
        orderResult.insertId;

      /* =========================================
         INSERT ORDER ITEMS
      ========================================= */

      for (const item of items) {

        await connection.query(
          `
          INSERT INTO order_items
          (
            order_id,
            service_id,
            category
          )
          VALUES (?, ?, ?)
          `,
          [
            orderId,
            item.service_id,
            item.category ||
              "Nurse",
          ]
        );
      }

      /* =========================================
         CLEAR CART
      ========================================= */

      await connection.query(
        `
        DELETE FROM cart
        WHERE user_id = ?
        `,
        [user_id]
      );

      await connection.commit();

      return res.json({

        success: true,

        orderId,

        message:
          "Order placed & cart cleared",
      });

    } catch (err) {

      await connection.rollback();

      console.error(
        "CHECKOUT ERROR:",
        err
      );

      return res.status(500).json({
        message:
          err.message,
      });

    } finally {

      connection.release();
    }
  }
);

module.exports = router;