const express = require("express");
const cors = require("cors");
const path = require("path");
const fs = require("fs");
require("dotenv").config();

const http = require("http");
const { Server } = require("socket.io");

const authRoutes = require("./routes/auth.routes");
const forgotPasswordRoutes = require("./routes/forgotpassword.routes");
const userRoutes = require("./routes/users.routes");
const addressRoutes = require("./routes/address.routes");

const locationCheckRoutes = require("./routes/locationCheck.routes");
const servicesRoutes = require("./routes/services.routes");
const nearbyCaretakersRoutes = require("./routes/nearbyCaretakers.routes");
const feedbackRoutes = require("./routes/careseekerfeedback.routes");

const cartRoutes = require("./routes/cart.routes");
const slotRoutes = require("./routes/slots.routes");
const orderRoutes = require("./routes/orders.routes");
const paymentRoutes = require("./routes/payment.routes");
const documentRoutes = require("./routes/document.routes");
const careSeekerOrderDetails = require("./routes/careseekerorderdetails.routes");

const careseekerCouponRoutes = require("./routes/careseekercoupon.routes");

const adminRoutes = require("./routes/admin.routes");
const adminProfileRoutes = require("./routes/adminprofile.routes");
const adminUsersRoutes = require("./routes/adminUsers.routes");
const adminOrdersRoutes = require("./routes/adminOrders.routes");
const adminServicesRoutes = require("./routes/admin_services.routes");
const adminLocationRoutes = require("./routes/adminlocationset.routes");
const adminWithdrawRoutes = require("./routes/adminwithdraw.routes");
const adminSettingsRoutes = require("./routes/admin_settings.routes");
const adminCaregiversRoutes = require("./routes/admin_caregivers.routes");
const adminCouponRoutes = require("./routes/admincoupon.routes");
const adminPromotionRoutes = require("./routes/adminpromotions.routes");
const adminNotificationRoutes = require("./routes/adminnotification.routes");
const serviceChargesRoutes = require("./routes/adminServiceCharges.routes");
const adminCareSeekerDetailsRoutes = require("./routes/admincareseeker_details.routes");

const caretakerRoutes = require("./routes/caretaker.routes");
const caretakerDocsRoutes = require("./routes/caretaker_documents.routes");
const caretakerLocationRoutes = require("./routes/caretakerLocation.routes");
const caretakerTasksRoutes = require("./routes/caretakerTasks.routes");
const caretakerProfileRoutes = require("./routes/caretakerprofile.routes");
const caretakerPaymentRoutes = require("./routes/caretakerpayment.routes");
const caretakerPaymentDetailsRoutes = require("./routes/caretakerpaymentdetails.routes");
const caretakerPerformanceRoutes = require("./routes/performance.routes");
const earningsRoutes = require("./routes/earnings.routes");
const withdrawalRoutes = require("./routes/withdrawal.routes");

const chatRoutes = require("./routes/chat.routes");
const testNotificationRoutes = require("./routes/testNotification.routes");

const chatSocket = require("./sockets/chat.socket");

const app = express();
const server = http.createServer(app);

/* =========================================
   SOCKET IO
========================================= */

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
  transports: ["websocket"],
});

chatSocket(io);

/* =========================================
   MIDDLEWARE
========================================= */

app.use(cors());

app.use(
  express.json({
    limit: "10mb",
  })
);

app.use(
  express.urlencoded({
    extended: true,
    limit: "10mb",
  })
);

/* =========================================
   UPLOAD FOLDER
========================================= */

const uploadDir = path.join(__dirname, "uploads/profile");

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, {
    recursive: true,
  });
}

/* =========================================
   STATIC FILES
========================================= */

app.use(
  "/uploads",
  express.static(path.join(__dirname, "uploads"), {
    maxAge: "1d",

    setHeaders: (res) => {
      res.set("Access-Control-Allow-Origin", "*");
    },
  })
);

/* =========================================
   REQUEST LOGGER
========================================= */

app.use((req, res, next) => {
  console.log("👉", req.method, req.originalUrl);
  next();
});

/* =========================================
   AUTH
========================================= */

app.use("/api", authRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/auth", forgotPasswordRoutes);

/* =========================================
   USERS
========================================= */

app.use("/api/users", userRoutes);
app.use("/api/addresses", addressRoutes);

/* =========================================
   GENERAL
========================================= */

app.use("/api", locationCheckRoutes);
app.use("/api/services", servicesRoutes);
app.use("/api/feedback", feedbackRoutes);

/* =========================================
   CARETAKERS
========================================= */

app.use("/api/caretakers", nearbyCaretakersRoutes);

/* =========================================
   CART / ORDER
========================================= */

app.use("/api/cart", cartRoutes);

app.use("/api/slots", slotRoutes);

app.use("/api/orders", orderRoutes);

app.use("/api/documents", documentRoutes);

app.use("/api/careseeker/order", careSeekerOrderDetails);

/* =========================================
   PAYMENT
========================================= */

app.use("/api/payment", paymentRoutes);

/* =========================================
   COUPONS
========================================= */

app.use(
  "/api/careseeker/coupons",
  careseekerCouponRoutes
);

/* =========================================
   CARETAKER
========================================= */

app.use("/api/caretaker", caretakerRoutes);

app.use(
  "/api/caretaker/documents",
  caretakerDocsRoutes
);

app.use(
  "/api/caretaker/location",
  caretakerLocationRoutes
);

app.use(
  "/api/caretaker/tasks",
  caretakerTasksRoutes
);

app.use(
  "/api/caretaker/profile",
  caretakerProfileRoutes
);

app.use(
  "/api/caretaker/payment",
  caretakerPaymentRoutes
);

app.use(
  "/api/caretaker/payment-details",
  caretakerPaymentDetailsRoutes
);

app.use(
  "/api/caretaker/performance",
  caretakerPerformanceRoutes
);

app.use("/api/earnings", earningsRoutes);

app.use("/api/withdrawals", withdrawalRoutes);

/* =========================================
   ADMIN
========================================= */

app.use("/api/admin", adminRoutes);

app.use("/api/admin", adminProfileRoutes);

app.use("/api/admin/users", adminUsersRoutes);

app.use("/api/admin/orders", adminOrdersRoutes);

app.use("/api/admin/services", adminServicesRoutes);

app.use(
  "/api/admin/service-charges",
  serviceChargesRoutes
);

app.use(
  "/api/admin/withdraw",
  adminWithdrawRoutes
);

app.use(
  "/api/admin/settings",
  adminSettingsRoutes
);

app.use(
  "/api/admin/caregivers",
  adminCaregiversRoutes
);

app.use(
  "/api/admin/coupons",
  adminCouponRoutes
);

app.use(
  "/api/admin/promotions",
  adminPromotionRoutes
);

app.use(
  "/api/admin/notifications",
  adminNotificationRoutes
);

app.use(
  "/api/admin/careseeker",
  adminCareSeekerDetailsRoutes
);

app.use("/api", adminLocationRoutes);

/* =========================================
   OTHER
========================================= */

app.use("/api", testNotificationRoutes);

app.use("/api/chat", chatRoutes);

/* =========================================
   ROOT
========================================= */

app.get("/", (req, res) => {
  return res.json({
    success: true,
    message: "Medico Backend Running",
    time: new Date(),
  });
});

/* =========================================
   404
========================================= */

app.use((req, res) => {
  return res.status(404).json({
    success: false,
    message: "API route not found",
  });
});

/* =========================================
   ERROR HANDLER
========================================= */

app.use((err, req, res, next) => {
  console.error("🔥 ERROR:", err.message);

  return res.status(500).json({
    success: false,
    message: err.message || "Server error",
  });
});

/* =========================================
   SERVER START
========================================= */

const PORT = process.env.PORT || 3000;

server.listen(PORT, "0.0.0.0", () => {
  console.log("==================================");
  console.log("🚀 Server Running");
  console.log(`🌍 http://localhost:${PORT}`);
  console.log("💬 Socket Ready");
  console.log("==================================");
});