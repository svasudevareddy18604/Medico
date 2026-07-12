const db = require("../config/db");
const sendEmail = require("../config/mailer");
const { sendPushNotification } = require("./pushNotification.service");

/* ─────────────────────────────────────────
   PROFESSIONAL EMAIL TEMPLATE
   Compact, scannable, easy to read in seconds
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
    font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;
  ">

    <table width="100%" cellpadding="0" cellspacing="0" style="
      background:#f3f4f6;
      padding:24px 12px;
    ">

      <tr>
        <td align="center">

          <table width="100%" cellpadding="0" cellspacing="0" style="
            max-width:480px;
            background:#ffffff;
            border-radius:14px;
            overflow:hidden;
            box-shadow:0 2px 10px rgba(0,0,0,0.06);
          ">

            <!-- HEADER -->
            <tr>
              <td style="
                background:${statusColor};
                padding:24px 24px;
                text-align:center;
              ">
                <p style="
                  color:#ffffff;
                  margin:0;
                  font-size:17px;
                  font-weight:700;
                  letter-spacing:0.3px;
                ">
                  Medico
                </p>
                <p style="
                  color:rgba(255,255,255,0.85);
                  margin:6px 0 0;
                  font-size:12.5px;
                  font-weight:400;
                ">
                  ${subtitle}
                </p>
              </td>
            </tr>

            <!-- BODY -->
            <tr>
              <td style="
                padding:22px 24px 24px;
                color:#1f2937;
                font-size:13px;
                line-height:1.55;
              ">
                ${content}
              </td>
            </tr>

            <!-- FOOTER -->
            <tr>
              <td style="
                background:#f9fafb;
                padding:14px 24px;
                text-align:center;
                border-top:1px solid #eef0f2;
              ">
                <p style="
                  margin:0;
                  color:#9ca3af;
                  font-size:10.5px;
                ">
                  © ${new Date().getFullYear()} Medico · Professional Home Healthcare Services
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

          subject: "Update to Medico's Terms & Conditions",

          html: emailTemplate({
            title: "Terms & Conditions Updated",
            subtitle: "A quick update on our policies",
            statusColor: "#4f46e5",

            content: `
              <p style="margin:0 0 12px;">
                Hi <b>${u.first_name || "there"}</b>,
              </p>

              <p style="margin:0 0 14px;">
                We've updated our <b>Terms & Conditions</b>. Here's what you need to know:
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px;">
                <tr>
                  <td style="padding:6px 0; font-size:13px; vertical-align:top; width:20px;">•</td>
                  <td style="padding:6px 0; font-size:13px; color:#374151;">
                    Reflects the latest changes to how our services work
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0; font-size:13px; vertical-align:top;">•</td>
                  <td style="padding:6px 0; font-size:13px; color:#374151;">
                    Clarifies how your information is used and protected
                  </td>
                </tr>
                <tr>
                  <td style="padding:6px 0; font-size:13px; vertical-align:top;">•</td>
                  <td style="padding:6px 0; font-size:13px; color:#374151;">
                    Takes effect immediately
                  </td>
                </tr>
              </table>

              <p style="
                margin:0 0 16px;
                padding:10px 12px;
                background:#f5f5fb;
                border-left:3px solid #4f46e5;
                border-radius:6px;
                font-size:12px;
                color:#4b5563;
              ">
                Continuing to use Medico after this notice means you accept the revised terms.
              </p>

              <p style="margin:0; font-size:12.5px; color:#6b7280;">
                Thanks for being part of Medico.
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