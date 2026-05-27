import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 55, 16, 25),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 15),
                const Text(
                  "Privacy Policy",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, "Introduction"),
                  _card(
                    context,
                    "Welcome to Medico. Your privacy is very important to us. "
                    "This Privacy Policy explains how we collect, use, and protect your information when you use our app.",
                  ),

                  _sectionTitle(context, "Information We Collect"),
                  _card(
                    context,
                    "• Personal Information (Name, Phone, Email)\n"
                    "• Profile details\n"
                    "• Service usage data\n"
                    "• Device and log information",
                  ),

                  _sectionTitle(context, "How We Use Your Information"),
                  _card(
                    context,
                    "• To provide and improve our services\n"
                    "• To connect users with caregivers\n"
                    "• To send notifications and updates\n"
                    "• To ensure platform safety and security",
                  ),

                  _sectionTitle(context, "Data Sharing"),
                  _card(
                    context,
                    "We do not sell your personal data. Your information is only shared with:\n"
                    "• Caregivers you connect with\n"
                    "• Legal authorities (if required)\n"
                    "• Internal service improvements",
                  ),

                  _sectionTitle(context, "Data Security"),
                  _card(
                    context,
                    "We implement strong security measures to protect your data. "
                    "However, no system is 100% secure, so we encourage users to keep their credentials safe.",
                  ),

                  _sectionTitle(context, "Your Rights"),
                  _card(
                    context,
                    "You have the right to:\n"
                    "• Access your data\n"
                    "• Update your information\n"
                    "• Request account deletion",
                  ),

                  _sectionTitle(context, "Changes to Policy"),
                  _card(
                    context,
                    "We may update this Privacy Policy from time to time. "
                    "Users will be notified of major changes.",
                  ),

                  _sectionTitle(context, "Contact Us"),
                  _card(
                    context,
                    "If you have any questions, contact us at:\n\nsupport@medico.com",
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Widget _sectionTitle(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
          )
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: isDark ? Colors.grey[300] : Colors.black87,
        ),
      ),
    );
  }
}