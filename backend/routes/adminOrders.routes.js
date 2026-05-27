const express    = require("express");
const router     = express.Router();
const db         = require("../config/db");
const nodemailer = require("nodemailer");

/* =====================================================
   NODEMAILER
===================================================== */

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: { user: process.env.MAIL_USER, pass: process.env.MAIL_PASS },
});

const sendMail = async ({ to, subject, html }) => {
  try {
    await transporter.sendMail({
      from: `"Medico" <${process.env.MAIL_USER}>`,
      to,
      subject,
      html,
    });
    console.log(`Mail sent → ${to}`);
  } catch (err) {
    console.error("Mail error:", err.message);
  }
};

/* =====================================================
   EMAIL TEMPLATES
===================================================== */

const refundApprovedEmail = ({ name, email, amount, orderCode }) =>
  sendMail({
    to: email,
    subject: `Refund of ₹${amount} Approved – ${orderCode}`,
    html: `
  <div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;background:#f9f9f9;border-radius:12px;overflow:hidden">
    <div style="background:linear-gradient(135deg,#1B7F6E,#25A98F);padding:32px 28px;text-align:center">
      <h1 style="color:#fff;margin:0;font-size:22px">Refund Approved ✓</h1>
    </div>
    <div style="padding:28px">
      <p style="color:#333;font-size:15px">Hi <strong>${name}</strong>,</p>
      <p style="color:#555;font-size:14px;line-height:1.7">
        Your refund request for order <strong>${orderCode}</strong> has been approved.
      </p>
      <div style="background:#e8f8f4;border-radius:10px;padding:20px;margin:20px 0;text-align:center">
        <p style="margin:0;color:#0F6E56;font-size:13px;font-weight:600">REFUND AMOUNT</p>
        <p style="margin:8px 0 0;color:#0F6E56;font-size:32px;font-weight:700">₹${amount}</p>
      </div>
      <p style="color:#555;font-size:13.5px;line-height:1.7">
        Your refund has been approved and will be processed via Cashfree.
        Allow <strong>5–7 business days</strong> for the amount to reflect.
      </p>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
      <p style="color:#999;font-size:12px;text-align:center">Medico Healthcare Services</p>
    </div>
  </div>`,
  });

const refundRejectedEmail = ({ name, email, amount, orderCode, reason }) =>
  sendMail({
    to: email,
    subject: `Refund Request Update – ${orderCode}`,
    html: `
  <div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;background:#f9f9f9;border-radius:12px;overflow:hidden">
    <div style="background:#EF4444;padding:32px 28px;text-align:center">
      <h1 style="color:#fff;margin:0;font-size:22px">Refund Not Approved</h1>
    </div>
    <div style="padding:28px">
      <p style="color:#333;font-size:15px">Hi <strong>${name}</strong>,</p>
      <p style="color:#555;font-size:14px;line-height:1.7">
        We reviewed your refund of <strong>₹${amount}</strong> for <strong>${orderCode}</strong>.
        Unfortunately we cannot process it at this time.
      </p>
      <div style="background:#fff0f0;border-left:4px solid #EF4444;border-radius:6px;padding:14px 16px;margin:20px 0">
        <p style="margin:0;color:#c0392b;font-size:13.5px">
          <strong>Reason:</strong> ${reason || "Does not meet refund eligibility criteria."}
        </p>
      </div>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
      <p style="color:#999;font-size:12px;text-align:center">Medico Healthcare Services</p>
    </div>
  </div>`,
  });

/* =====================================================
   GET /  — ALL ORDERS (admin)
===================================================== */

router.get("/", async (req, res) => {
  try {
    const [orders] = await db.query(`
      SELECT
        o.id,
        o.order_code,
        o.total,
        o.status,
        o.payment_method,
        o.payment_id,
        o.payment_status,
        o.date,
        o.slot,
        o.location,
        o.latitude,
        o.longitude,
        o.category,
        o.cancel_reason,
        o.refund_amount,
        o.refund_status,
        o.created_at,
        o.accepted_at,
        o.completed_at,
        o.cancelled_at,
        o.assigned_caretaker_id,

        u.first_name  AS user_first_name,
        u.last_name   AS user_last_name,
        u.mobile      AS user_mobile,
        u.email       AS user_email,

        c.first_name  AS caretaker_first_name,
        c.last_name   AS caretaker_last_name,
        c.mobile      AS caretaker_mobile,

        cancelled_by.first_name AS cancelled_caretaker_first_name,
        cancelled_by.last_name  AS cancelled_caretaker_last_name,
        cancelled_by.mobile     AS cancelled_caretaker_mobile

      FROM orders o
      LEFT JOIN users u            ON o.user_id               = u.id
      LEFT JOIN users c            ON o.caretaker_id          = c.id
      LEFT JOIN users cancelled_by ON o.assigned_caretaker_id = cancelled_by.id

      ORDER BY o.created_at DESC
    `);
    res.json({ success: true, data: orders });
  } catch (err) {
    console.error("GET /orders:", err);
    res.status(500).json({ success: false, message: "Fetch failed" });
  }
});

/* =====================================================
   GET /caretakers-by-category
===================================================== */

router.get("/caretakers-by-category", async (req, res) => {
  const { category } = req.query;
  if (!category)
    return res
      .status(400)
      .json({ success: false, message: "Category required" });

  try {
    const [rows] = await db.query(
      `SELECT u.id, u.first_name, u.last_name, u.mobile,
              u.profile_image, u.approval_status,
              cp.caregiver_type, cp.experience, cp.availability
       FROM users u
       LEFT JOIN caretaker_profiles cp ON cp.user_id = u.id
       WHERE u.role           = 'care_taker'
         AND u.approval_status = 'approved'
         AND cp.caregiver_type = ?
       ORDER BY u.first_name ASC`,
      [category]
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("GET /caretakers-by-category:", err);
    res.status(500).json({ success: false, message: "Fetch failed" });
  }
});

/* =====================================================
   GET /available-caretakers/:orderId
   Slot-aware: excludes caretakers busy on same date+slot
===================================================== */

router.get("/available-caretakers/:orderId", async (req, res) => {
  try {
    const { orderId } = req.params;

    const [[order]] = await db.query(
      `SELECT id, category, date, slot FROM orders WHERE id = ?`,
      [orderId]
    );

    if (!order)
      return res
        .status(404)
        .json({ success: false, message: "Order not found" });

    const [caretakers] = await db.query(
      `
      SELECT
        u.id,
        u.first_name,
        u.last_name,
        u.mobile,
        cp.caregiver_type,
        cp.experience

      FROM users u
      JOIN caretaker_profiles cp ON cp.user_id = u.id

      WHERE u.role             = 'care_taker'
        AND u.approval_status  = 'approved'
        AND cp.caregiver_type  = ?

        AND u.id NOT IN (
          SELECT caretaker_id
          FROM   orders
          WHERE  date         = ?
            AND  slot         = ?
            AND  status       IN ('ACCEPTED', 'IN_PROGRESS')
            AND  caretaker_id IS NOT NULL
        )

      ORDER BY u.first_name ASC
      `,
      [order.category, order.date, order.slot]
    );

    return res.json({
      success: true,
      count: caretakers.length,
      data: caretakers,
    });
  } catch (err) {
    console.error("AVAILABLE CARETAKERS ERROR:", err);
    return res.status(500).json({ success: false, message: "Fetch failed" });
  }
});

/* =====================================================
   POST /:id/assign  — ASSIGN / REASSIGN CARETAKER
   Slot conflict check before assigning
   Sets status → ACCEPTED
===================================================== */

router.post("/:id/assign", async (req, res) => {
  try {
    const { id } = req.params;
    const { caretaker_id } = req.body;

    if (!caretaker_id)
      return res
        .status(400)
        .json({ success: false, message: "caretaker_id required" });

    const [[order]] = await db.query(
      `SELECT id, date, slot, category FROM orders WHERE id = ?`,
      [id]
    );

    if (!order)
      return res
        .status(404)
        .json({ success: false, message: "Order not found" });

    /* ── Slot conflict check ── */
    const [[conflict]] = await db.query(
      `
      SELECT id FROM orders
      WHERE caretaker_id = ?
        AND date         = ?
        AND slot         = ?
        AND status       IN ('ACCEPTED', 'IN_PROGRESS')
      LIMIT 1
      `,
      [caretaker_id, order.date, order.slot]
    );

    if (conflict)
      return res.json({
        success: false,
        message: "Caretaker already busy for this slot",
      });

    await db.query(
      `
      UPDATE orders
      SET caretaker_id          = ?,
          assigned_caretaker_id = ?,
          status                = 'ACCEPTED',
          accepted_at           = NOW()
      WHERE id = ?
      `,
      [caretaker_id, caretaker_id, id]
    );

    return res.json({
      success: true,
      message: "Caretaker assigned successfully",
    });
  } catch (err) {
    console.error("ASSIGN ERROR:", err);
    return res.status(500).json({ success: false, message: "Assignment failed" });
  }
});

/* =====================================================
   PUT /:id/cancel  — CANCEL ORDER (admin)
===================================================== */

router.put("/:id/cancel", async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  if (!reason?.trim())
    return res
      .status(400)
      .json({ success: false, message: "Reason required" });

  try {
    await db.query(
      `UPDATE orders
       SET status        = 'CANCELLED',
           cancel_reason = ?,
           cancelled_at  = NOW()
       WHERE id = ?`,
      [reason, id]
    );
    res.json({ success: true, message: "Order cancelled" });
  } catch (err) {
    console.error("PUT /:id/cancel:", err);
    res.status(500).json({ success: false, message: "Cancel failed" });
  }
});

/* =====================================================
   PUT /status/:id  — UPDATE STATUS (admin override)
===================================================== */

router.put("/status/:id", async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!status)
    return res
      .status(400)
      .json({ success: false, message: "Status required" });

  try {
    await db.query("UPDATE orders SET status = ? WHERE id = ?", [
      status,
      id,
    ]);
    res.json({ success: true, message: "Status updated" });
  } catch (err) {
    console.error("PUT /status/:id:", err);
    res.status(500).json({ success: false, message: "Update failed" });
  }
});

/* =====================================================
   GET /refunds  — GET ALL REFUND REQUESTS
===================================================== */

router.get("/refunds", async (req, res) => {
  const { order_id } = req.query;
  try {
    let query = `
      SELECT rr.*,
             o.order_code, o.total, o.payment_method, o.payment_id,
             o.date, o.slot, o.cancel_reason, o.cancelled_at,
             u.first_name, u.last_name, u.email, u.mobile
      FROM refund_requests rr
      JOIN orders o ON o.id = rr.order_id
      JOIN users  u ON u.id = rr.user_id
    `;
    const params = [];
    if (order_id) {
      query += " WHERE rr.order_id = ?";
      params.push(order_id);
    }
    query += " ORDER BY rr.requested_at DESC";

    const [rows] = await db.query(query, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error("GET /refunds:", err);
    res.status(500).json({ success: false, message: "Fetch failed" });
  }
});

/* =====================================================
   POST /refunds/:id/approve  — APPROVE REFUND
   NOTE: Cashfree refund API not yet integrated.
   Admin marks approved in DB → must manually process
   via Cashfree dashboard until API is wired up.
===================================================== */

router.post("/refunds/:id/approve", async (req, res) => {
  try {
    const [[refund]] = await db.query(
      `SELECT rr.*, u.first_name, u.email
       FROM refund_requests rr
       JOIN users u ON u.id = rr.user_id
       WHERE rr.id = ?`,
      [req.params.id]
    );

    if (!refund)
      return res
        .status(404)
        .json({ success: false, message: "Refund not found" });

    if (refund.status !== "PENDING")
      return res
        .status(400)
        .json({ success: false, message: "Already processed" });

    const [[order]] = await db.query(
      "SELECT order_code FROM orders WHERE id = ?",
      [refund.order_id]
    );

    await db.query(
      `UPDATE refund_requests
       SET status       = 'APPROVED',
           processed_at = NOW()
       WHERE id = ?`,
      [refund.id]
    );

    await db.query(
      `UPDATE orders
       SET refund_status  = 'REFUNDED',
           payment_status = 'REFUNDED'
       WHERE id = ?`,
      [refund.order_id]
    );

    res.json({
      success: true,
      message: `Refund of ₹${refund.refund_amount} marked as approved. Please process manually via Cashfree dashboard.`,
    });

    setImmediate(() =>
      refundApprovedEmail({
        name:      refund.first_name,
        email:     refund.email,
        amount:    refund.refund_amount,
        orderCode: order?.order_code || `#${refund.order_id}`,
      })
    );
  } catch (err) {
    console.error("POST /refunds/:id/approve:", err);
    res
      .status(500)
      .json({ success: false, message: "Refund approval failed" });
  }
});

/* =====================================================
   POST /refunds/:id/reject  — REJECT REFUND
===================================================== */

router.post("/refunds/:id/reject", async (req, res) => {
  const { reason } = req.body;
  try {
    const [[refund]] = await db.query(
      `SELECT rr.*, u.first_name, u.email
       FROM refund_requests rr
       JOIN users u ON u.id = rr.user_id
       WHERE rr.id = ?`,
      [req.params.id]
    );

    if (!refund)
      return res
        .status(404)
        .json({ success: false, message: "Refund not found" });

    if (refund.status !== "PENDING")
      return res
        .status(400)
        .json({ success: false, message: "Already processed" });

    const [[order]] = await db.query(
      "SELECT order_code FROM orders WHERE id = ?",
      [refund.order_id]
    );

    await db.query(
      `UPDATE refund_requests
       SET status        = 'REJECTED',
           reject_reason = ?,
           processed_at  = NOW()
       WHERE id = ?`,
      [reason || "", req.params.id]
    );

    await db.query(
      "UPDATE orders SET refund_status = 'REJECTED' WHERE id = ?",
      [refund.order_id]
    );

    res.json({ success: true, message: "Refund rejected." });

    setImmediate(() =>
      refundRejectedEmail({
        name:      refund.first_name,
        email:     refund.email,
        amount:    refund.refund_amount,
        orderCode: order?.order_code || `#${refund.order_id}`,
        reason,
      })
    );
  } catch (err) {
    console.error("POST /refunds/:id/reject:", err);
    res
      .status(500)
      .json({ success: false, message: "Rejection failed" });
  }
});

module.exports = router;