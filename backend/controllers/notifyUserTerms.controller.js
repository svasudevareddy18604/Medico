const { sendTermsUpdateNotifications } = require("../services/termsNotification.service");

const VALID_AUDIENCES = ["both", "careseekers", "caretakers"];

const notifyTermsUpdate = async (req, res) => {
  try {
    const { audience } = req.body;

    if (!audience || !VALID_AUDIENCES.includes(audience)) {
      return res.status(400).json({
        success: false,
        message: "Invalid audience. Must be 'both', 'careseekers', or 'caretakers'."
      });
    }

    const result = await sendTermsUpdateNotifications(audience);

    return res.status(200).json({
      success: true,
      message: "Terms & Conditions update notification sent",
      audience,
      ...result
    });
  } catch (err) {
    console.log("NOTIFY TERMS UPDATE ERROR:", err);
    return res.status(500).json({
      success: false,
      message: "Failed to send Terms & Conditions notifications"
    });
  }
};

module.exports = {
  notifyTermsUpdate
};