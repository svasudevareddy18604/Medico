const db = require("../config/db");
const sendEmail = require("../config/mailer");

const {
  sendPushNotification
} = require("../services/pushNotification.service");

/* ─────────────────────────────────────────
   PROFESSIONAL EMAIL TEMPLATE
───────────────────────────────────────── */

const emailTemplate = ({
  title,
  subtitle,
  content,
  statusColor = "#16a34a"
}) => {

  return `
  <!DOCTYPE html>
  <html>

  <head>
    <meta charset="UTF-8" />

    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>

    <title>${title}</title>
  </head>

  <body style="
    margin:0;
    padding:0;
    background:#f3f4f6;
    font-family:Arial,sans-serif;
  ">

    <table width="100%" cellpadding="0" cellspacing="0" style="
      background:#f3f4f6;
      padding:20px 10px;
    ">

      <tr>
        <td align="center">

          <table width="100%" cellpadding="0" cellspacing="0" style="
            max-width:650px;
            background:#ffffff;
            border-radius:16px;
            overflow:hidden;
            box-shadow:0 4px 20px rgba(0,0,0,0.08);
          ">

            <!-- HEADER -->

            <tr>
              <td style="
                background:${statusColor};
                padding:35px 25px;
                text-align:center;
              ">

                <h1 style="
                  color:white;
                  margin:0;
                  font-size:28px;
                ">
                  Medico
                </h1>

                <p style="
                  color:#e5e7eb;
                  margin-top:10px;
                  font-size:15px;
                ">
                  ${subtitle}
                </p>

              </td>
            </tr>

            <!-- BODY -->

            <tr>
              <td style="
                padding:35px 25px;
                color:#111827;
                font-size:15px;
                line-height:1.8;
              ">

                ${content}

              </td>
            </tr>

            <!-- FOOTER -->

            <tr>
              <td style="
                background:#f9fafb;
                padding:20px;
                text-align:center;
                border-top:1px solid #e5e7eb;
              ">

                <p style="
                  margin:0;
                  color:#6b7280;
                  font-size:13px;
                ">
                  © ${new Date().getFullYear()} Medico
                </p>

                <p style="
                  margin-top:8px;
                  color:#9ca3af;
                  font-size:12px;
                ">
                  Professional Home Healthcare Services
                </p>

              </td>
            </tr>

          </table>

        </td>
      </tr>

    </table>

  </body>
  </html>
  `;
};

/* ─────────────────────────────────────────
   ORDER DETAILS TABLE
───────────────────────────────────────── */
const orderTable = ({
  orderCode,
  serviceName,
  dateStr,
  slot,
  payment_method,
  total,
  location
}) => {

  return `

  <table width="100%" cellpadding="0" cellspacing="0" style="
    margin-top:18px;
    border:1px solid #e5e7eb;
  ">

    ${
      orderCode ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
          width:40%;
        ">
          Booking ID
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ${orderCode}
        </td>
      </tr>
      ` : ""
    }

    ${
      serviceName ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
        ">
          Service
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ${serviceName}
        </td>
      </tr>
      ` : ""
    }

    ${
      dateStr ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
        ">
          Date
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ${dateStr}
        </td>
      </tr>
      ` : ""
    }

    ${
      slot ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
        ">
          Slot
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ${slot}
        </td>
      </tr>
      ` : ""
    }

    ${
      payment_method ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
        ">
          Payment
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ${payment_method}
        </td>
      </tr>
      ` : ""
    }

    ${
      total ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
        ">
          Total
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ₹${total}
        </td>
      </tr>
      ` : ""
    }

    ${
      location ? `
      <tr>
        <td style="
          padding:10px;
          background:#f9fafb;
          font-size:13px;
          font-weight:bold;
        ">
          Location
        </td>

        <td style="
          padding:10px;
          font-size:13px;
        ">
          ${location}
        </td>
      </tr>
      ` : ""
    }

  </table>

  `;
};
/* ─────────────────────────────────────────
   USER BOOKING CONFIRMATION
───────────────────────────────────────── */

const sendBookingConfirmedToUser = async ({
  user,
  order,
  bookingId,
  serviceName,
  dateStr,
  slot,
  payment_method
}) => {

  try {

    console.log("SENDING USER EMAIL TO:", user?.email);

    // Accept either naming style so this never silently breaks again
    // if the caller's field names change.
    const orderCode = bookingId || order.order_code || order.orderCode || "";
    const total     = order.total ?? order.totalPrice ?? "";

    if (user?.fcm_token) {

      await sendPushNotification(
        user.fcm_token,
        "✅ Booking Confirmed",
        `${orderCode} confirmed successfully`
      );

    }

    if (user?.email) {

      await sendEmail({
        to: user.email,

        subject: `✅ Booking Confirmed - ${orderCode}`,

        html: emailTemplate({
          title: "Booking Confirmed",

          subtitle: "Your healthcare booking has been confirmed",

          statusColor: "#16a34a",

          content: `
            <p>Hello <b>${user.first_name}</b>,</p>

            <p>
              Your booking has been successfully confirmed.
              Our caretaker team will connect with you shortly.
            </p>

            ${orderTable({
              orderCode,
              serviceName,
              dateStr,
              slot,
              payment_method,
              total
            })}

            <p style="
              margin-top:25px;
              color:#374151;
            ">
              Thank you for choosing Medico.
            </p>
          `
        })
      });

      console.log("USER EMAIL SENT");

    }

  } catch (err) {

    console.log("USER EMAIL ERROR:", err);

  }

};

/* ─────────────────────────────────────────
   CARETAKER ALERTS
───────────────────────────────────────── */

const sendBookingAlertToCaretakers = async ({
  order,
  bookingId,
  serviceName,
  dateStr,
  slot,
  location
}) => {

  try {

    console.log("FETCHING CARETAKERS FOR:", order.category);

    // Accept either naming style.
    const orderCode = bookingId || order.order_code || order.orderCode || "";

    const [caretakers] = await db.query(`
      SELECT
      u.id,
      u.first_name,
      u.email,
      u.fcm_token,
      cp.caregiver_type

      FROM users u

      JOIN caretaker_profiles cp
      ON cp.user_id = u.id

      WHERE u.role = 'care_taker'
      AND cp.is_available = 1
      AND cp.caregiver_type = ?
    `, [order.category]);

    console.log("CARETAKERS FOUND:", caretakers.length);

    for (const ct of caretakers) {

      try {

        console.log("CARETAKER:", ct.email);

        if (ct.fcm_token) {

          await sendPushNotification(
            ct.fcm_token,
            "🔔 New Booking Available",
            `${orderCode} available for acceptance`
          );

        }

        if (ct.email) {

          await sendEmail({
            to: ct.email,

            subject: `🔔 New Booking Available - ${orderCode}`,

            html: emailTemplate({
              title: "New Booking Available",

              subtitle: "A patient booking is waiting for your acceptance",

              statusColor: "#2563eb",

              content: `
                <p>Hello <b>${ct.first_name}</b>,</p>

                <p>
                  A new booking matching your caregiver category
                  is available.
                </p>

                ${orderTable({
                  orderCode,
                  serviceName,
                  dateStr,
                  slot,
                  location
                })}

                <p style="
                  margin-top:25px;
                  color:#374151;
                ">
                  Please open the Medico app and accept the booking.
                </p>
              `
            })
          });

          console.log("CARETAKER EMAIL SENT:", ct.email);

        } else {

          console.log("NO CARETAKER EMAIL FOUND");

        }

      } catch (err) {

        console.log("INDIVIDUAL CARETAKER ERROR:", err);

      }

    }

  } catch (err) {

    console.log("CARETAKER ALERT ERROR:", err);

  }

};

/* ─────────────────────────────────────────
   CANCELLATION
───────────────────────────────────────── */

const sendCancellationNotifications = async (order) => {

  try {

    const [[user]] = await db.query(`
      SELECT first_name,email,fcm_token
      FROM users
      WHERE id = ?
    `, [order.user_id]);

    if (user?.fcm_token) {

      await sendPushNotification(
        user.fcm_token,
        "❌ Booking Cancelled",
        `${order.order_code} cancelled`
      );

    }

    if (user?.email) {

      await sendEmail({
        to: user.email,

        subject: `❌ Booking Cancelled - ${order.order_code}`,

        html: emailTemplate({
          title: "Booking Cancelled",

          subtitle: "Your booking has been cancelled",

          statusColor: "#dc2626",

          content: `
            <p>Hello <b>${user.first_name}</b>,</p>

            <p>
              Your booking has been cancelled successfully.
            </p>

            ${orderTable({
              orderCode: order.order_code
            })}
          `
        })
      });

    }

  } catch (err) {

    console.log("CANCELLATION ERROR:", err);

  }

};

module.exports = {
  sendBookingConfirmedToUser,
  sendBookingAlertToCaretakers,
  sendCancellationNotifications
};