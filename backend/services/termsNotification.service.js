const db = require("../config/db");
const sendEmail = require("../config/mailer");
const { sendPushNotification } = require("./pushNotification.service");

/* ─────────────────────────────────────────
   PROFESSIONAL EMAIL TEMPLATE
───────────────────────────────────────── */

const emailTemplate = ({ title, subtitle, content, statusColor = "#4f46e5" }) => {
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

            <tr>
              <td style="
                background:${statusColor};
                padding:35px 25px;
                text-align:center;
              ">
                <h1 style="color:white;margin:0;font-size:28px;">Medico</h1>
                <p style="color:#e5e7eb;margin-top:10px;font-size:15px;">${subtitle}</p>
              </td>
            </tr>

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

            <tr>
              <td style="
                background:#f9fafb;
                padding:20px;
                text-align:center;
                border-top:1px solid #e5e7eb;
              ">
                <p style="margin:0;color:#6b7280;font-size:13px;">
                  © ${new Date().getFullYear()} Medico
                </p>
                <p style="margin-top:8px;color:#9ca3af;font-size:12px;">
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
   FETCH USERS BY AUDIENCE
   Confirmed role values from users table:
   'care_seeker' and 'care_taker'
───────────────────────────────────────── */

const getUsersByAudience = async (audience) => {
  let roles = [];

  if (audience === "careseekers") roles = ["care_seeker"];
  else if (audience === "caretakers") roles = ["care_taker"];
  else roles = ["care_seeker", "care_taker"]; // both

  const placeholders = roles.map(() => "?").join(",");

  const [rows] = await db.query(
    `SELECT id, first_name, email, fcm_token, role
     FROM users
     WHERE role IN (${placeholders})
     AND is_deleted = 0
     AND is_blocked = 0`,
    roles
  );

  return rows;
};

/* ─────────────────────────────────────────
   SEND TERMS UPDATE NOTIFICATIONS
───────────────────────────────────────── */

const sendTermsUpdateNotifications = async (audience) => {
  const users = await getUsersByAudience(audience);

  let emailSent = 0;
  let pushSent = 0;
  const failed = [];

  console.log(`TERMS UPDATE → notifying ${users.length} users (audience: ${audience})`);

  for (const u of users) {
    try {
      if (u.fcm_token) {
        await sendPushNotification(
          u.fcm_token,
          "📋 Terms & Conditions Updated",
          "We've updated our Terms & Conditions. Tap to review the changes."
        );
        pushSent++;
      }

      if (u.email) {
        await sendEmail({
          to: u.email,

          subject: "📋 Terms & Conditions Updated - Medico",

          html: emailTemplate({
            title: "Terms & Conditions Updated",
            subtitle: "Please review our updated policies",
            statusColor: "#4f46e5",

            content: `
              <p>Hello <b>${u.first_name || "there"}</b>,</p>

              <p>
                We've made updates to our Terms & Conditions to keep you
                informed about how Medico's services work and how your
                information is handled.
              </p>

              <p>
                We recommend reviewing the updated terms at your earliest
                convenience. Continued use of Medico after this notice
                means you accept the revised terms.
              </p>

              <p style="margin-top:25px;color:#374151;">
                Thank you for being a part of the Medico community.
              </p>
            `,
          }),
        });

        emailSent++;
      }
    } catch (err) {
      console.log("TERMS NOTIFY - USER ERROR:", u.email || u.id, err.message);
      failed.push(u.email || u.id);
    }
  }

  return {
    totalUsers: users.length,
    emailSent,
    pushSent,
    failed,
  };
};

module.exports = {
  sendTermsUpdateNotifications,
};