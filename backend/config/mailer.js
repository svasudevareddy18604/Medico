const SibApiV3Sdk = require('sib-api-v3-sdk');

const client = SibApiV3Sdk.ApiClient.instance;
const apiKey = client.authentications['api-key'];
apiKey.apiKey = process.env.BREVO_API_KEY;

const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();

const sendEmail = async ({ to, subject, html }) => {
  if (!to) {
    console.error("❌ Email Error: no recipient email provided");
    return;
  }

  try {
    const result = await apiInstance.sendTransacEmail({
      sender: { email: "svasu18604@gmail.com" }, // temp sender
      to: [{ email: to }],
      subject: subject,
      htmlContent: html,
      textContent: `Medico OTP: ${html.replace(/<[^>]*>?/gm, '').slice(0, 200)}`
    });

    console.log("✅ Email sent to", to, "| messageId:", result?.messageId);
  } catch (err) {
    console.error(
      "❌ Email error to:", to,
      "| status:", err?.status,
      "| body:", err?.response?.body,
      "| text:", err?.response?.text,
      "| message:", err?.message
    );
  }
};

module.exports = sendEmail;