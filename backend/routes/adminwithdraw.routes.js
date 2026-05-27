const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* ================= GET ALL WITH PAYMENT DETAILS ================= */
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        w.id,
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

    res.json({ success: true, data: rows });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});

/* ================= APPROVE ================= */
router.post("/approve", async (req, res) => {
  try {
    const { withdrawal_id } = req.body;

    const [result] = await db.query(`
      UPDATE withdrawals
      SET status = 'approved'
      WHERE id = ? AND status = 'pending'
    `, [withdrawal_id]);

    if (result.affectedRows === 0) {
      return res.json({ success: false, message: "Invalid request" });
    }

    res.json({ success: true, message: "Approved" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});


/* ================= BULK APPROVE ================= */
router.post("/approve-bulk", async (req, res) => {
  try {
    const { ids } = req.body;

    await db.query(`
      UPDATE withdrawals
      SET status = 'approved'
      WHERE id IN (?) AND status='pending'
    `, [ids]);

    res.json({ success: true, message: "Bulk approved" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});


/* ================= MARK AS PAID ================= */
router.post("/mark-paid", async (req, res) => {
  try {
    const { withdrawal_id } = req.body;

    const [result] = await db.query(`
      UPDATE withdrawals
      SET status = 'paid'
      WHERE id = ? AND status = 'approved'
    `, [withdrawal_id]);

    if (result.affectedRows === 0) {
      return res.json({
        success: false,
        message: "Only approved withdrawals can be paid"
      });
    }

    await db.query(`
      UPDATE earnings
      SET status='paid'
      WHERE withdrawal_id=?
    `, [withdrawal_id]);

    res.json({
      success: true,
      message: "Marked as paid"
    });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});


/* ================= REJECT ================= */
router.post("/reject", async (req, res) => {
  try {
    const { withdrawal_id } = req.body;

    await db.query(`
      UPDATE withdrawals
      SET status='rejected'
      WHERE id=?
    `, [withdrawal_id]);

    res.json({ success: true, message: "Rejected" });

  } catch (err) {
    console.error(err);
    res.json({ success: false });
  }
});

module.exports = router;

