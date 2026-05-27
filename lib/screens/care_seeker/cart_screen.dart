import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import '../../widgets/cart/cart_item_card.dart';
import '../../widgets/cart/premium_bottom_bill.dart';
import '../../widgets/common_header.dart';
import '../../widgets/cart/address_card.dart';
import '../../widgets/cart/schedule_bottom_sheet.dart';
import 'careseeker_location.dart';
import 'careseekercoupon_screen.dart';
import '../../config/api.dart';

enum ToastType { success, error, warning, info }

class CartScreen extends StatefulWidget {
  final int userId;
  const CartScreen({super.key, required this.userId});
  @override
  // PUBLIC state class — required for GlobalKey<CartScreenState>
  CartScreenState createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  List<dynamic> cartItems = [];
  bool loading = true;
  String location = "Add Address";
  double? lat, lng;
  double discount = 0, couponValue = 0, backendSubtotal = 0, serviceCharge = 0, backendTotal = 0;
  String couponCode = "", couponType = "";
  List dates = [];

  bool get isDark => themeNotifier.value == ThemeMode.dark;
  void _onThemeChange() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    WidgetsBinding.instance.addObserver(this);
    generateDates();
    refresh();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// Called by CareSeekerHome when user taps the Cart tab
  Future<void> refresh() async {
    await Future.wait([_loadLocation(), _loadCart(), _loadCartSummary()]);
  }

  Future<void> _loadCart() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/cart/${widget.userId}"));
      if (res.statusCode == 200 && mounted) setState(() => cartItems = jsonDecode(res.body));
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadCartSummary() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/cart/${widget.userId}/summary"));
      if (res.statusCode == 200 && mounted) {
        final d = jsonDecode(res.body);
        setState(() {
          backendSubtotal = (d["subtotal"]      ?? 0).toDouble();
          serviceCharge   = (d["serviceCharge"] ?? 0).toDouble();
          backendTotal    = (d["total"]          ?? 0).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLocation() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      location = p.getString("user_location_${widget.userId}") ?? "Add Address";
      lat      = p.getDouble("user_lat_${widget.userId}");
      lng      = p.getDouble("user_lng_${widget.userId}");
    });
  }

  Future<void> _removeFromCart(int id) async {
    await http.delete(Uri.parse("${Api.baseUrl}/cart/${widget.userId}/$id"));
    if (!mounted) return;
    setState(() => cartItems.removeWhere((i) => i["cart_id"] == id));
    _loadCartSummary();
  }

  Future<void> _clearCartAfterBooking() async {
    await http.delete(Uri.parse("${Api.baseUrl}/cart/${widget.userId}/clear"));
    _clearCoupon();
    if (!mounted) return;
    setState(() => cartItems.clear());
  }

  Future<List> _loadSlots(String date) async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/slots/date/$date"));
      if (res.statusCode == 200) return jsonDecode(res.body)["slots"] ?? [];
    } catch (_) {}
    return [];
  }

  void generateDates() {
    dates = List.generate(7, (i) {
      final d = DateTime.now().add(Duration(days: i));
      return {"label": "${d.day}/${d.month}", "value": d.toIso8601String().split("T")[0]};
    });
  }

  // ── Coupon: NO auto-save/load — user applies manually each time ───────────

  void _clearCoupon() {
    if (!mounted) return;
    setState(() { discount = 0; couponCode = ""; couponType = ""; couponValue = 0; });
  }

  void _openCouponScreen() async {
    final result = await Navigator.push<Map>(context,
        MaterialPageRoute(builder: (_) =>
            CareSeekerCouponScreen(total: backendSubtotal, userId: widget.userId)));
    if (result != null && mounted) {
      setState(() {
        discount    = (result["discount"]       ?? 0).toDouble();
        couponCode  =  result["code"]           ?? "";
        couponType  =  result["discount_type"]  ?? "flat";
        couponValue = (result["discount_value"] ?? 0).toDouble();
      });
      _showToast("Coupon applied! You save ₹${discount.toStringAsFixed(2)}", type: ToastType.success);
    }
  }

  String get _couponLabel => couponType == 'percentage'
      ? "$couponCode · ${couponValue.toStringAsFixed(0)}% OFF"
      : "$couponCode · ₹${couponValue.toStringAsFixed(0)} OFF";

  void _showToast(String msg, {ToastType type = ToastType.error}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) =>
        _ToastWidget(message: msg, type: type, onDismiss: () => entry.remove()));
    overlay.insert(entry);
  }

  // ── UI Widgets ────────────────────────────────────────────────────────────

  Widget _couponBox() {
    final cardColor   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    if (couponCode.isEmpty) {
      return GestureDetector(
        onTap: _openCouponScreen,
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor), color: cardColor),
          child: Row(children: [
            Icon(Icons.local_offer, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text("Apply Coupon",
                style: TextStyle(fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black))),
            Icon(Icons.arrow_forward_ios, size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey),
          ]),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(_couponLabel,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
          GestureDetector(onTap: _clearCoupon,
              child: const Icon(Icons.close, color: Colors.red, size: 20)),
        ]),
        const SizedBox(height: 4),
        Text("You save ₹${discount.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _emptyCart() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 120, height: 120,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle),
          child: Icon(Icons.shopping_cart_outlined, size: 64,
              color: AppColors.primary.withOpacity(0.5))),
      const SizedBox(height: 20),
      Text("Your cart is empty", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A2E2B))),
      const SizedBox(height: 8),
      Text("Add services to get started",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
    ]),
  );

  void _openScheduleSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ScheduleBottomSheet(
        userId: widget.userId, cartItems: cartItems,
        total: backendSubtotal, serviceCharge: serviceCharge,
        discount: discount, couponCode: couponCode,
        location: location, lat: lat, lng: lng,
        primary: AppColors.primary, dates: dates,
        loadSlots: _loadSlots,
        clearCart: _clearCartAfterBooking,
        reloadCart: _loadCart,
        reloadSummary: _loadCartSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor    = isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB);
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final hasAddress = location != "Add Address" && location.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refresh,
        child: Column(children: [
          CommonHeader(title: "My Cart", icon: Icons.shopping_cart,
              primary: AppColors.primary, accent: AppColors.secondary),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(alignment: Alignment.centerLeft,
                child: Text("Service Address", style: TextStyle(fontSize: 13, color: labelColor))),
          ),

          AddressCard(
            location: location, primary: AppColors.primary,
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CareSeekerLocation(userId: widget.userId)));
              await _loadLocation(); // instant update on return
            },
          ),

          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (cartItems.isEmpty)
            Expanded(child: _emptyCart())
          else
            Expanded(child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(children: [
                    Text("Your Services", style: TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text("${cartItems.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                ...cartItems.map((item) => CartItemCard(
                    item: item, primary: AppColors.primary, onDelete: _removeFromCart)),
                const SizedBox(height: 12),
                _couponBox(),
              ],
            )),
        ]),
      ),

      bottomNavigationBar: cartItems.isNotEmpty
          ? PremiumBottomBill(
              subtotal: backendSubtotal, serviceCharge: serviceCharge,
              total: backendTotal, discount: discount, couponCode: couponCode,
              primary: AppColors.primary,
              onRemoveCoupon: _clearCoupon,
              onCheckout: () {
                if (!hasAddress) {
                  _showToast("Please add a service address first", type: ToastType.warning);
                  return;
                }
                _openScheduleSheet();
              },
            )
          : null,
    );
  }
}

// ── Toast ─────────────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final String message; final ToastType type; final VoidCallback onDismiss;
  const _ToastWidget({required this.message, required this.type, required this.onDismiss});
  @override State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async { if (!mounted) return; await _ctrl.reverse(); widget.onDismiss(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  _ToastStyle get _style => switch (widget.type) {
    ToastType.success => _ToastStyle(const Color(0xFF1B7A4A), const Color(0xFF34C97B), Icons.check_circle_rounded, "Success"),
    ToastType.error   => _ToastStyle(const Color(0xFFC0392B), const Color(0xFFFF6B6B), Icons.cancel_rounded,       "Error"),
    ToastType.warning => _ToastStyle(const Color(0xFFB7600A), const Color(0xFFFFB347), Icons.warning_amber_rounded, "Warning"),
    ToastType.info    => _ToastStyle(const Color(0xFF1A6FA8), const Color(0xFF4FC3F7), Icons.info_rounded,         "Info"),
  };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14, left: 16, right: 16,
      child: SlideTransition(position: _slide, child: FadeTransition(opacity: _fade,
        child: Material(color: Colors.transparent, child: GestureDetector(onTap: _dismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: s.bg.withOpacity(0.45), blurRadius: 18,
                    offset: const Offset(0, 6))]),
            child: Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: Icon(s.icon, color: s.accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(s.label, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(widget.message, style: TextStyle(color: Colors.white.withOpacity(0.88),
                    fontSize: 13, height: 1.3)),
              ])),
              GestureDetector(onTap: _dismiss,
                  child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.6), size: 18)),
            ]),
          ),
        )),
      )),
    );
  }
}

class _ToastStyle {
  final Color bg, accent; final IconData icon; final String label;
  const _ToastStyle(this.bg, this.accent, this.icon, this.label);
}