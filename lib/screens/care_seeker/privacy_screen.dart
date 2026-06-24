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
                const Expanded(
                  child: Text(
                    "Privacy Policy",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Privacy",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lastUpdatedBanner(isDark),
                  const SizedBox(height: 18),

                  _section(
                    context,
                    icon: Icons.waving_hand_rounded,
                    title: "1. Introduction",
                    body:
                        "Welcome to Medico. Your privacy matters to us. This Privacy Policy explains what "
                        "information we collect, how we use it, who we share it with, and the choices you "
                        "have when using our app. By using Medico, you consent to the practices described "
                        "in this policy.",
                  ),

                  _section(
                    context,
                    icon: Icons.folder_shared_rounded,
                    title: "2. Information We Collect",
                    bullets: const [
                      "Personal details — name, phone number, email address",
                      "Profile information — photo, address, and saved preferences",
                      "Location data — to find nearby caregivers and enable accurate service delivery",
                      "Service & booking history — appointments, schedules, and order details",
                      "Payment information — processed securely through third-party gateways; we do not store card or bank details",
                      "Device & log information — IP address, device model, app version, and crash logs",
                    ],
                  ),

                  _section(
                    context,
                    icon: Icons.settings_suggest_rounded,
                    title: "3. How We Use Your Information",
                    bullets: const [
                      "To create and manage your account",
                      "To connect care seekers with verified caregivers",
                      "To process bookings and facilitate payments",
                      "To send service updates, reminders, and notifications",
                      "To monitor and improve app performance and reliability",
                      "To detect, prevent, and address fraud or misuse",
                    ],
                  ),

                  _section(
                    context,
                    icon: Icons.my_location_rounded,
                    title: "4. Location Data",
                    body:
                        "Medico uses your device location to match you with nearby caregivers and to enable "
                        "caregivers to navigate to your service address. Location access can be managed at "
                        "any time through your device settings, though disabling it may limit certain "
                        "features of the app.",
                  ),

                  _section(
                    context,
                    icon: Icons.payments_rounded,
                    title: "5. Payment Information",
                    body:
                        "All online payments made through Medico are processed via secure, PCI-DSS "
                        "compliant third-party payment gateways. Medico does not collect, view, or store "
                        "your full card number, CVV, or banking credentials. Limited transaction metadata "
                        "(such as order ID and payment status) is retained for booking and support "
                        "purposes only.",
                  ),

                  _section(
                    context,
                    icon: Icons.share_rounded,
                    title: "6. How We Share Your Information",
                    body:
                        "We do not sell your personal data to third parties. Information may be shared "
                        "only in the following circumstances:",
                    bullets: const [
                      "With the caregiver or care seeker involved in a specific booking, to facilitate service delivery",
                      "With payment gateway partners, solely to process transactions",
                      "With legal or regulatory authorities, where required by law",
                      "Internally, for analytics and service improvement, in anonymized or aggregated form",
                    ],
                  ),

                  _section(
                    context,
                    icon: Icons.lock_rounded,
                    title: "7. Data Security",
                    body:
                        "We apply industry-standard safeguards — including encryption in transit, access "
                        "controls, and secure infrastructure — to protect your information from unauthorized "
                        "access, alteration, or disclosure. However, no method of transmission or storage is "
                        "completely secure, and we encourage you to keep your account credentials "
                        "confidential.",
                  ),

                  _section(
                    context,
                    icon: Icons.schedule_rounded,
                    title: "8. Data Retention",
                    body:
                        "We retain your personal information for as long as your account is active or as "
                        "needed to provide services, comply with legal obligations, resolve disputes, and "
                        "enforce our agreements. You may request deletion of your data at any time, subject "
                        "to legal and operational retention requirements.",
                  ),

                  _section(
                    context,
                    icon: Icons.fingerprint_rounded,
                    title: "9. Your Rights",
                    bullets: const [
                      "Access the personal data we hold about you",
                      "Correct or update inaccurate information",
                      "Request deletion of your account and associated data",
                      "Withdraw consent for location or notification permissions at any time",
                      "Object to certain uses of your data, where applicable",
                    ],
                  ),

                  _section(
                    context,
                    icon: Icons.child_care_rounded,
                    title: "10. Children's Privacy",
                    body:
                        "Medico is intended for use by individuals aged 18 and above. We do not knowingly "
                        "collect personal information from minors. If we become aware that a minor's data "
                        "has been collected without appropriate consent, we will take steps to delete it "
                        "promptly.",
                  ),

                  _section(
                    context,
                    icon: Icons.update_rounded,
                    title: "11. Changes to This Policy",
                    body:
                        "We may update this Privacy Policy periodically to reflect changes in our practices "
                        "or legal requirements. Material changes will be communicated through the app, and "
                        "continued use after such updates constitutes acceptance of the revised policy.",
                  ),

                  _section(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: "12. Contact Us",
                    body:
                        "If you have questions, concerns, or requests regarding this Privacy Policy or your "
                        "personal data, please reach out to our support team.",
                    footer: const _ContactRow(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Last Updated Banner ─────────────────────────────────────────

  Widget _lastUpdatedBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Last updated: April 2026 — Your privacy and trust matter to us.",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Builder ─────────────────────────────────────────────

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? body,
    List<String>? bullets,
    Widget? footer,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: Colors.grey.shade800)
            : null,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 3),
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (body != null)
            Text(
              body,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
          if (body != null && bullets != null) const SizedBox(height: 10),
          if (bullets != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bullets
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                b,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer,
          ],
        ],
      ),
    );
  }
}

// ── Contact Row Widget ────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  const _ContactRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contactItem(
          context,
          icon: Icons.email_rounded,
          text: "support@medico.com",
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _contactItem(
          context,
          icon: Icons.language_rounded,
          text: "www.medico.com",
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _contactItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[200] : Colors.black87,
          ),
        ),
      ],
    );
  }
}