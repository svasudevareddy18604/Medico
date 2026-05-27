import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.vertical(
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
                  "Terms & Conditions",
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
                  _sectionTitle(context, "Acceptance of Terms"),
                  _card(
                    context,
                    "By using the Medico app, you agree to comply with and be bound by these Terms & Conditions. "
                    "If you do not agree, please do not use our services.",
                  ),

                  _sectionTitle(context, "Use of Services"),
                  _card(
                    context,
                    "Medico provides a platform to connect care seekers with caregivers. "
                    "Users must provide accurate information and use the app responsibly.",
                  ),

                  _sectionTitle(context, "User Responsibilities"),
                  _card(
                    context,
                    "• Provide correct personal details\n"
                    "• Respect caregivers and other users\n"
                    "• Do not misuse the platform\n"
                    "• Follow all applicable laws",
                  ),

                  _sectionTitle(context, "Bookings & Payments"),
                  _card(
                    context,
                    "• All bookings must be confirmed through the app\n"
                    "• Payments should be completed using approved methods\n"
                    "• Cancellation policies may apply",
                  ),

                  _sectionTitle(context, "Cancellation & Refund"),
                  _card(
                    context,
                    "Cancellations must be made within the allowed time. "
                    "Refunds will be processed based on our refund policy.",
                  ),

                  _sectionTitle(context, "Limitation of Liability"),
                  _card(
                    context,
                    "Medico is not responsible for any direct or indirect damages arising from the use of services. "
                    "We act only as a platform connecting users.",
                  ),

                  _sectionTitle(context, "Account Termination"),
                  _card(
                    context,
                    "We reserve the right to suspend or terminate accounts that violate our policies without prior notice.",
                  ),

                  _sectionTitle(context, "Changes to Terms"),
                  _card(
                    context,
                    "We may update these Terms & Conditions at any time. "
                    "Continued use of the app means you accept the updated terms.",
                  ),

                  _sectionTitle(context, "Contact Us"),
                  _card(
                    context,
                    "For any questions regarding these terms, contact us at:\n\nsupport@medico.com",
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