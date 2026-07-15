const router = require("express").Router();
const db = require("../config/db");

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) : "";

const fmtSlot = (raw) => {
  if (!raw) return "-";
  try {
    const [hStr, mStr = "00"] = raw.toString().split(":");
    let h = parseInt(hStr, 10);
    const suffix = h >= 12 ? "PM" : "AM";
    if (h > 12) h -= 12;
    if (h === 0) h = 12;
    return `${h}:${mStr} ${suffix}`;
  } catch (_) {
    return raw;
  }
};

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

router.get("/order/:orderId", async (req, res) => {
  const { orderId } = req.params;
  try {
    const [[existing]] = await db.query(`SELECT * FROM invoices WHERE order_id = ?`, [orderId]);
    if (existing) {
      return res.json({ success: true, invoice: formatInvoiceRow(existing) });
    }

    const [[order]] = await db.query(
      `SELECT o.*,
              cust.first_name AS customer_first_name, cust.last_name AS customer_last_name,
              ct.first_name   AS caretaker_first_name, ct.last_name   AS caretaker_last_name
       FROM orders o
       LEFT JOIN users cust ON cust.id = o.user_id
       LEFT JOIN users ct   ON ct.id = o.caretaker_id
       WHERE o.id = ?`,
      [orderId]
    );
    if (!order) return res.status(404).json({ success: false, message: "Order not found" });

    const [items] = await db.query(
      `SELECT s.name AS service_name, oi.price
       FROM order_items oi
       JOIN services s ON s.id = oi.service_id
       WHERE oi.order_id = ?`,
      [orderId]
    );

    const customerName =
      [order.customer_first_name, order.customer_last_name].filter(Boolean).join(" ") || "Customer";
    const caretakerName = order.caretaker_id
      ? [order.caretaker_first_name, order.caretaker_last_name].filter(Boolean).join(" ") || "Caretaker"
      : "Not assigned yet";

    const itemsJson =
      items.length > 0
        ? items.map((i) => ({
            service_name: i.service_name,
            category: order.category || "Service",
            slot: fmtSlot(order.slot),
            price: parseFloat(i.price),
          }))
        : [
            {
              service_name: order.category || "Service",
              category: order.category || "Service",
              slot: fmtSlot(order.slot),
              price: parseFloat(order.total),
            },
          ];

    let invoiceId;
    try {
      const [insertRes] = await db.query(
        `INSERT INTO invoices
         (order_id, order_code, customer_name, caretaker_name, payment_method, payment_status,
          subtotal, service_charge, discount, total, items_json, order_date)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderId, order.order_code, customerName, caretakerName,
          order.payment_method, order.payment_status,
          order.subtotal, order.service_charge, order.discount_amount, order.total,
          JSON.stringify(itemsJson), order.date,
        ]
      );
      invoiceId = insertRes.insertId;
    } catch (e) {
      if (e.code === "ER_DUP_ENTRY") {
        const [[row]] = await db.query(`SELECT * FROM invoices WHERE order_id = ?`, [orderId]);
        return res.json({ success: true, invoice: formatInvoiceRow(row) });
      }
      throw e;
    }

    const d = new Date(order.date);
    const invoiceNo = `INV-${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(
      d.getDate()
    ).padStart(2, "0")}-${String(invoiceId).padStart(4, "0")}`;

    await db.query(`UPDATE invoices SET invoice_no = ? WHERE id = ?`, [invoiceNo, invoiceId]);

    const [[row]] = await db.query(`SELECT * FROM invoices WHERE id = ?`, [invoiceId]);
    return res.json({ success: true, invoice: formatInvoiceRow(row) });
  } catch (err) {
    console.error("INVOICE ERROR:", err);
    return res.status(500).json({ success: false, message: "Failed to load invoice" });
  }
});

// update displayPaymentStatus case block:
const displayPaymentStatus = (s) => {
  switch ((s || "").toUpperCase()) {
    case "PAID": return "Paid";
    case "PENDING": return "Pending";
    case "FAILED": return "Failed";
    case "REFUNDED": return "Refunded";
    default: return s || "-";
  }
};

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