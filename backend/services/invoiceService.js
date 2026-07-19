const db = require("../config/db");

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

/**
 * Creates (or returns the existing) invoice row for an order.
 * Safe to call multiple times — idempotent via the order_id UNIQUE
 * constraint + ER_DUP_ENTRY fallback.
 *
 * @param {number|string} orderId
 * @param {import('mysql2/promise').PoolConnection} [conn] optional
 *        connection/transaction to run on (defaults to the pool `db`)
 * @returns {Promise<object>} the invoice row (raw DB row, not formatted)
 */
async function createInvoiceForOrder(orderId, conn = db) {
  const [[existing]] = await conn.query(`SELECT * FROM invoices WHERE order_id = ?`, [orderId]);
  if (existing) return existing;

  const [[order]] = await conn.query(
    `SELECT o.*,
            cust.first_name AS customer_first_name, cust.last_name AS customer_last_name,
            ct.first_name   AS caretaker_first_name, ct.last_name   AS caretaker_last_name
     FROM orders o
     LEFT JOIN users cust ON cust.id = o.user_id
     LEFT JOIN users ct   ON ct.id = o.caretaker_id
     WHERE o.id = ?`,
    [orderId]
  );
  if (!order) throw new Error(`createInvoiceForOrder: order ${orderId} not found`);

  const [items] = await conn.query(
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
    const [insertRes] = await conn.query(
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
      const [[row]] = await conn.query(`SELECT * FROM invoices WHERE order_id = ?`, [orderId]);
      return row;
    }
    throw e;
  }

  const d = new Date(order.date);
  const invoiceNo = `INV-${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(
    d.getDate()
  ).padStart(2, "0")}-${String(invoiceId).padStart(4, "0")}`;

  await conn.query(`UPDATE invoices SET invoice_no = ? WHERE id = ?`, [invoiceNo, invoiceId]);

  const [[row]] = await conn.query(`SELECT * FROM invoices WHERE id = ?`, [invoiceId]);
  return row;
}

module.exports = { createInvoiceForOrder };