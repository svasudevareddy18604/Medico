const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* ================= TEST ================= */

router.get("/test", (req, res) => {
  res.send("ADMIN ROUTE WORKING");
});

/* ================= GET WITHDRAWALS ================= */
/* 🔥 FIXED: Now includes caretaker name + mobile */

router.get("/withdrawals", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        w.id,
        w.amount,
        w.status,
        w.created_at,

        CONCAT(u.first_name, ' ', u.last_name) AS caretaker_name,
        u.mobile AS caretaker_mobile

      FROM withdrawals w
      LEFT JOIN users u 
        ON w.caretaker_id = u.id

      ORDER BY w.created_at DESC
    `);

    res.json({
      success: true,
      data: rows
    });

  } catch (err) {
    console.error("GET WITHDRAWALS ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Failed to fetch withdrawals"
    });
  }
});

/* ================= APPROVE ================= */

router.post("/withdraw/approve", async (req, res) => {
  const connection = await db.getConnection();

  try {
    const { withdrawal_id } = req.body;

    if (!withdrawal_id) {
      return res.json({
        success: false,
        message: "Withdrawal ID required"
      });
    }

    await connection.beginTransaction();

    /* ===== CHECK VALID ===== */
    const [w] = await connection.query(`
      SELECT * FROM withdrawals
      WHERE id = ? AND status = 'pending'
      FOR UPDATE
    `, [withdrawal_id]);

    if (w.length === 0) {
      await connection.rollback();
      return res.json({
        success: false,
        message: "Invalid or already processed"
      });
    }

    /* ===== UPDATE WITHDRAWAL ===== */
    await connection.query(`
      UPDATE withdrawals
      SET status = 'approved'
      WHERE id = ?
    `, [withdrawal_id]);

    /* ===== UPDATE EARNINGS ===== */
    await connection.query(`
      UPDATE earnings
      SET status = 'paid'
      WHERE withdrawal_id = ?
    `, [withdrawal_id]);

    await connection.commit();

    res.json({
      success: true,
      message: "Withdraw approved & marked as paid"
    });

  } catch (err) {
    await connection.rollback();
    console.error("APPROVE ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Approval failed"
    });

  } finally {
    connection.release();
  }
});

/* ================= REJECT ================= */

router.post("/withdraw/reject", async (req, res) => {
  const connection = await db.getConnection();

  try {
    const { withdrawal_id } = req.body;

    if (!withdrawal_id) {
      return res.json({
        success: false,
        message: "Withdrawal ID required"
      });
    }

    await connection.beginTransaction();

    /* ===== CHECK VALID ===== */
    const [w] = await connection.query(`
      SELECT * FROM withdrawals
      WHERE id = ? AND status = 'pending'
      FOR UPDATE
    `, [withdrawal_id]);

    if (w.length === 0) {
      await connection.rollback();
      return res.json({
        success: false,
        message: "Invalid or already processed"
      });
    }

    /* ===== REJECT WITHDRAW ===== */
    await connection.query(`
      UPDATE withdrawals
      SET status = 'rejected'
      WHERE id = ?
    `, [withdrawal_id]);

    /* ===== RELEASE EARNINGS ===== */
    await connection.query(`
      UPDATE earnings
      SET status = 'pending', withdrawal_id = NULL
      WHERE withdrawal_id = ?
    `, [withdrawal_id]);

    await connection.commit();

    res.json({
      success: true,
      message: "Withdraw rejected"
    });

  } catch (err) {
    await connection.rollback();
    console.error("REJECT ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Reject failed"
    });

  } finally {
    connection.release();
  }
});

module.exports = router;