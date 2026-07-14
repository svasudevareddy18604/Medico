import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:intl/intl.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import '../../config/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'processing_screen.dart';
import 'payment_failed_screen.dart';
// Imported with a prefix because careseeker_location.dart declares its own
// top-level `enum ToastType`, which would otherwise collide with the one
// defined below in this file.
import 'careseeker_location.dart' as location_screen;

void _log(String msg) => debugPrint("💳 [Payment] $msg");

// ════════════════════════════════════════════════════════════════════════
//  TOP TOAST — a small, dependency-free replacement for SnackBar that
//  slides down from the top of the screen. Stacks cleanly, auto-dismisses,
//  and never fights with the bottom bar / keyboard the way SnackBars do.
// ════════════════════════════════════════════════════════════════════════
enum ToastType { success, error, info }

class TopToast {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.error,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    final overlayState = Overlay.of(context, rootOverlay: true);

    // Remove any toast currently showing so they don't stack.
    _entry?.remove();
    _entry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopToastWidget(
        message: message,
        type: type,
        duration: duration,
        onFinished: () {
          entry.remove();
          if (_entry == entry) _entry = null;
        },
      ),
    );

    _entry = entry;
    overlayState.insert(entry);
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onFinished;

  const _TopToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onFinished,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({IconData icon, Color color}) get _style {
    switch (widget.type) {
      case ToastType.success:
        return (icon: Icons.check_circle_rounded, color: const Color(0xFF16A34A));
      case ToastType.error:
        return (icon: Icons.error_rounded, color: const Color(0xFFDC2626));
      case ToastType.info:
        return (icon: Icons.info_rounded, color: const Color(0xFF2563EB));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, color: s.color, size: 15),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  PAYMENT SCREEN
// ════════════════════════════════════════════════════════════════════════
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

  // ── Service address is now mutable state, seeded from the widget, so it
  // can be updated in place after the user picks a new one on the map/
  // address screen — no need to pop this whole screen and rebuild it.
  late String _location;
  double? _latitude;
  double? _longitude;
  bool _locationUpdating = false;

  // ── collapsible section states — hidden by default, user can expand ──────
  bool _locationExpanded = false;
  bool _scheduleExpanded = false;

  // ── FIX 1: Single persistent HTTP client — reuses TCP+TLS connections
  // instead of doing a full handshake on every tap. Saves 300–600ms.
  final http.Client _httpClient = http.Client();

  // ── FIX 2: CFPaymentGatewayService created ONCE at init, not per-tap.
  // setCallback also called at init so the SDK warms up its WebView
  // before the user even taps Pay. By the time they tap, the sheet
  // opens instantly instead of waiting 1–2s for WebView init.
  late final CFPaymentGatewayService _cfService;

  bool get isDark => themeNotifier.value == ThemeMode.dark;

  String _to24Hour(String time) {
    final dt = DateFormat("h:mm a")
        .parse(time.trim().replaceAll(RegExp(r'\s+'), ' '));
    return DateFormat("HH:mm:ss").format(dt);
  }

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);

    _location = widget.location;
    _latitude = widget.latitude;
    _longitude = widget.longitude;

    // ── FIX 2 (core): Warm up the SDK immediately on screen open.
    // setCallback here means the WebView is ready before user taps Pay.
    _cfService = CFPaymentGatewayService();
    _cfService.setCallback(_verifyPayment, _onError);
    _log("Screen init — userId:${widget.userId} total:${widget.total}");

    // ── FIX 3: Pre-warm backend connection by sending a lightweight
    // OPTIONS/HEAD equivalent — just open the TCP+TLS connection to
    // your server so it's in the keep-alive pool when the user taps Pay.
    // We do this silently, ignoring any errors.
    _prewarmBackend();
  }

  Future<void> _prewarmBackend() async {
    try {
      await _httpClient
          .get(Uri.parse("${Api.baseUrl}/ping"))
          .timeout(const Duration(seconds: 5));
      _log("Backend prewarmed ✅");
    } catch (_) {
      // Silent — this is best-effort only
    }
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    // Close the persistent client to release socket pool
    _httpClient.close();
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  // ── CASHFREE CALLBACKS ────────────────────────────────────────────────────

  void _verifyPayment(String orderId) {
    _log("✅ verifyPayment — CF orderId: $orderId");
    if (!mounted) return;
    setState(() => _processing = false);

    final apiFuture =
        _placeOrder(method: "ONLINE", paymentId: orderId).then((result) async {
      if (result == null) return null;
      await _clearCart();
      return result;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          isCOD: false,
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

  void _onError(CFErrorResponse errorResponse, String orderId) {
    final msg = errorResponse.getMessage() ?? "";
    final String? statusCode = errorResponse.getStatus();
    _log("❌ onError — orderId:$orderId status:$statusCode msg:$msg");
    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentFailedScreen()),
    );
  }

  // ── PLACE ORDER ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _placeOrder({
    required String method,
    String paymentId = "",
  }) async {
    _log("placeOrder → method:$method paymentId:$paymentId");
    try {
      final body = jsonEncode({
        "user_id": widget.userId,
        "location": _location,
        "date": widget.date,
        "slot": _to24Hour(widget.slot),
        "total": widget.total,
        "subtotal": widget.subtotal,
        "service_charge": widget.serviceCharge,
        "discount": widget.discount,
        "coupon_code": widget.couponCode,
        "payment_method": method,
        "payment_id": paymentId,
        "latitude": _latitude,
        "longitude": _longitude,
        "items": widget.cartItems
            .map((e) => {
                  "service_id": e["service_id"] ?? e["id"],
                  "quantity": e["quantity"] ?? 1,
                  "price": e["price"] ?? 0,
                  "category": (e["category"] ?? "").toString().trim(),
                })
            .toList(),
      });

      // ── FIX 1 (used here): reuse persistent _httpClient
      final res = await _httpClient
          .post(
            Uri.parse(Api.placeOrder),
            headers: {"Content-Type": "application/json"},
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      _log("placeOrder ${res.statusCode}: ${res.body}");
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["success"] != true) return null;

      if (data["orders"] is List && (data["orders"] as List).isNotEmpty) {
        final first = (data["orders"] as List).first as Map<String, dynamic>;
        data["order_id"] ??= first["order_id"] ?? first["id"];
        data["order_code"] ??= first["order_code"];
      }
      _log("placeOrder success — order_id:${data["order_id"]}");
      return data;
    } catch (e) {
      _log("placeOrder exception: $e");
      return null;
    }
  }

  // ── CLEAR CART ────────────────────────────────────────────────────────────
  Future<void> _clearCart() async {
    try {
      await _httpClient
          .delete(Uri.parse("${Api.baseUrl}/cart/${widget.userId}/clear"))
          .timeout(const Duration(seconds: 10));
      _log("Cart cleared");
    } catch (e) {
      _log("clearCart error: $e");
    }
  }

  // ── COD ───────────────────────────────────────────────────────────────────
  Future<void> _handleCOD() async {
    if (_processing) return;
    setState(() => _processing = true); // ── FIX 4: show spinner immediately

    final apiFuture = _placeOrder(method: "COD").then((result) async {
      if (result == null) return null;
      final id = result["order_id"];
      if (id != null) {
        _httpClient
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

  // ── CASHFREE SDK FLOW ─────────────────────────────────────────────────────
  Future<void> _startCashfree() async {
    if (_processing) return;
    _log("Cashfree SDK flow — amount:${widget.total}");

    // ── FIX 4: Set processing TRUE before any await so the button shows
    // a spinner instantly on tap. User gets immediate visual feedback.
    setState(() => _processing = true);

    try {
      // ── FIX 1 (used here): persistent _httpClient for fast connection reuse
      final res = await _httpClient
          .post(
            Uri.parse(Api.createOrder),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "amount": widget.total,
              "customer_id": widget.userId.toString(),
              "customer_name": "Medico User",
              "customer_email": "user@test.com",
              "customer_phone": "9999999999",
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception("Order creation timed out"),
          );

      _log("createOrder HTTP ${res.statusCode}: ${res.body}");

      if (res.statusCode != 200) {
        _toast("Server error (${res.statusCode}). Please try again.");
        if (mounted) setState(() => _processing = false);
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data["success"] != true) {
        _toast(data["message"] ?? "Payment initialization failed.");
        if (mounted) setState(() => _processing = false);
        return;
      }

      final String? sessionId = data["payment_session_id"] as String?;
      final String? cfOrderId = data["order_id"] as String?;

      if (sessionId == null || sessionId.isEmpty) {
        _toast("Payment session unavailable. Please try again.");
        if (mounted) setState(() => _processing = false);
        return;
      }

      if (cfOrderId == null || cfOrderId.isEmpty) {
        _toast("Order ID missing. Please try again.");
        if (mounted) setState(() => _processing = false);
        return;
      }

      _log("CF-OrderId: $cfOrderId  SessionId: $sessionId");

      // ── FIX 2 (used here): _cfService and setCallback already done in
      // initState, so the SDK is pre-warmed. We just build session + launch.
      // No re-registration needed — setCallback is idempotent and safe.

      final cfSession = CFSessionBuilder()
          .setEnvironment(
            Api.isProduction ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX,
          )
          .setOrderId(cfOrderId)
          .setPaymentSessionId(sessionId)
          .build();

      final cfPayment = CFWebCheckoutPaymentBuilder()
          .setSession(cfSession)
          .build();

      // ── FIX 5: doPayment is synchronous from SDK perspective — it hands
      // control to the payment sheet. _processing stays true until
      // _verifyPayment or _onError fires (both reset it).
      _cfService.doPayment(cfPayment);
    } catch (e) {
      _log("_startCashfree exception: $e");
      _toast("Failed to open payment. Please try again.");
      if (mounted) setState(() => _processing = false);
    }
  }

  // ── CHANGE SERVICE ADDRESS ─────────────────────────────────────────────
  // Opens the real careseeker_location.dart screen. That screen takes only
  // a userId — no address is passed in, and nothing is returned via
  // Navigator.pop. Instead, when the user taps an address there it writes
  // the selection straight into SharedPreferences (keys below) and then
  // pops. So once we're back, we just read those keys and, if the address
  // actually changed, update this screen's summary in place.
  Future<void> _changeLocation() async {
    if (_locationUpdating) return;
    setState(() => _locationUpdating = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => location_screen.CareSeekerLocation(userId: widget.userId),
        ),
      );

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final newAddress = prefs.getString("user_location_${widget.userId}");
      final newLat = prefs.getDouble("user_lat_${widget.userId}");
      final newLng = prefs.getDouble("user_lng_${widget.userId}");

      if (newAddress != null &&
          newAddress.trim().isNotEmpty &&
          newAddress.trim() != _location) {
        setState(() {
          _location = newAddress.trim();
          _latitude = newLat ?? _latitude;
          _longitude = newLng ?? _longitude;
          _locationExpanded = true; // reveal the updated address right away
        });
        _toast("Delivery address updated", type: ToastType.success);
      }
    } finally {
      if (mounted) setState(() => _locationUpdating = false);
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  void _toast(String msg, {ToastType type = ToastType.error}) {
    if (!mounted) return;
    TopToast.show(context, message: msg, type: type);
  }

  void _onConfirm() {
    if (_method == null) {
      _toast("Please select a payment method");
      return;
    }
    _method == "COD" ? _handleCOD() : _startCashfree();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
                const SizedBox(height: 12),
                _scheduleCard(),
                const SizedBox(height: 12),
                _summaryCard(),
                const SizedBox(height: 12),
                _paymentCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
          _bottomBar(),
        ]),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 22),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Row(children: [
          _circleBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Checkout",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
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

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: Colors.grey.shade800) : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String title, IconData icon, {double fontSize = 15}) =>
      Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
      ]);

  // ── COLLAPSIBLE SECTION HEADER — used for Location + Schedule ────────────
  // Hidden by default. Tapping the row toggles a smooth expand/collapse.
  // An optional trailingAction (e.g. "Change") sits as its own tap target
  // so it doesn't also trigger expand/collapse.
  Widget _collapsibleHeader({
    required IconData icon,
    required String title,
    required String collapsedSubtitle,
    required bool expanded,
    required VoidCallback onTap,
    Widget? trailingAction,
  }) =>
      Row(children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87)),
                    if (!expanded) ...[
                      const SizedBox(height: 2),
                      Text(collapsedSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500)),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
        if (trailingAction != null) ...[
          const SizedBox(width: 4),
          trailingAction,
        ],
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  size: 22),
            ),
          ),
        ),
      ]);

  // ── "Change" pill button — opens careseeker_location.dart ────────────────
  Widget _changeAddressButton() => InkWell(
        onTap: _changeLocation,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: _locationUpdating
              ? SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_location_alt_rounded,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text("Change",
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ]),
        ),
      );

  Widget _locationCard() => _card(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          _collapsibleHeader(
            icon: Icons.location_on_rounded,
            title: "Service Location",
            collapsedSubtitle: _location,
            expanded: _locationExpanded,
            onTap: () =>
                setState(() => _locationExpanded = !_locationExpanded),
            trailingAction: _changeAddressButton(),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _locationExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12, left: 52),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_location,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? Colors.white : Colors.black87)),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ]),
      );

  Widget _scheduleCard() => _card(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          _collapsibleHeader(
            icon: Icons.schedule_rounded,
            title: "Service Schedule",
            collapsedSubtitle: "${widget.date} • ${widget.slot}",
            expanded: _scheduleExpanded,
            onTap: () =>
                setState(() => _scheduleExpanded = !_scheduleExpanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _scheduleExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 14, left: 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.calendar_today,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(widget.date,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.access_time,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(widget.slot,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                      "All selected services will be provided at this time slot",
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500)),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ]),
      );

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
            _sectionTitle("Booking Summary", Icons.receipt_long_rounded),
            const SizedBox(height: 14),
            ...grouped.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.medical_services_outlined,
                            color: AppColors.primary, size: 18)),
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
                                    : Colors.black87))),
                    Text(
                        "₹${((e.value["price"] as double) * (e.value["qty"] as int)).toStringAsFixed(0)}",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ]),
                )),
            Divider(
                thickness: 0.8,
                color: isDark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200),
            const SizedBox(height: 8),
            _billRow("Subtotal", "₹${widget.subtotal.toStringAsFixed(2)}"),
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
                color: isDark ? Colors.grey.shade300 : Colors.black54,
                fontWeight:
                    isBold ? FontWeight.bold : FontWeight.normal)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ??
                    (isBold
                        ? AppColors.primary
                        : (isDark ? Colors.white : Colors.black87)))),
      ]);

  // ── PAYMENT METHOD — compact, professional segmented-style selector ──────
  Widget _paymentCard() => _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Payment Method", Icons.payment_rounded),
              const SizedBox(height: 4),
              if (_method == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text("Select how you'd like to pay",
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400)),
                )
              else
                const SizedBox(height: 14),
              _payOption(
                value: "COD",
                iconBg: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF2E7D32),
                icon: Icons.money_rounded,
                title: "Cash after Service",
                subtitle: "Pay in cash when done",
              ),
              const SizedBox(height: 8),
              _payOption(
                value: "ONLINE",
                iconBg: const Color(0xFFE3F2FD),
                iconColor: const Color(0xFF1565C0),
                icon: null,
                assetIcon: 'assets/cashfree.png',
                title: "Cards / UPI / Wallets",
                subtitle: "Secure payment via Cashfree",
              ),
            ]),
      );

  Widget _payOption({
    required String value,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    IconData? icon,
    String? assetIcon,
  }) {
    final sel = _method == value;
    return InkWell(
      onTap: () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary.withOpacity(isDark ? 0.14 : 0.06)
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel
                  ? AppColors.primary
                  : (isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade200),
              width: sel ? 1.3 : 1),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            padding: assetIcon != null ? const EdgeInsets.all(5) : null,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: assetIcon != null
                ? Image.asset(assetIcon, fit: BoxFit.contain)
                : Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? AppColors.primary
                              : (isDark ? Colors.white : Colors.black87))),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500)),
                ]),
          ),
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? AppColors.primary : Colors.transparent,
                border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : (isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade300),
                    width: 1.6)),
            child: sel
                ? const Icon(Icons.check, color: Colors.white, size: 11)
                : null,
          ),
        ]),
      ),
    );
  }

  Widget _bottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: isDark
              ? Border(top: BorderSide(color: Colors.grey.shade800))
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: Row(children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.discount > 0 || widget.serviceCharge > 0)
                  Text("₹${widget.subtotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.grey)),
                Text("₹${widget.total.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                if (widget.discount > 0)
                  Text("Saved ₹${widget.discount.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.green,
                          fontWeight: FontWeight.w600)),
              ]),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: _processing ? null : _onConfirm,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  gradient: _method == null
                      ? LinearGradient(colors: [
                          Colors.grey.shade400,
                          Colors.grey.shade400
                        ])
                      : AppColors.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _method != null
                      ? [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : [],
                ),
                child: Center(
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                _method == "ONLINE"
                                    ? Icons.flash_on_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _method == null
                                  ? "Select Payment Method"
                                  : _method == "COD"
                                      ? "Confirm Booking"
                                      : "Pay ₹${widget.total.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]),
                ),
              ),
            ),
          ),
        ]),
      );
}