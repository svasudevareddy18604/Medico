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
   HELPER — fetch a careseeker/caretaker row by id
   (kept minimal + reused everywhere below so cancel/
   reschedule/assign never miss a field again)
───────────────────────────────────────── */
const getUserById = async (id) => {
  if (!id) return null;
  const [[u]] = await db.query(
    `SELECT id, first_name, last_name, email, mobile, fcm_token
     FROM users WHERE id = ?`,
    [id]
  );
  return u || null;
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
   CARETAKER ALERTS (booking available to accept)
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
   ✅ NEW — CARETAKER ASSIGNMENT NOTIFICATIONS
   Fired when admin assigns/reassigns a caretaker to an
   order. Notifies BOTH the caretaker (they've been given
   a job) and the careseeker (who's coming to help them),
   by email + push.
───────────────────────────────────────── */

const sendCaretakerAssignmentNotifications = async ({ orderId, caretakerId }) => {
  try {
    const [[order]] = await db.query(
      `SELECT id, order_code, user_id, date, slot, category, total, location
       FROM orders WHERE id = ?`,
      [orderId]
    );

    if (!order) {
      console.log("ASSIGNMENT NOTIF: order not found", orderId);
      return;
    }

    const careseeker = await getUserById(order.user_id);
    const caretaker   = await getUserById(caretakerId);

    /* ── Notify the caretaker ── */
    if (caretaker?.fcm_token) {
      await sendPushNotification(
        caretaker.fcm_token,
        "🩺 New Booking Assigned",
        `${order.order_code} has been assigned to you`
      );
    }

    if (caretaker?.email) {
      await sendEmail({
        to: caretaker.email,
        subject: `🩺 New Booking Assigned - ${order.order_code}`,
        html: emailTemplate({
          title: "Booking Assigned",
          subtitle: "A new booking has been assigned to you",
          statusColor: "#2563eb",
          content: `
            <p>Hello <b>${caretaker.first_name}</b>,</p>
            <p>
              You have been assigned a new booking. Please open the
              Medico app for full patient details and be ready at the
              scheduled time.
            </p>
            ${orderTable({
              orderCode: order.order_code,
              serviceName: order.category,
              dateStr: order.date,
              slot: order.slot,
              location: order.location,
              total: order.total
            })}
          `
        })
      });
      console.log("ASSIGNMENT EMAIL SENT TO CARETAKER:", caretaker.email);
    }

    /* ── Notify the careseeker ── */
    if (careseeker?.fcm_token) {
      await sendPushNotification(
        careseeker.fcm_token,
        "🩺 Caretaker Assigned",
        `A caretaker has been assigned to ${order.order_code}`
      );
    }

    if (careseeker?.email) {
      await sendEmail({
        to: careseeker.email,
        subject: `🩺 Caretaker Assigned - ${order.order_code}`,
        html: emailTemplate({
          title: "Caretaker Assigned",
          subtitle: "Your booking now has a caretaker assigned",
          statusColor: "#2563eb",
          content: `
            <p>Hello <b>${careseeker.first_name}</b>,</p>
            <p>
              <b>${caretaker?.first_name || "A caretaker"}</b> has been
              assigned to your booking${caretaker?.mobile ? ` and can be reached at ${caretaker.mobile}` : ""}.
            </p>
            ${orderTable({
              orderCode: order.order_code,
              serviceName: order.category,
              dateStr: order.date,
              slot: order.slot
            })}
          `
        })
      });
      console.log("ASSIGNMENT EMAIL SENT TO CARESEEKER:", careseeker.email);
    }

  } catch (err) {
    console.log("ASSIGNMENT NOTIF ERROR:", err);
  }
};

/* ─────────────────────────────────────────
   CANCELLATION
   ✅ UPDATED — now looks up the order itself (instead of
   relying on the caller to pass every field), and notifies
   the caretaker too when one was assigned, not just the
   careseeker. Accepts either sendCancellationNotifications(orderId, reason)
   or the old sendCancellationNotifications(orderObjectWithIdAndReason)
   shape, so existing callers elsewhere in the codebase keep working.
───────────────────────────────────────── */

const sendCancellationNotifications = async (orderIdOrOrder, maybeReason) => {

  try {

    const orderId = typeof orderIdOrOrder === "object"
      ? (orderIdOrOrder.orderId ?? orderIdOrOrder.id ?? orderIdOrOrder.order_id)
      : orderIdOrOrder;

    const reason = maybeReason
      ?? (typeof orderIdOrOrder === "object"
            ? (orderIdOrOrder.reason ?? orderIdOrOrder.cancel_reason)
            : undefined);

    const [[order]] = await db.query(
      `SELECT id, order_code, user_id, caretaker_id, assigned_caretaker_id
       FROM orders WHERE id = ?`,
      [orderId]
    );

    if (!order) {
      console.log("CANCELLATION NOTIF: order not found", orderId);
      return;
    }

    const careseeker = await getUserById(order.user_id);
    const caretakerId = order.caretaker_id || order.assigned_caretaker_id;
    const caretaker   = caretakerId ? await getUserById(caretakerId) : null;

    /* ── Careseeker ── */
    if (careseeker?.fcm_token) {
      await sendPushNotification(
        careseeker.fcm_token,
        "❌ Booking Cancelled",
        `${order.order_code} has been cancelled`
      );
    }

    if (careseeker?.email) {
      await sendEmail({
        to: careseeker.email,
        subject: `❌ Booking Cancelled - ${order.order_code}`,
        html: emailTemplate({
          title: "Booking Cancelled",
          subtitle: "Your booking has been cancelled",
          statusColor: "#dc2626",
          content: `
            <p>Hello <b>${careseeker.first_name}</b>,</p>
            <p>
              Your booking has been cancelled${reason ? ` — <b>Reason:</b> ${reason}` : ""}.
            </p>
            ${orderTable({ orderCode: order.order_code })}
          `
        })
      });
    }

    /* ── Caretaker (only if one had been assigned) ── */
    if (caretaker?.fcm_token) {
      await sendPushNotification(
        caretaker.fcm_token,
        "❌ Booking Cancelled",
        `${order.order_code} has been cancelled by admin`
      );
    }

    if (caretaker?.email) {
      await sendEmail({
        to: caretaker.email,
        subject: `❌ Booking Cancelled - ${order.order_code}`,
        html: emailTemplate({
          title: "Booking Cancelled",
          subtitle: "A booking assigned to you has been cancelled",
          statusColor: "#dc2626",
          content: `
            <p>Hello <b>${caretaker.first_name}</b>,</p>
            <p>
              The booking <b>${order.order_code}</b> that was assigned to
              you has been cancelled${reason ? ` — <b>Reason:</b> ${reason}` : ""}.
              You no longer need to attend this appointment.
            </p>
            ${orderTable({ orderCode: order.order_code })}
          `
        })
      });
    }

  } catch (err) {

    console.log("CANCELLATION ERROR:", err);

  }

};

/* =====================================================
   RESCHEDULE CONFIRMATION EMAIL
   ✅ UPDATED — now also notifies the caretaker (email +
   push) when the order already has one assigned, in
   addition to the careseeker.
===================================================== */

const sendRescheduleConfirmation = async ({ user, order, newDate, newSlot, oldDate, oldSlot, caretaker }) => {

  const fmtDate = (d) =>
    d
      ? new Date(d).toLocaleDateString("en-IN", {
          day: "2-digit",
          month: "short",
          year: "numeric",
        })
      : "-";

  const orderCode = order.order_code || order.orderCode;

  const notifyOne = async (person, isCaretaker) => {
    if (!person?.email) {
      console.warn(`⚠️ Skipping reschedule email — no email on file for ${isCaretaker ? "caretaker" : "user"} ${person?.id || "unknown"}`);
    } else {
      const subject = `Booking Rescheduled — ${orderCode}`;
      const html = `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
          <h2 style="color:#0f766e;">${isCaretaker ? "A booking you're assigned to has been rescheduled" : "Your booking has been rescheduled"}</h2>
          <p>Hi ${person.first_name || "there"},</p>
          <p>${isCaretaker ? "The" : "Your"} Medico booking <strong>${orderCode}</strong> has been moved to a new date and time.</p>

          <table style="width:100%; border-collapse:collapse; margin:16px 0;">
            <tr>
              <td style="padding:8px; color:#94a3b8;">Previous</td>
              <td style="padding:8px; text-decoration:line-through; color:#94a3b8;">
                ${fmtDate(oldDate)}, ${oldSlot || "-"}
              </td>
            </tr>
            <tr>
              <td style="padding:8px; color:#0f766e; font-weight:bold;">New</td>
              <td style="padding:8px; color:#0f766e; font-weight:bold;">
                ${fmtDate(newDate)}, ${newSlot}
              </td>
            </tr>
          </table>

          <p>If you have any questions about this change, please contact our support team.</p>
          <p style="color:#94a3b8; font-size:12px; margin-top:24px;">— Team Medico</p>
        </div>
      `;

      try {
        await sendEmail({ to: person.email, subject, html });
        console.log(`✅ Reschedule email sent to ${person.email}`);
      } catch (err) {
        console.error("RESCHEDULE EMAIL ERROR:", err);
      }
    }

    if (person?.fcm_token) {
      await sendPushNotification(
        person.fcm_token,
        "📅 Booking Rescheduled",
        `${orderCode} moved to ${fmtDate(newDate)}, ${newSlot}`
      );
    }
  };

  await notifyOne(user, false);
  if (caretaker) await notifyOne(caretaker, true);
};


module.exports = {
  sendBookingConfirmedToUser,
  sendBookingAlertToCaretakers,
  sendCancellationNotifications,
  sendRescheduleConfirmation,
  sendCaretakerAssignmentNotifications,
};