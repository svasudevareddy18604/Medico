import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import '../../config/api.dart';
import 'processing_screen.dart';
import 'package:intl/intl.dart';

class PaymentScreen extends StatefulWidget {
  final int userId;
  final String date, slot, location;
  final double subtotal, serviceCharge, discount;
  final String couponCode;
  final List<dynamic> cartItems;
  final double? latitude, longitude;

  const PaymentScreen({
    super.key,
    required this.userId,
    required this.date,
    required this.slot,
    required this.location,
    required this.cartItems,
    required this.subtotal,
    this.serviceCharge = 0.0,
    this.discount = 0.0,
    this.couponCode = "",
    this.latitude,
    this.longitude,
  });

  double get total =>
      (subtotal + serviceCharge - discount).clamp(0.0, double.infinity);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _method;
  bool _processing = false;

  bool get isDark => themeNotifier.value == ThemeMode.dark;
  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  String _to24Hour(String time) {
    final dt = DateFormat("h:mm a")
        .parse(time.trim().replaceAll(RegExp(r'\s+'), ' '));
    return DateFormat("HH:mm:ss").format(dt);
  }

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    super.dispose();
  }

  /* =====================================================
     PLACE ORDER
  ===================================================== */

  Future<Map<String, dynamic>?> _placeOrder({
    required String method,
    String paymentId = "",
  }) async {
    try {
      final res = await http.post(
        Uri.parse(Api.placeOrder),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "location": widget.location,
          "date": widget.date,
          "slot": _to24Hour(widget.slot),
          "total": widget.total,
          "subtotal": widget.subtotal,
          "service_charge": widget.serviceCharge,
          "discount": widget.discount,
          "payment_method": method,
          "payment_id": paymentId,
          "latitude": widget.latitude,
          "longitude": widget.longitude,
          "items": widget.cartItems
              .map((e) => {
                    "service_id": e["service_id"] ?? e["id"],
                    "quantity": e["quantity"] ?? 1,
                    "price": e["price"] ?? 0,
                    "category":
                        (e["category"] ?? "").toString().trim(),
                  })
              .toList(),
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["success"] != true) return null;
      if (data["orders"] is List &&
          (data["orders"] as List).isNotEmpty) {
        final first =
            (data["orders"] as List).first as Map<String, dynamic>;
        data["order_id"] ??= first["order_id"] ?? first["id"];
        data["order_code"] ??= first["order_code"];
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  /* =====================================================
     CLEAR CART
  ===================================================== */

  Future<void> _clearCart() async {
    try {
      await http.delete(
          Uri.parse("${Api.baseUrl}/cart/${widget.userId}/clear"));
    } catch (_) {}
  }

  /* =====================================================
     COD FLOW
  ===================================================== */

  Future<void> _handleCOD() async {
    if (_processing) return;
    setState(() => _processing = true);

    final apiFuture =
        _placeOrder(method: "COD").then((result) async {
      if (result == null) return null;
      final id = result["order_id"];
      if (id != null) {
        http
            .post(
              Uri.parse(Api.codNotification),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"order_id": id}),
            )
            .catchError((_) {});
      }
      await _clearCart();
      return result;
    });

    setState(() => _processing = false);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          isCOD: true,
          apiFuture: apiFuture,
          userId: widget.userId,
          subtotal: widget.subtotal,
          serviceCharge: widget.serviceCharge,
          discount: widget.discount,
          total: widget.total,
        ),
      ),
    );
  }

  /* =====================================================
     CASHFREE HOSTED CHECKOUT FLOW
  ===================================================== */

  Future<void> _startCashfree() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      // Step 1 — place order on backend
      final orderResult = await _placeOrder(method: "ONLINE");

      if (orderResult == null) {
        _snack("Order creation failed");
        setState(() => _processing = false);
        return;
      }

      // Step 2 — create Cashfree payment session
      final paymentRes = await http.post(
        Uri.parse(Api.createOrder),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": widget.total,
          "customer_id": widget.userId.toString(),
          "customer_name": "Medico User",
          "customer_email": "user@test.com",
          "customer_phone": "9999999999",
        }),
      );

      final paymentData = jsonDecode(paymentRes.body);

      if (paymentData["success"] != true) {
        _snack("Payment initialization failed");
        setState(() => _processing = false);
        return;
      }

      // Step 3 — open Cashfree hosted checkout in browser
      final sessionId = paymentData["payment_session_id"];
      final paymentUrl =
          "https://payments.cashfree.com/order/#$sessionId";

      await launchUrl(
        Uri.parse(paymentUrl),
        mode: LaunchMode.externalApplication,
      );

      // Step 4 — clear cart and navigate to processing screen
      await _clearCart();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            isCOD: false,
            apiFuture: Future.value(orderResult),
            userId: widget.userId,
            subtotal: widget.subtotal,
            serviceCharge: widget.serviceCharge,
            discount: widget.discount,
            total: widget.total,
          ),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      _snack("Payment failed");
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  /* =====================================================
     HELPERS
  ===================================================== */

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  void _onConfirm() {
    if (_method == null) {
      _snack("Please select a payment method");
      return;
    }
    _method == "COD" ? _handleCOD() : _startCashfree();
  }

  /* =====================================================
     BUILD
  ===================================================== */

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
        body: Column(children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(children: [
                _locationCard(),
                const SizedBox(height: 16),
                _scheduleCard(),
                const SizedBox(height: 16),
                _summaryCard(),
                const SizedBox(height: 16),
                _paymentCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
          _bottomBar(),
        ]),
      );

  /* =====================================================
     HEADER
  ===================================================== */

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 22),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Row(children: [
          _circleBtn(
              Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Checkout",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text("Secure",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  /* =====================================================
     CARD WRAPPER
  ===================================================== */

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              isDark ? Border.all(color: Colors.grey.shade800) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String title, IconData icon) =>
      Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
      ]);

  /* =====================================================
     LOCATION CARD
  ===================================================== */

  Widget _locationCard() => _card(
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Service Location",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey)),
                  const SizedBox(height: 3),
                  Text(widget.location,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : Colors.black87)),
                ]),
          ),
        ]),
      );

  /* =====================================================
     SCHEDULE CARD
  ===================================================== */

  Widget _scheduleCard() => _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                  "Service Schedule", Icons.schedule_rounded),
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.calendar_today,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(widget.date,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : Colors.black87)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.access_time,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(widget.slot,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ]),
              const SizedBox(height: 12),
              Text(
                  "All selected services will be provided at this time slot",
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey)),
            ]),
      );

  /* =====================================================
     SUMMARY CARD
  ===================================================== */

  Widget _summaryCard() {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final item in widget.cartItems) {
      final name = item["name"] ?? "Service";
      if (grouped.containsKey(name)) {
        grouped[name]!["qty"] = (grouped[name]!["qty"] as int) + 1;
      } else {
        grouped[name] = {
          "qty": 1,
          "price":
              double.tryParse(item["price"]?.toString() ?? "0") ?? 0.0,
        };
      }
    }

    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                "Booking Summary", Icons.receipt_long_rounded),
            const SizedBox(height: 14),
            ...grouped.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color:
                              AppColors.primary.withOpacity(0.08),
                          borderRadius:
                              BorderRadius.circular(10)),
                      child: Icon(
                          Icons.medical_services_outlined,
                          color: AppColors.primary,
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value["qty"] > 1
                            ? "${e.key} ×${e.value["qty"]}"
                            : e.key,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : Colors.black87),
                      ),
                    ),
                    Text(
                      "₹${((e.value["price"] as double) * (e.value["qty"] as int)).toStringAsFixed(0)}",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ]),
                )),
            Divider(
                thickness: 0.8,
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200),
            const SizedBox(height: 8),
            _billRow("Subtotal",
                "₹${widget.subtotal.toStringAsFixed(2)}"),
            if (widget.serviceCharge > 0) ...[
              const SizedBox(height: 6),
              _billRow(
                  "Service Charge",
                  "+₹${widget.serviceCharge.toStringAsFixed(2)}",
                  valueColor: isDark
                      ? Colors.orange.shade300
                      : Colors.orange.shade700),
            ],
            if (widget.discount > 0) ...[
              const SizedBox(height: 6),
              _billRow(
                  widget.couponCode.isNotEmpty
                      ? "Coupon (${widget.couponCode})"
                      : "Discount",
                  "−₹${widget.discount.toStringAsFixed(2)}",
                  valueColor: Colors.green),
            ],
            const SizedBox(height: 10),
            Divider(
                thickness: 0.8,
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200),
            const SizedBox(height: 8),
            _billRow("Total Payable",
                "₹${widget.total.toStringAsFixed(2)}",
                isBold: true),
          ]),
    );
  }

  Widget _billRow(String label, String value,
          {bool isBold = false, Color? valueColor}) =>
      Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? Colors.grey.shade300 : Colors.black54,
                fontWeight:
                    isBold ? FontWeight.bold : FontWeight.normal)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight:
                    isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ??
                    (isBold
                        ? AppColors.primary
                        : (isDark
                            ? Colors.white
                            : Colors.black87)))),
      ]);

  /* =====================================================
     PAYMENT CARD
  ===================================================== */

  Widget _paymentCard() => _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                  "Payment Method", Icons.payment_rounded),
              const SizedBox(height: 6),
              if (_method == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text("Select how you'd like to pay",
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400)),
                ),
              const SizedBox(height: 8),
              _payOption(
                value: "COD",
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.money_rounded,
                      color: Color(0xFF2E7D32), size: 22),
                ),
                title: "Cash after Service",
                subtitle: "Pay in cash when done",
              ),
              const SizedBox(height: 10),
              _payOption(
                value: "ONLINE",
                leading: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12)),
                  child: Image.asset('assets/cashfree.png',
                      fit: BoxFit.contain),
                ),
                title: "Cards / UPI / Wallets",
                subtitle: "Secure payment via Cashfree",
              ),
            ]),
      );

  Widget _payOption({
    required String value,
    required Widget leading,
    required String title,
    required String subtitle,
  }) {
    final sel = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.05)
              : (isDark
                  ? const Color(0xFF0F172A)
                  : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel
                ? AppColors.primary
                : (isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200),
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: sel
                              ? AppColors.primary
                              : (isDark
                                  ? Colors.white
                                  : Colors.black87))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500)),
                ]),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? AppColors.primary : Colors.transparent,
              border: Border.all(
                  color: sel
                      ? AppColors.primary
                      : (isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300),
                  width: 2),
            ),
            child: sel
                ? const Icon(Icons.check,
                    color: Colors.white, size: 13)
                : null,
          ),
        ]),
      ),
    );
  }

  /* =====================================================
     BOTTOM BAR
  ===================================================== */

  Widget _bottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: isDark
              ? Border(
                  top: BorderSide(color: Colors.grey.shade800))
              : null,
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(isDark ? 0.4 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Row(children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.discount > 0 ||
                    widget.serviceCharge > 0)
                  Text(
                      "₹${widget.subtotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.grey)),
                Text("₹${widget.total.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                if (widget.discount > 0)
                  Text(
                      "Saved ₹${widget.discount.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600)),
              ]),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _processing ? null : _onConfirm,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  gradient: _method == null
                      ? LinearGradient(colors: [
                          Colors.grey.shade400,
                          Colors.grey.shade400,
                        ])
                      : AppColors.gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _method != null
                      ? [
                          BoxShadow(
                              color: AppColors.primary
                                  .withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]
                      : [],
                ),
                child: Center(
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2))
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              _method == "ONLINE"
                                  ? Icons.flash_on_rounded
                                  : Icons
                                      .check_circle_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _method == null
                                  ? "Select Payment Method"
                                  : _method == "COD"
                                      ? "Confirm Booking"
                                      : "Pay ₹${widget.total.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ]),
      );
}