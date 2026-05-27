const SibApiV3Sdk = require('sib-api-v3-sdk');

const client = SibApiV3Sdk.ApiClient.instance;
const apiKey = client.authentications['api-key'];
apiKey.apiKey = process.env.BREVO_API_KEY;

const apiInstance = new SibApiV3Sdk.TransactionalEmailsApi();

const sendEmail = async ({ to, subject, html }) => {
  try {
    await apiInstance.sendTransacEmail({
      sender: { email: "svasu18604@gmail.com" }, // temp sender
      to: [{ email: to }],
      subject: subject,
      htmlContent: html,
      textContent: `Medico OTP: ${html.replace(/<[^>]*>?/gm, '').slice(0, 200)}`
    });

    console.log("✅ Email sent");
  } catch (err) {
    console.error("❌ Email error:", err.response?.body || err.message);
  }
};

module.exports = sendEmail;