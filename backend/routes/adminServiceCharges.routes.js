const express = require("express");
const router = express.Router();
const db = require("../config/db");

/* =========================
   HELPER: GET OR CREATE ROW
========================= */
async function getOrCreateSettings() {
  const [rows] = await db.query(
    "SELECT * FROM service_charges LIMIT 1"
  );

  if (rows.length === 0) {
    const [result] = await db.query(
      `INSERT INTO service_charges 
       (is_enabled, charge_type, amount)
       VALUES (1, 'flat', 0)`
    );

    return {
      id: result.insertId,
      is_enabled: 1,
      charge_type: "flat",
      amount: 0,
    };
  }

  return rows[0];
}

/* =========================
   GET SERVICE CHARGES
========================= */
router.get("/", async (req, res) => {
  try {
    const data = await getOrCreateSettings();

    return res.json({
      id: data.id,
      is_enabled: data.is_enabled === 1,
      charge_type: data.charge_type,
      amount: data.amount,
    });

  } catch (err) {
    console.error("GET SERVICE CHARGES ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

/* =========================
   UPDATE SERVICE CHARGES
========================= */
router.put("/", async (req, res) => {
  try {
    let { is_enabled, charge_type, amount } = req.body;

    /// 🔥 VALIDATION
    if (!["flat", "per_km"].includes(charge_type)) {
      return res.status(400).json({
        success: false,
        message: "charge_type must be 'flat' or 'per_km'",
      });
    }

    if (amount === undefined || isNaN(amount)) {
      return res.status(400).json({
        success: false,
        message: "amount must be a valid number",
      });
    }

    /// 🔥 SANITIZE
    is_enabled = is_enabled ? 1 : 0;
    amount = parseInt(amount);

    /// 🔥 GET EXISTING ROW
    const existing = await getOrCreateSettings();

    /// 🔥 UPDATE
    await db.query(
      `UPDATE service_charges
       SET is_enabled = ?, charge_type = ?, amount = ?
       WHERE id = ?`,
      [is_enabled, charge_type, amount, existing.id]
    );

    return res.json({
      success: true,
      message: "Service charges updated successfully",
    });

  } catch (err) {
    console.error("UPDATE SERVICE CHARGES ERROR:", err);

    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

module.exports = router;