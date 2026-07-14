const admin = require("../utils/firebase");

const sendPushNotification = async (
  fcmToken,
  title,
  body,
  imageUrl = null
) => {
  try {
    if (!fcmToken) return;

    const message = {
      token: fcmToken,

      notification: {
        title,
        body,
        ...(imageUrl ? { image: imageUrl } : {})
      },

      android: {
        notification: {
          ...(imageUrl ? { imageUrl } : {})
        }
      },

      apns: {
        payload: {
          aps: {
            "mutable-content": 1
          }
        },
        fcm_options: imageUrl
          ? {
              image: imageUrl
            }
          : undefined
      }
    };

    const response = await admin.messaging().send(message);

    console.log("Notification sent:", response);
  } catch (err) {
    console.error(err);
  }
};

module.exports = { sendPushNotification };