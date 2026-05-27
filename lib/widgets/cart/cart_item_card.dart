import 'package:flutter/material.dart';
import 'package:medico/main.dart';

class CartItemCard extends StatelessWidget {
  final dynamic item;
  final Function(int) onDelete;
  final Color primary;
  const CartItemCard({super.key, required this.item, required this.onDelete, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final price = double.tryParse(item["price"].toString()) ?? 0.0;
    final cartId = item['cart_id'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary.withOpacity(0.15), primary.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.medical_services_rounded, color: primary, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item["name"] ?? "Service",
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text("₹${price.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 16, color: primary, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: cartId != null ? () => onDelete(cartId) : null,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
          ),
        ),
      ]),
    );
  }
}