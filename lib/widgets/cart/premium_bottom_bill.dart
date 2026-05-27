import 'package:flutter/material.dart';
import 'package:medico/main.dart';

class PremiumBottomBill extends StatefulWidget {
  final double subtotal, serviceCharge, total, discount;
  final String couponCode;
  final VoidCallback onRemoveCoupon, onCheckout;
  final Color primary;

  const PremiumBottomBill({
    super.key, required this.subtotal, required this.serviceCharge,
    required this.total, required this.discount, required this.couponCode,
    required this.onRemoveCoupon, required this.onCheckout, required this.primary,
  });

  @override
  State<PremiumBottomBill> createState() => _PremiumBottomBillState();
}

class _PremiumBottomBillState extends State<PremiumBottomBill> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final displayTotal = widget.total - widget.discount;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(children: [
              _row("Item Total", widget.subtotal, labelColor, valueColor),
              _row("Service Fee", widget.serviceCharge, labelColor, valueColor),
              if (widget.discount > 0)
                _row("Discount", -widget.discount, Colors.green, Colors.green, isDiscount: true),
              Divider(color: border),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("To Pay", style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
                Text("₹${displayTotal.toStringAsFixed(0)}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: widget.primary)),
              ]),
              if (widget.couponCode.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: widget.onRemoveCoupon,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: widget.primary.withOpacity(isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.local_offer, size: 18, color: widget.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Applied: ${widget.couponCode}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                      const Icon(Icons.close, color: Colors.red),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ]),
          ),
          secondChild: const SizedBox(),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => setState(() => expanded = !expanded),
                  child: Row(children: [
                    Text(expanded ? "Hide Details" : "View Details",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: labelColor)),
                    const SizedBox(width: 4),
                    Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        size: 18, color: labelColor),
                  ]),
                ),
                const SizedBox(height: 4),
                Text("₹${displayTotal.toStringAsFixed(0)}",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
              ]),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: widget.onCheckout,
              child: const Text("Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(String title, double value, Color lc, Color vc, {bool isDiscount = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: TextStyle(color: lc, fontSize: 14)),
        Text(isDiscount ? "- ₹${value.abs().toStringAsFixed(0)}" : "₹${value.toStringAsFixed(0)}",
            style: TextStyle(color: vc, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
}