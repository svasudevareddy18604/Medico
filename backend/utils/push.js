const admin = require("../utils/firebase");

/*
  Send push notification
*/
const sendPushNotification = async (fcmToken, title, body) => {
  try {
    if (!fcmToken) {
      console.log("FCM token missing");
      return;
    }

    const message = {
      notification: {
        title,
        body,
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);

    console.log("🔔 Notification sent:", response);

  } catch (error) {
    console.error("❌ Push error:", error);
  }
};

module.exports = {
  sendPushNotification,
};