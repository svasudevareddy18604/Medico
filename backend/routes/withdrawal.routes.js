const express = require("express");
const router = express.Router();
const db = require("../config/db");


/* ================= GET ALL WITH PAYMENT ================= */
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        w.id,
        w.caretaker_id,
        w.amount,
        w.status,
        w.created_at,

        CONCAT(u.first_name, ' ', u.last_name) AS caretaker_name,
        u.mobile AS caretaker_mobile,

        p.type,
        p.upi_id,
        p.account_number,
        p.ifsc_code,
        p.account_name

      FROM withdrawals w

      LEFT JOIN users u 
        ON u.id = w.caretaker_id

      LEFT JOIN caregiver_payment_details p 
        ON p.user_id = w.caretaker_id

      WHERE p.id = (
        SELECT MAX(id)
        FROM caregiver_payment_details
        WHERE user_id = w.caretaker_id
      )

      ORDER BY w.id DESC
    `);

    console.log("✅ PAYMENT JOIN WORKING");

    res.json({ success: true, data: rows });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});


/* ================= CREATE WITHDRAW ================= */
router.post("/", async (req, res) => {
  const connection = await db.getConnection();

  try {
    const { caretaker_id } = req.body;

    if (!caretaker_id) {
      return res.json({
        success: false,
        message: "Caretaker ID required"
      });
    }

    await connection.beginTransaction();

    /* ================= FIXED TABLE NAME ================= */

    const [payment] = await connection.query(`
      SELECT id FROM caregiver_payment_details
      WHERE user_id = ?
      LIMIT 1
    `, [caretaker_id]);

    // 🚨 BLOCK IF NO PAYMENT DETAILS
    if (payment.length === 0) {
      await connection.rollback();
      return res.json({
        success: false,
        message: "Add payment details first"
      });
    }

    /* ================= CHECK EXISTING ================= */

    const [existing] = await connection.query(`
      SELECT id FROM withdrawals
      WHERE caretaker_id = ?
      AND status = 'pending'
      LIMIT 1
    `, [caretaker_id]);

    if (existing.length > 0) {
      await connection.rollback();
      return res.json({
        success: false,
        message: "Withdraw already requested"
      });
    }

    /* ================= LOCK EARNINGS ================= */

    const [rows] = await connection.query(`
      SELECT id, caretaker_amount
      FROM earnings
      WHERE caretaker_id = ?
      AND status = 'pending'
      FOR UPDATE
    `, [caretaker_id]);

    if (rows.length === 0) {
      await connection.rollback();
      return res.json({
        success: false,
        message: "No earnings available"
      });
    }

    /* ================= CALCULATE ================= */

    const amount = rows.reduce(
      (sum, r) => sum + Number(r.caretaker_amount || 0),
      0
    );

    if (amount <= 0) {
      await connection.rollback();
      return res.json({
        success: false,
        message: "Invalid amount"
      });
    }

    /* ================= INSERT ================= */

    const [result] = await connection.query(`
      INSERT INTO withdrawals (caretaker_id, amount, status)
      VALUES (?, ?, 'pending')
    `, [caretaker_id, amount]);

    const withdrawalId = result.insertId;

    /* ================= UPDATE EARNINGS ================= */

    const earningIds = rows.map(r => r.id);

    await connection.query(`
      UPDATE earnings
      SET status = 'processing', withdrawal_id = ?
      WHERE id IN (?)
    `, [withdrawalId, earningIds]);

    await connection.commit();

    res.json({
      success: true,
      message: "Withdraw request created",
      amount
    });

  } catch (err) {
    await connection.rollback();
    console.error("WITHDRAW ERROR:", err);

    res.json({
      success: false,
      message: "Server error"
    });

  } finally {
    connection.release();
  }
});

module.exports = router;

