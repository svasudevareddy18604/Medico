const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* ================= HELPER ================= */
async function getOrder(order_id) {
  const [rows] = await db.query(`
    SELECT 
      o.*,
      COALESCE(a.name, CONCAT(u.first_name,' ',u.last_name), '') AS careseeker_name,
      COALESCE(a.mobile, u.mobile, '') AS careseeker_phone,
      CONCAT(
        IFNULL(a.address_line, ''), ', ',
        IFNULL(a.area, ''), ', ',
        IFNULL(a.landmark, ''), ', ',
        IFNULL(a.pincode, '')
      ) AS full_address
    FROM orders o
    LEFT JOIN addresses a 
      ON a.user_id = o.user_id AND a.is_default = 1
    LEFT JOIN users u
      ON u.id = o.user_id
    WHERE o.id = ?
  `, [order_id]);

  return rows[0];
}

/* ================= GET ORDER ================= */
router.get("/:order_id", async (req, res) => {
  try {
    const order = await getOrder(req.params.order_id);

    if (!order) {
      return res.json({ success: false, message: "Order not found" });
    }

    res.json({ success: true, data: order });

  } catch (err) {
    console.error(err);
    res.json({ success: false, message: "Server error" });
  }
});

/* ================= CONFIRM COD ================= */
router.post("/confirm", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;

    const order = await getOrder(order_id);

    if (!order || order.payment_method !== "COD") {
      return res.json({ success: false, message: "Invalid order" });
    }

    await db.query(
      `UPDATE orders 
       SET payment_status = 'PAID',
           status = 'IN_PROGRESS',
           caretaker_id = ?
       WHERE id = ?`,
      [caretaker_id, order_id]
    );

    res.json({ success: true, message: "COD confirmed" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});

/* ================= VERIFY ONLINE PAYMENT ================= */
router.post("/verify", async (req, res) => {
  try {
    const { order_id, payment_id, caretaker_id } = req.body;

    const order = await getOrder(order_id);

    if (!order) {
      return res.json({ success: false, message: "Order not found" });
    }

    await db.query(
      `UPDATE orders 
       SET payment_status = 'PAID',
           payment_id = ?,
           status = 'CONFIRMED',
           caretaker_id = ?
       WHERE id = ?`,
      [payment_id, caretaker_id || null, order_id]
    );

    res.json({ success: true, message: "Payment verified" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});

/* ================= START SERVICE ================= */
router.post("/start", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;

    const order = await getOrder(order_id);

    if (!order || order.payment_status !== "PAID") {
      return res.json({ success: false, message: "Payment not completed" });
    }

    await db.query(
      `UPDATE orders 
       SET status = 'IN_PROGRESS',
           caretaker_id = ?
       WHERE id = ?`,
      [caretaker_id, order_id]
    );

    res.json({ success: true, message: "Service started" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});

/* ================= MARK PAYMENT RECEIVED ================= */
router.post("/mark-received", async (req, res) => {
  try {
    const { order_id, caretaker_id } = req.body;

    const order = await getOrder(order_id);

    if (!order) {
      return res.json({ success: false, message: "Order not found" });
    }

    if (order.payment_status === "PAID") {
      return res.json({ success: true, message: "Already paid" });
    }

    await db.query(
      `UPDATE orders 
       SET payment_status = 'PAID',
           status = 'CONFIRMED',
           caretaker_id = ?
       WHERE id = ?`,
      [caretaker_id, order_id]
    );

    res.json({ success: true, message: "Payment marked" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});

/* ================= COMPLETE SERVICE ================= */
router.post("/complete", async (req, res) => {
  const connection = await db.getConnection();

  try {
    const { order_id, caretaker_id } = req.body;

    await connection.beginTransaction();

    const [orders] = await connection.query(
      "SELECT * FROM orders WHERE id = ? FOR UPDATE",
      [order_id]
    );

    if (orders.length === 0) {
      await connection.rollback();
      return res.json({ success: false, message: "Order not found" });
    }

    const order = orders[0];

    if (order.payment_status !== "PAID") {
      await connection.rollback();
      return res.json({ success: false, message: "Payment not completed" });
    }

    const [existing] = await connection.query(
      "SELECT id FROM earnings WHERE order_id = ? AND caretaker_id = ?",
      [order_id, caretaker_id]
    );

    if (existing.length > 0) {
      await connection.commit();
      return res.json({ success: true, message: "Already completed" });
    }

    const total = Number(order.total || 0);
    const commission = total * 0.20;
    const caretakerAmount = total - commission;

    await connection.query(
      `UPDATE orders SET status = 'COMPLETED' WHERE id = ?`,
      [order_id]
    );

    await connection.query(
      `INSERT INTO earnings 
      (order_id, caretaker_id, total_amount, commission, caretaker_amount, status)
      VALUES (?, ?, ?, ?, ?, 'pending')`,
      [order_id, caretaker_id, total, commission, caretakerAmount]
    );

    await connection.commit();

    res.json({ success: true, message: "Completed & earnings added" });

  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.json({ success: false });
  } finally {
    connection.release();
  }
});

module.exports = router;
