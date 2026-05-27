import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';

class CareSeekerCouponScreen extends StatefulWidget {
  final double total;
  final int userId;
  const CareSeekerCouponScreen({super.key, required this.total, required this.userId});

  @override
  State<CareSeekerCouponScreen> createState() => _CareSeekerCouponScreenState();
}

class _CareSeekerCouponScreenState extends State<CareSeekerCouponScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> coupons = [];
  bool loading = true;
  String? errorMessage;
  late AnimationController _emptyAnim;

  @override
  void initState() {
    super.initState();
    _emptyAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    fetchCoupons();
  }

  @override
  void dispose() { _emptyAnim.dispose(); super.dispose(); }

  Future<void> fetchCoupons() async {
    setState(() { loading = true; errorMessage = null; });
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/careseeker/coupons?user_id=${widget.userId}"));
      if (res.statusCode == 200) {
        setState(() => coupons = jsonDecode(res.body)['data'] ?? []);
      } else {
        setState(() => errorMessage = "Failed to load coupons");
      }
    } catch (_) {
      setState(() => errorMessage = "No internet connection");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Compute actual discount rupee amount from coupon + current cart total
  double _computeDiscount(dynamic coupon) {
    final type = coupon['discount_type']?.toString() ?? 'flat';
    final value = (coupon['discount'] ?? 0).toDouble();
    final maxDisc = coupon['max_discount'] != null ? (coupon['max_discount']).toDouble() : double.infinity;

    if (type == 'percentage') {
      final calculated = widget.total * value / 100;
      return calculated > maxDisc ? maxDisc : calculated;
    }
    // flat
    return value > widget.total ? widget.total : value;
  }

  void _applyCoupon(dynamic coupon) {
    final minOrder = (coupon['min_order'] ?? 0).toDouble();
    if (widget.total < minOrder) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Minimum order ₹${minOrder.toStringAsFixed(0)} required"),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final discountAmount = _computeDiscount(coupon);
    Navigator.pop(context, {
      "code": coupon["code"],
      "discount": discountAmount,           // actual ₹ amount
      "discount_type": coupon["discount_type"] ?? "flat",
      "discount_value": coupon["discount"], // raw % or ₹ for display
    });
  }

  String _discountLabel(dynamic coupon) {
    final type = coupon['discount_type']?.toString() ?? 'flat';
    final value = coupon['discount'] ?? 0;
    final maxDisc = coupon['max_discount'];
    if (type == 'percentage') {
      final suffix = maxDisc != null ? " (upto ₹$maxDisc)" : "";
      return "$value% OFF$suffix";
    }
    return "₹$value OFF";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF6F7FB),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : errorMessage != null
                  ? _errorState()
                  : coupons.isEmpty
                      ? _emptyState(context)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: coupons.length,
                          itemBuilder: (ctx, i) => _couponCard(ctx, coupons[i]),
                        ),
        ),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 40),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
        ),
      ),
      const SizedBox(width: 12),
      const Icon(Icons.local_offer_rounded, color: Colors.white, size: 28),
      const SizedBox(width: 10),
      const Text("Apply Coupon",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _couponCard(BuildContext context, dynamic coupon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minOrder = (coupon['min_order'] ?? 0).toDouble();
    final eligible = widget.total >= minOrder;
    final actualDiscount = _computeDiscount(coupon);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(eligible ? 0.2 : 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        // Accent strip
        Container(
          width: 6, height: 100,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
          ),
        ),
        const SizedBox(width: 14),
        // Icon
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        // Details
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(coupon["code"] ?? "", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(_discountLabel(coupon), style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                coupon["title"]?.toString().isNotEmpty == true ? coupon["title"] : _discountLabel(coupon),
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              if (minOrder > 0) ...[
                const SizedBox(height: 3),
                Text("Min. ₹${minOrder.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
              // Show computed saving if eligible
              if (eligible)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text("You save ₹${actualDiscount.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
        ),
        // Apply button
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: eligible ? () => _applyCoupon(coupon) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: eligible ? AppColors.gradient : null,
                color: eligible ? null : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("Apply",
                  style: TextStyle(
                    color: eligible ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey),
                    fontSize: 13, fontWeight: FontWeight.bold,
                  )),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _emptyAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -6 * _emptyAnim.value),
              child: Stack(alignment: Alignment.center, children: [
                Container(width: 130, height: 130,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.06 + 0.04 * _emptyAnim.value))),
                Container(width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
                    child: Icon(Icons.confirmation_number_rounded, color: AppColors.primary.withOpacity(0.7), size: 50)),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          Text("No Coupons Available",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
          const SizedBox(height: 10),
          Text("No active coupons right now.\nCheck back later for exciting offers!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, height: 1.6)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text("New coupons are added regularly. Stay tuned!",
                  style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _errorState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 90, height: 90,
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, size: 44, color: Colors.redAccent)),
      const SizedBox(height: 16),
      Text(errorMessage!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        label: const Text("Retry", style: TextStyle(color: Colors.white)),
        onPressed: fetchCoupons,
      ),
    ]),
  );
}