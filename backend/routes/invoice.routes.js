const router = require("express").Router();
const db = require("../config/db");
const { createInvoiceForOrder } = require("../services/invoiceService");

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) : "";

const displayPaymentMethod = (m) => {
  switch ((m || "").toUpperCase()) {
    case "COD": return "Cash on Delivery";
    case "ONLINE": return "Online";
    default: return m || "-";
  }
};

const displayPaymentStatus = (s) => {
  switch ((s || "").toUpperCase()) {
    case "PAID": return "Paid";
    case "PENDING": return "Pending";
    case "FAILED": return "Failed";
    case "REFUNDED": return "Refunded";
    default: return s || "-";
  }
};

function formatInvoiceRow(row) {
  return {
    invoice_id: row.id,
    invoice_no: row.invoice_no,
    order_id: row.order_id,
    booking_id: row.order_code,
    date: fmtDate(row.order_date),
    customer_name: row.customer_name,
    caretaker_name: row.caretaker_name,
    items: typeof row.items_json === "string" ? JSON.parse(row.items_json) : row.items_json,
    subtotal: parseFloat(row.subtotal),
    service_charge: parseFloat(row.service_charge),
    discount: parseFloat(row.discount),
    total: parseFloat(row.total),
    payment_method: displayPaymentMethod(row.payment_method),
    payment_status: displayPaymentStatus(row.payment_status),
  };
}

/* =====================================================
   GET /api/invoice/order/:orderId
   Careseeker: fetch invoice for one order.
   Invoice should already exist (created at order-placement
   time) — this call now just reads it, with the old
   generate-on-read logic kept ONLY as a safety-net fallback
   for orders that predate this fix.
===================================================== */
router.get("/order/:orderId", async (req, res) => {
  const { orderId } = req.params;
  try {
    const row = await createInvoiceForOrder(orderId); // returns existing row if already created
    return res.json({ success: true, invoice: formatInvoiceRow(row) });
  } catch (err) {
    console.error("INVOICE ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load invoice" });
  }
});

/* =====================================================
   GET /api/invoice/admin/all
   Admin: list all invoices, with optional search (booking id /
   invoice no / customer name) and payment status filter.
===================================================== */
router.get("/admin/all", async (req, res) => {
  try {
    const { search = "", status = "" } = req.query;
    let query = `SELECT * FROM invoices WHERE 1=1`;
    const params = [];

    if (search.trim()) {
      const like = `%${search.trim()}%`;
      query += ` AND (invoice_no LIKE ? OR order_code LIKE ? OR customer_name LIKE ?)`;
      params.push(like, like, like);
    }

    if (status.trim()) {
      query += ` AND payment_status = ?`;
      params.push(status.trim().toUpperCase());
    }

    query += ` ORDER BY created_at DESC`;

    const [rows] = await db.query(query, params);
    return res.json({ success: true, invoices: rows.map(formatInvoiceRow) });
  } catch (err) {
    console.error("ADMIN INVOICE LIST ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load invoices" });
  }
});

module.exports = router;