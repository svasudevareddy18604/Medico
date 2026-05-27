class Api {
  static const String baseUrl   = "https://medico-3vyh.onrender.com/api";
  static const String imageBase = "https://medico-3vyh.onrender.com";

  static const String login    = "$baseUrl/auth/login";
  static const String register = "$baseUrl/auth/register";

  static const String users       = "$baseUrl/users";
  static const String userProfile = "$baseUrl/users/profile";

  static const String addresses = "$baseUrl/addresses";
  static String getUserAddresses(int userId) => "$baseUrl/addresses/$userId";

  static const String caretakerLocation = "$baseUrl/caretaker/location";
  static String getCaretakerLocation(int caretakerId) => "$baseUrl/caretaker/location/$caretakerId";

  static const String caretakerOnboarding      = "$baseUrl/caretaker/onboarding";
  static const String caretakerUploadDocuments = "$baseUrl/caretaker/documents/upload-documents";
  static const String caretakerProfile         = "$baseUrl/caretaker/profile";
  static String uploadCaretakerProfile(int id) => "$baseUrl/caretaker/profile/upload/$id";
  static String caretakerStatus(int userId)    => "$baseUrl/caretaker/status/$userId";

  static const String availableJobs = "$baseUrl/caretaker/orders";
  static const String acceptJob     = "$baseUrl/caretaker/accept";
  static const String startJob      = "$baseUrl/caretaker/start";
  static const String completeJob   = "$baseUrl/caretaker/complete";
  static const String rejectJob     = "$baseUrl/caretaker/reject-order";
  static String myJobs(int caretakerId)            => "$baseUrl/caretaker/my-jobs/$caretakerId";
  static String caretakerOrderDetails(int orderId) => "$baseUrl/caretaker/order-detail/$orderId";

  static const String markPaymentReceived = "$baseUrl/caretaker/payment/mark-received";
  static const String confirmPayment      = "$baseUrl/caretaker/payment/confirm";
  static const String completeOrder       = "$baseUrl/caretaker/payment/complete";
  static String caretakerPaymentDetails(int orderId) => "$baseUrl/caretaker/payment/$orderId";

  /* ================= DOCUMENTS ================= */

  static const String uploadDocuments = "$baseUrl/documents/upload";
  static String orderDocuments(int orderId)                        => "$baseUrl/documents/order/$orderId";
  static String pendingDocuments(int userId, int serviceId)        => "$baseUrl/documents/pending/$userId/$serviceId";

  /* ================= SERVICES ================= */

  static const String services      = "$baseUrl/services";
  static const String adminServices = "$baseUrl/admin/services";

  static const String getServiceCharges    = "$baseUrl/admin/service-charges";
  static const String updateServiceCharges = "$baseUrl/admin/service-charges";
  static String deleteServiceCharge(int id) => "$baseUrl/admin/service-charges/$id";

  /* ================= CART ================= */

  static const String cart           = "$baseUrl/cart";
  static const String addToCart      = "$baseUrl/cart/add";
  static const String removeFromCart = "$baseUrl/cart/remove";

  /* ================= SLOTS ================= */

  static const String slots      = "$baseUrl/slots";
  static const String adminSlots = "$baseUrl/admin/slots";

  /* ================= ORDERS ================= */

  static const String orders     = "$baseUrl/orders";
  static const String placeOrder = "$baseUrl/orders/place";
  static const String userOrders = "$baseUrl/orders/user";
  static String orderDetails(int orderId) => "$baseUrl/careseeker/order/$orderId";
  static String cancelOrder(int orderId)  => "$baseUrl/orders/$orderId/cancel";

  /* ================= PAYMENTS ================= */

  static const String createOrder     = "$baseUrl/payment/create-order";
  static const String verifyPayment   = "$baseUrl/payment/verify";
  static const String codNotification = "$baseUrl/payment/cod-notification";

  /* ================= ADMIN ORDERS ================= */

  static const String adminOrders = "$baseUrl/admin/orders";
  static String adminOrderDetails(int id)   => "$baseUrl/admin/orders/$id";
  static String updateOrderStatus(int id)   => "$baseUrl/admin/orders/status/$id";
  static String updatePaymentStatus(int id) => "$baseUrl/admin/orders/payment/$id";
  static String refundOrder(int id)         => "$baseUrl/admin/orders/refund/$id";

  /* ================= ADMIN USERS ================= */

  static const String adminCareSeekers  = "$baseUrl/admin/users/care-seekers";
  static String blockUser(int id)       => "$baseUrl/admin/users/block/$id";
  static String careSeekerDetails(int id) => "$baseUrl/admin/careseeker/$id/details";

  /* ================= ADMIN CAREGIVERS ================= */

  static const String adminCaregivers    = "$baseUrl/admin/caregivers";
  static String caregiverDetails(int id) => "$baseUrl/admin/caregivers/$id";
  static String approveCaregiver(int id) => "$baseUrl/admin/caregivers/approve/$id";
  static String rejectCaregiver(int id)  => "$baseUrl/admin/caregivers/reject/$id";
  static String blockCaregiver(id)       => "$baseUrl/admin/caregivers/block/$id";
  static String unblockCaregiver(id)     => "$baseUrl/admin/caregivers/unblock/$id";

  /* ================= ADMIN SETTINGS ================= */

  static const String setRadius = "$baseUrl/admin/settings/radius";
  static const String getRadius = "$baseUrl/admin/settings/radius";

  /* ================= ADMIN NOTIFICATIONS ================= */

  static const String adminNotifications   = "$baseUrl/admin/notifications";
  static String updateNotification(int id) => "$baseUrl/admin/notifications/$id";
  static String deleteNotification(int id) => "$baseUrl/admin/notifications/$id";

  /* ================= PROMOTIONS ================= */

  static const String adminPromotions   = "$baseUrl/admin/promotions";
  static String updatePromotion(int id) => "$baseUrl/admin/promotions/$id";
  static String deletePromotion(int id) => "$baseUrl/admin/promotions/$id";

  /* ================= COUPONS ================= */

  static const String adminCoupons         = "$baseUrl/admin/coupons";
  static String updateCoupon(int id)       => "$baseUrl/admin/coupons/$id";
  static String deleteCoupon(int id)       => "$baseUrl/admin/coupons/$id";
  static String toggleCouponStatus(int id) => "$baseUrl/admin/coupons/$id/status";

  /* ================= FEEDBACK ================= */

  static const String submitFeedback         = "$baseUrl/feedback";
  static String getCaregiverFeedback(int id) => "$baseUrl/feedback/$id";
  static String caregiverRating(int id)      => "$baseUrl/feedback/summary/$id";

  /* ================= EARNINGS ================= */

  static String earnings(int caretakerId)        => "$baseUrl/earnings/$caretakerId";
  static String earningsHistory(int caretakerId) => "$baseUrl/earnings/history/$caretakerId";
  static const String withdraw                   = "$baseUrl/withdrawals";

  /* ================= CARETAKERS ================= */

  static String nearbyCaretakers(int userId)                       => "$baseUrl/caretakers/$userId";
  static String caretakerAvailability(int userId, String category) => "$baseUrl/caretakers/$userId/availability/$category";

  /* ================= LIVE CHAT ================= */

  static const String supportMessages    = "$baseUrl/chat";
  static String supportChat(int userId)  => "$baseUrl/chat/$userId";
  static const String sendSupportMessage = "$baseUrl/chat/send";
  static String markSupportRead(int userId)  => "$baseUrl/chat/admin/read/$userId";
  static String supportUnread(int userId)    => "$baseUrl/chat/admin/unread/$userId";


  
}