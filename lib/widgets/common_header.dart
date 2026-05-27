import 'package:flutter/material.dart';

class CommonHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primary;
  final Color accent;
  final Widget? rightWidget;
  final bool showBack;

  const CommonHeader({
    super.key, required this.title, required this.icon,
    required this.primary, required this.accent,
    this.rightWidget, this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Row(children: [
            if (showBack)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            if (showBack) const SizedBox(width: 10),
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
            if (rightWidget != null) rightWidget!,
          ]),
        ),
      ),
    );
  }
}