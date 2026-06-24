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
                const Expanded(
                  child: Text(
                    "Terms & Conditions",
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
                      Icon(Icons.gavel_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Legal",
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
                    icon: Icons.handshake_rounded,
                    title: "1. Acceptance of Terms",
                    body:
                        "By accessing or using the Medico app, you agree to be legally bound by these "
                        "Terms & Conditions and our Privacy Policy. If you do not agree with any part of "
                        "these terms, please discontinue use of the app immediately.",
                  ),

                  _section(
                    context,
                    icon: Icons.medical_services_rounded,
                    title: "2. Description of Services",
                    body:
                        "Medico is a platform that connects care seekers with independent caregivers and "
                        "caretaker professionals for home-based care services. Medico acts solely as a "
                        "facilitator and is not a direct provider of medical or caregiving services.",
                  ),

                  _section(
                    context,
                    icon: Icons.how_to_reg_rounded,
                    title: "3. Eligibility & Account Registration",
                    body:
                        "You must be at least 18 years old and legally capable of entering into binding "
                        "contracts to use this app. You agree to provide accurate, current, and complete "
                        "information during registration and to keep your login credentials confidential. "
                        "You are responsible for all activity that occurs under your account.",
                  ),

                  _section(
                    context,
                    icon: Icons.rule_rounded,
                    title: "4. User Responsibilities",
                    bullets: const [
                      "Provide accurate personal, contact, and location details",
                      "Treat caregivers, caretakers, and staff with respect",
                      "Do not use the platform for any unlawful or fraudulent purpose",
                      "Do not attempt to bypass, exploit, or abuse the app's systems",
                      "Comply with all applicable local, state, and national laws",
                    ],
                  ),

                  _section(
                    context,
                    icon: Icons.verified_user_rounded,
                    title: "5. Caregiver & Caretaker Conduct",
                    body:
                        "Caregivers and caretakers onboarded through Medico are required to undergo "
                        "verification, including identity and document checks. However, Medico does not "
                        "guarantee the conduct, qualifications, or performance of any individual caregiver "
                        "beyond the verification steps completed at onboarding.",
                  ),

                  _section(
                    context,
                    icon: Icons.payments_rounded,
                    title: "6. Bookings & Payments",
                    bullets: const [
                      "All service bookings must be confirmed and scheduled through the app",
                      "Payments may be made online via approved payment partners, or as Cash on Delivery where available",
                      "Online payments are processed securely through third-party payment gateways; Medico does not store your card or banking details",
                      "Prices displayed at checkout are final and inclusive of applicable service charges unless stated otherwise",
                    ],
                  ),

                  _section(
                    context,
                    icon: Icons.replay_circle_filled_rounded,
                    title: "7. Cancellation & Refund Policy",
                    body:
                        "Bookings may be cancelled within the time window specified at the time of booking. "
                        "Refunds, where applicable, will be processed to the original payment method within "
                        "a reasonable timeframe and are subject to our refund policy. Cancellations made "
                        "after a caregiver has been dispatched or has begun service may not be eligible for "
                        "a full refund.",
                  ),

                  _section(
                    context,
                    icon: Icons.privacy_tip_rounded,
                    title: "8. Privacy & Data Use",
                    body:
                        "Your personal information, including location and health-related details shared "
                        "for service purposes, is handled in accordance with our Privacy Policy. We use "
                        "this data solely to facilitate bookings, improve our services, and ensure safety "
                        "and accountability on the platform.",
                  ),

                  _section(
                    context,
                    icon: Icons.shield_moon_rounded,
                    title: "9. Limitation of Liability",
                    body:
                        "Medico functions as an intermediary platform and is not liable for any direct, "
                        "indirect, incidental, or consequential damages arising from the use of services "
                        "booked through the app, including but not limited to the quality of care provided "
                        "by independent caregivers. Use of the platform is at your own discretion and risk.",
                  ),

                  _section(
                    context,
                    icon: Icons.block_rounded,
                    title: "10. Account Suspension & Termination",
                    body:
                        "Medico reserves the right to suspend, restrict, or terminate any account found to "
                        "be in violation of these Terms, engaging in fraudulent activity, or posing a risk "
                        "to other users, without prior notice.",
                  ),

                  _section(
                    context,
                    icon: Icons.report_problem_rounded,
                    title: "11. Dispute Resolution",
                    body:
                        "Any disputes arising out of or relating to the use of this app shall first be "
                        "addressed through our customer support. Should resolution not be reached, disputes "
                        "shall be subject to the exclusive jurisdiction of the courts located in Bengaluru, "
                        "Karnataka, India.",
                  ),

                  _section(
                    context,
                    icon: Icons.update_rounded,
                    title: "12. Changes to These Terms",
                    body:
                        "We may revise these Terms & Conditions from time to time to reflect changes in our "
                        "services or legal requirements. Continued use of the app after any update "
                        "constitutes your acceptance of the revised terms.",
                  ),

                  _section(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: "13. Contact Us",
                    body:
                        "If you have any questions, concerns, or feedback regarding these Terms & "
                        "Conditions, please reach out to our support team.",
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
              "Last updated: April 2026 — Please read carefully before using Medico.",
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