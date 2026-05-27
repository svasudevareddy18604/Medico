import 'package:flutter/material.dart';
import 'package:medico/main.dart';

class BillSection extends StatelessWidget {
  final double subtotal, serviceCharge, total, discount;
  final String couponCode;
  final VoidCallback onApplyCoupon, onClearCoupon;
  final Color primary;

  const BillSection({
    super.key, required this.subtotal, required this.serviceCharge,
    required this.total, required this.discount, required this.couponCode,
    required this.onApplyCoupon, required this.onClearCoupon, required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.black87;
    final displayTotal = total - discount;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Bill Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 12),
        _billRow("Item Total", subtotal, labelColor, isDark),
        _billRow("Service Fee", serviceCharge, labelColor, isDark),
        if (discount > 0) _billRow("Discount", -discount, labelColor, isDark, isDiscount: true),
        const SizedBox(height: 10),
        Divider(color: border),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("To Pay", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleColor)),
          Text("₹${displayTotal.toStringAsFixed(0)}",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
        ]),
        if (discount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text("🎉 You saved ₹${discount.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: couponCode.isEmpty ? onApplyCoupon : onClearCoupon,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: couponCode.isEmpty ? (isDark ? const Color(0xFF0F172A) : Colors.grey[100]) : null,
              gradient: couponCode.isEmpty ? null : LinearGradient(
                  colors: [primary.withOpacity(isDark ? 0.2 : 0.15), primary.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: couponCode.isEmpty ? (isDark ? Colors.grey.shade700 : Colors.grey.shade300) : primary),
            ),
            child: Row(children: [
              Icon(Icons.local_offer, size: 20, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(couponCode.isEmpty ? "Apply Coupon" : "Coupon Applied",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: couponCode.isEmpty ? (isDark ? Colors.white : Colors.black) : primary)),
                  if (couponCode.isNotEmpty)
                    Text(couponCode, style: TextStyle(fontSize: 12, color: primary)),
                ]),
              ),
              if (couponCode.isNotEmpty)
                const Icon(Icons.close, color: Colors.red, size: 18)
              else
                Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _billRow(String title, double value, Color labelColor, bool isDark, {bool isDiscount = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: TextStyle(fontSize: 14, color: labelColor)),
        Text(isDiscount ? "- ₹${value.abs().toStringAsFixed(0)}" : "₹${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isDiscount ? Colors.green : (isDark ? Colors.white : Colors.black))),
      ]),
    );
}