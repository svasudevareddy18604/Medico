const db = require("../config/db");
const { sendPushNotification } = require("../utils/push");

module.exports = (io) => {

  io.on("connection", (socket) => {
    console.log("🟢 Connected:", socket.id);

    /* =========================
       JOIN ROOM
    ========================= */
    socket.on("joinRoom", ({ userId }) => {
      if (!userId) return;

      const room = `support_${userId}`;
      socket.join(room);

      console.log(`✅ Joined room: ${room}`);
    });

    /* =========================
       SEND MESSAGE (MAIN LOGIC)
    ========================= */
    socket.on("sendMessage", async (data) => {
      try {
        const { userId, message, sender } = data;

        if (!userId || !message || !sender) {
          console.log("❌ Invalid message data");
          return;
        }

        const room = `support_${userId}`;

        console.log("📩 Message received:", data);

        /* =========================
           ✅ SAVE TO DATABASE
        ========================= */
        await db.query(
          "INSERT INTO support_messages (user_id, sender, message) VALUES (?, ?, ?)",
          [userId, sender, message]
        );

        /* =========================
           ✅ REALTIME SEND
        ========================= */
        const payload = {
          userId,
          message,
          sender,
          created_at: new Date(),
        };

        io.to(room).emit("receiveMessage", payload);

        /* =========================
           🔔 PUSH NOTIFICATIONS
        ========================= */

        if (sender === "user") {
          // USER → ADMIN (from users table)

          const [admins] = await db.query(
            "SELECT fcm_token FROM users WHERE role = 'admin' AND fcm_token IS NOT NULL"
          );

          for (const admin of admins) {
            if (admin.fcm_token) {
              await sendPushNotification(
                admin.fcm_token,
                "New Support Message",
                message
              );
            }
          }

        } else {
          // ADMIN → USER

          const [rows] = await db.query(
            "SELECT fcm_token FROM users WHERE id = ?",
            [userId]
          );

          const userToken = rows[0]?.fcm_token;

          if (userToken) {
            await sendPushNotification(
              userToken,
              "Support Reply",
              message
            );
          }
        }

      } catch (err) {
        console.error("❌ Chat error:", err);
      }
    });

    /* =========================
       DISCONNECT
    ========================= */
    socket.on("disconnect", () => {
      console.log("🔴 Disconnected:", socket.id);
    });

  });

};