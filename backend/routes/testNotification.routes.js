const express = require("express");
const router = express.Router();

const { sendPushNotification } = require("../services/pushNotification.service");

/*
  TEST API
  Send notification manually
*/

router.get("/test-notification", async (req, res) => {

  try {

    const fcmToken = req.query.token;

    if (!fcmToken) {
      return res.status(400).json({
        message: "FCM token required"
      });
    }

    await sendPushNotification(
      fcmToken,
      "Test Notification",
      "Firebase push notification working"
    );

    res.json({
      success: true,
      message: "Notification sent"
    });

  } catch (error) {

    console.error(error);

    res.status(500).json({
      success: false,
      message: "Notification failed"
    });

  }

});

module.exports = router;