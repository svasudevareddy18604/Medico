import 'package:flutter/material.dart';

class CartBottomBar extends StatelessWidget {
  final double total;
  final double discount;
  final String location;
  final List cartItems;
  final VoidCallback onCheckout;
  final Color primary;

  const CartBottomBar({
    super.key,
    required this.total,
    required this.discount,
    required this.location,
    required this.cartItems,
    required this.onCheckout,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final displayTotal = total - discount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -3))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Total", style: TextStyle(fontSize: 14)),
                  Text(
                    "₹${displayTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (location == "Add Address") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Please add your address first")),
                  );
                  return;
                }

                if (cartItems.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cart is empty")),
                  );
                  return;
                }

                onCheckout();
              },
              child: const Text(
                "Proceed to Checkout",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}