const admin = require("../utils/firebase");
const db = require("../config/db"); // ⚠️ adjust path if needed

/*
  Send push notification to a single device
*/
const sendPushNotification = async (fcmToken, title, body) => {
  try {

    // 🔴 STRICT VALIDATION
    if (!fcmToken || fcmToken.length < 20) {
      console.log("⚠️ Invalid FCM token skipped:", fcmToken);
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
    console.log("Push notification sent:", response);

  } catch (error) {

    // 🔥 MAIN FIX
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log("❌ Removing invalid token:", fcmToken);

      try {
        await db.query(
          "UPDATE users SET fcm_token = NULL WHERE fcm_token = ?",
          [fcmToken]
        );
      } catch (dbErr) {
        console.error("DB error while removing token:", dbErr);
      }
    }

    console.error("Push notification error:", error);
  }
};


/*
  Send push notification with extra data
*/
const sendPushWithData = async (fcmToken, title, body, data = {}) => {
  try {

    if (!fcmToken || fcmToken.length < 20) {
      console.log("⚠️ Invalid FCM token skipped:", fcmToken);
      return;
    }

    const message = {
      notification: {
        title,
        body,
      },
      data,
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);
    console.log("Push notification sent with data:", response);

  } catch (error) {

    // 🔥 SAME FIX HERE ALSO
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log("❌ Removing invalid token:", fcmToken);

      try {
        await db.query(
          "UPDATE users SET fcm_token = NULL WHERE fcm_token = ?",
          [fcmToken]
        );
      } catch (dbErr) {
        console.error("DB error while removing token:", dbErr);
      }
    }

    console.error("Push notification error:", error);
  }
};

/* =====================================================
   RESCHEDULE PUSH NOTIFICATION
===================================================== */

const sendReschedulePush = async ({ fcmToken, orderCode, newDate, newSlot }) => {
  const fmtDate = (d) =>
    d
      ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })
      : "-";

  await sendPushNotification(
    fcmToken,
    "📅 Booking Rescheduled",
    `${orderCode} moved to ${fmtDate(newDate)}, ${newSlot}`
  );
};


module.exports = {
  sendPushNotification,
  sendPushWithData,
  sendReschedulePush,
};