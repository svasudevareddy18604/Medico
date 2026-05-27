import 'package:flutter/material.dart';
import 'package:medico/main.dart';

class AddressCard extends StatelessWidget {
  final String location;
  final Color primary;
  final VoidCallback onTap;
  const AddressCard({super.key, required this.location, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.location_on_rounded, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Service Address", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
              const SizedBox(height: 2),
              Text(location, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87)),
            ]),
          ),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
        ]),
      ),
    );
  }
}