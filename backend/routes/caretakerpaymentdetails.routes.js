const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================
   ADD NEW PAYMENT METHOD
========================= */
router.post("/", async (req, res) => {
  try {
    let {
      user_id,
      type,
      upi_id,
      account_number,
      ifsc_code,
      account_name
    } = req.body;

    if (!user_id || !type) {
      return res.status(400).json({ success: false, message: "Missing fields" });
    }

    type = type.toUpperCase();

    if (!["UPI", "BANK"].includes(type)) {
      return res.status(400).json({ success: false, message: "Invalid type" });
    }

    upi_id = upi_id?.trim() || null;
    account_number = account_number?.trim() || null;
    ifsc_code = ifsc_code?.trim() || null;
    account_name = account_name?.trim() || null;

    if (type === "UPI") {
      if (!upi_id) {
        return res.status(400).json({ success: false, message: "UPI required" });
      }
      account_number = null;
      ifsc_code = null;
      account_name = null;
    }

    if (type === "BANK") {
      if (!account_number || !ifsc_code || !account_name) {
        return res.status(400).json({ success: false, message: "Bank details required" });
      }
      upi_id = null;
    }

    await db.query(
      `INSERT INTO caregiver_payment_details 
      (user_id, type, upi_id, account_number, ifsc_code, account_name)
      VALUES (?, ?, ?, ?, ?, ?)`,
      [user_id, type, upi_id, account_number, ifsc_code, account_name]
    );

    return res.json({ success: true, message: "Added successfully" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});


/* =========================
   GET ALL METHODS
========================= */
router.get("/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    const [rows] = await db.query(
      `SELECT * FROM caregiver_payment_details WHERE user_id = ? ORDER BY is_primary DESC`,
      [userId]
    );

    return res.json({
      success: true,
      data: rows
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false });
  }
});


/* =========================
   UPDATE METHOD
========================= */
router.put("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    let {
      type,
      upi_id,
      account_number,
      ifsc_code,
      account_name
    } = req.body;

    type = type.toUpperCase();

    upi_id = upi_id?.trim() || null;
    account_number = account_number?.trim() || null;
    ifsc_code = ifsc_code?.trim() || null;
    account_name = account_name?.trim() || null;

    if (type === "UPI") {
      account_number = null;
      ifsc_code = null;
      account_name = null;
    }

    if (type === "BANK") {
      upi_id = null;
    }

    await db.query(
      `UPDATE caregiver_payment_details 
       SET type=?, upi_id=?, account_number=?, ifsc_code=?, account_name=?
       WHERE id=?`,
      [type, upi_id, account_number, ifsc_code, account_name, id]
    );

    return res.json({ success: true, message: "Updated" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false });
  }
});


/* =========================
   DELETE METHOD
========================= */
router.delete("/:id", async (req, res) => {
  try {
    await db.query(
      `DELETE FROM caregiver_payment_details WHERE id=?`,
      [req.params.id]
    );

    return res.json({ success: true, message: "Deleted" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false });
  }
});


/* =========================
   SET PRIMARY METHOD
========================= */
router.patch("/:id/primary", async (req, res) => {
  try {
    const { id } = req.params;

    // Get user_id of this record
    const [rows] = await db.query(
      `SELECT user_id FROM caregiver_payment_details WHERE id=?`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false });
    }

    const userId = rows[0].user_id;

    // Remove previous primary
    await db.query(
      `UPDATE caregiver_payment_details SET is_primary=0 WHERE user_id=?`,
      [userId]
    );

    // Set new primary
    await db.query(
      `UPDATE caregiver_payment_details SET is_primary=1 WHERE id=?`,
      [id]
    );

    return res.json({ success: true, message: "Primary updated" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false });
  }
});

module.exports = router;