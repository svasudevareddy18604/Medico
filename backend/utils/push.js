const admin = require("../utils/firebase");

const sendPushNotification = async (
  fcmToken,
  title,
  body,
  imageUrl = null
) => {
  try {
    if (!fcmToken) {
      console.log("❌ FCM token missing");
      return;
    }

    const message = {
      token: fcmToken,

      notification: {
        title: title,
        body: body,
        ...(imageUrl ? { image: imageUrl } : {}),
      },

      android: {
        priority: "high",
        notification: {
          title: title,
          body: body,
          ...(imageUrl ? { imageUrl: imageUrl } : {}),
          channelId: "high_importance_channel",
        },
      },

      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            "mutable-content": 1,
          },
        },
        fcm_options: imageUrl
          ? {
              image: imageUrl,
            }
          : {},
      },

      data: imageUrl
        ? {
            image: imageUrl,
          }
        : {},
    };

    console.log("========== FCM PAYLOAD ==========");
    console.log(JSON.stringify(message, null, 2));
    console.log("=================================");

    const response = await admin.messaging().send(message);

    console.log("✅ Notification sent successfully");
    console.log(response);
  } catch (err) {
    console.error("❌ Push notification error");
    console.error(err);
  }
};

module.exports = {
  sendPushNotification,
};