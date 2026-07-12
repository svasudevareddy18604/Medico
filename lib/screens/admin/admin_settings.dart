import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login_page.dart';
import '../../utils/app_colors.dart';

import 'radius_settings_screen.dart';
import 'admin_chat_list_screen.dart';
import 'manage_notifications_screen.dart';
import 'admin_promotion_screen.dart';
import 'admin_coupon_screen.dart';
import 'service_charges_screen.dart';
import 'location_control_screen.dart';
import 'admin_terms_conditions_screen.dart'; // NEW

class AdminSettings extends StatelessWidget {
  const AdminSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(Icons.chat_bubble_rounded, Colors.green, "Support Chats",
          "View & reply to users", () => _go(context, const AdminChatListScreen())),
      _Item(Icons.local_offer_rounded, Colors.amber, "Coupons",
          "Manage discount coupons", () => _go(context, const AdminCouponScreen())),
      _Item(Icons.my_location_rounded, Colors.orange, "Nearby Radius",
          "Control caretaker distance", () => _go(context, const RadiusSettingsScreen())),
      _Item(Icons.location_on_rounded, Colors.deepPurple, "Location Control",
          "Manage service areas & states", () => _go(context, const LocationControlScreen())),
      _Item(Icons.notifications_active_rounded, Colors.teal, "Notifications",
          "Send & schedule alerts", () => _go(context, const ManageNotificationsScreen())),
      _Item(Icons.campaign_rounded, Colors.pink, "Promotions",
          "Manage offers & discounts", () => _go(context, const AdminPromotionScreen())),
      _Item(Icons.currency_rupee_rounded, Colors.indigo, "Service Charges",
          "Configure charge settings", () => _go(context, const ServiceChargesScreen())),
      _Item(Icons.gavel_rounded, Colors.brown, "Terms & Conditions",
          "Update terms & notify users", () => _go(context, const AdminTermsConditionsScreen())), // NEW
      _Item(Icons.logout_rounded, Colors.red, "Logout",
          "Sign out of your account", () => _logout(context), isLogout: true),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              itemCount: items.length,
              itemBuilder: (_, i) {
                if (i == items.length - 2) {
                  return Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(),
                      ),
                      _tile(context, items[i]),
                    ],
                  );
                }
                return _tile(context, items[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Settings",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            "Manage your admin controls",
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _Item item) {
    return GestureDetector(
      onTap: item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: item.isLogout ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: item.isLogout ? Border.all(color: Colors.red.shade100) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: item.isLogout ? Colors.red.shade600 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: item.isLogout ? Colors.red.shade300 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLogout;

  const _Item(this.icon, this.color, this.title, this.subtitle, this.onTap,
      {this.isLogout = false});
}