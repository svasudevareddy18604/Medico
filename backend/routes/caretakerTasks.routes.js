const router = require("express").Router();
const db = require("../config/db");

/* =========================================================
   1. AVAILABLE TASKS (category-filtered, safe)
========================================================= */
router.get("/available/:category", async (req, res) => {
  try {
    const { category } = req.params;

    const [orders] = await db.query(`
      SELECT 
        o.id,
        o.order_code,
        o.location,
        o.date,
        o.slot,
        o.total,
        o.payment_method,
        o.status,
        o.category,
        s.name AS service
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.id
      JOIN services s ON s.id = oi.service_id
      WHERE o.category = ?
        AND o.caretaker_id IS NULL
        AND o.status = 'PLACED'
      GROUP BY o.id
      ORDER BY o.date ASC, o.slot ASC
      LIMIT 20
    `, [category]);

    res.json({ success: true, orders });

  } catch (err) {
    console.error("AVAILABLE TASK ERROR:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});



/* =========================================================
   2. ACCEPT TASK (STRICT + SAFE)
========================================================= */
router.post("/accept", async (req, res) => {
  let conn;

  try {
    const { order_id, caretaker_id } = req.body;

    if (!order_id || !caretaker_id) {
      return res.status(400).json({
        success: false,
        message: "Missing order_id or caretaker_id"
      });
    }

    conn = await db.getConnection();
    await conn.beginTransaction();

    /* 🔥 CATEGORY VALIDATION + RACE CONDITION FIX */
    const [result] = await conn.query(`
      UPDATE orders o
      JOIN caretaker_profiles cp ON cp.user_id = ?
      SET 
        o.caretaker_id = ?,
        o.caretaker_response = 'ACCEPTED',
        o.status = 'CONFIRMED',
        o.accepted_at = NOW()
      WHERE o.id = ?
        AND o.caretaker_id IS NULL
        AND o.status = 'PLACED'
        AND cp.caregiver_type = o.category
    `, [caretaker_id, caretaker_id, order_id]);

    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.json({
        success: false,
        message: "Already accepted OR not allowed for your category"
      });
    }

    /* OPTIONAL: TRACK ASSIGNMENT */
    await conn.query(`
      INSERT INTO order_assignments (order_id, caretaker_id, status, accepted_at)
      VALUES (?, ?, 'accepted', NOW())
    `, [order_id, caretaker_id]);

    await conn.commit();

    res.json({
      success: true,
      message: "Task accepted successfully"
    });

  } catch (err) {
    if (conn) await conn.rollback();
    console.error("ACCEPT ERROR:", err);
    res.status(500).json({ success: false });
  } finally {
    if (conn) conn.release();
  }
});



/* =========================================================
   3. MY TASKS (SAFE + CLEAN)
========================================================= */
router.get("/my-tasks/:caretaker_id", async (req, res) => {
  try {
    const { caretaker_id } = req.params;

    const [orders] = await db.query(`
      SELECT 
        o.id,
        o.order_code,
        o.location,
        o.date,
        o.slot,
        o.total,
        o.payment_method,
        o.status,
        o.category,
        s.name AS service
      FROM orders o
      JOIN order_items oi ON oi.order_id = o.id
      JOIN services s ON s.id = oi.service_id
      WHERE o.caretaker_id = ?
        AND o.status != 'CANCELLED'
      GROUP BY o.id
      ORDER BY o.accepted_at DESC
    `, [caretaker_id]);

    res.json({ success: true, orders });

  } catch (err) {
    console.error("MY TASKS ERROR:", err);
    res.status(500).json({ success: false });
  }
});



/* =========================================================
   4. UPDATE TASK STATUS (STRICT FLOW CONTROL)
========================================================= */
router.post("/update-status", async (req, res) => {
  try {
    const { order_id, caretaker_id, status } = req.body;

    if (!order_id || !caretaker_id || !status) {
      return res.status(400).json({
        success: false,
        message: "Missing fields"
      });
    }

    /* 🔥 STRICT FLOW CONTROL */
    const [[order]] = await db.query(
      "SELECT status FROM orders WHERE id = ? AND caretaker_id = ?",
      [order_id, caretaker_id]
    );

    if (!order) {
      return res.json({
        success: false,
        message: "Order not found or not yours"
      });
    }

    const allowedTransitions = {
      CONFIRMED: ["IN_PROGRESS"],
      IN_PROGRESS: ["COMPLETED"]
    };

    if (!allowedTransitions[order.status] || 
        !allowedTransitions[order.status].includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status transition from ${order.status} → ${status}`
      });
    }

    const extra = status === "COMPLETED" ? ", completed_at = NOW()" : "";

    await db.query(
      `UPDATE orders SET status = ? ${extra} WHERE id = ? AND caretaker_id = ?`,
      [status, order_id, caretaker_id]
    );

    res.json({
      success: true,
      message: "Status updated"
    });

  } catch (err) {
    console.error("UPDATE STATUS ERROR:", err);
    res.status(500).json({ success: false });
  }
});



module.exports = router;