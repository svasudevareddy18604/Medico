import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
              child: Column(
                children: [
                  _buildLogoCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.info_outline_rounded,
                    title: "About Medico",
                    content:
                        "Medico is a modern healthcare service platform designed to bridge the gap between care seekers and trusted caregivers. "
                        "We believe quality healthcare should be accessible to everyone — from the comfort of your home.\n\n"
                        "Our platform empowers users to find, verify, and book professional caregivers within minutes, "
                        "with complete transparency in pricing, availability, and service quality.",
                  ),
                  _buildSection(
                    icon: Icons.medical_services_outlined,
                    title: "Our Services",
                    bullets: [
                      "🏥  Home nursing & medical care",
                      "👴  Elderly care & companionship",
                      "🤱  Babysitting & child care",
                      "🦽  Post-hospitalization support",
                      "💊  Medication management",
                      "🚑  Emergency care assistance",
                      "🧘  Physiotherapy at home",
                      "🧹  Non-medical daily assistance",
                    ],
                  ),
                  _buildSection(
                    icon: Icons.star_outline_rounded,
                    title: "Key Features",
                    bullets: [
                      "✅  Verified & background-checked caregivers",
                      "📍  Real-time caregiver tracking",
                      "📅  Flexible scheduling & booking",
                      "🔔  Instant notifications & reminders",
                      "⭐  Ratings, reviews & feedback system",
                      "💬  Live in-app support chat",
                      "🔒  Secure login & data protection",
                      "🎟️  Coupon codes & special offers",
                      "📦  Easy order history & re-booking",
                    ],
                  ),
                  _buildSection(
                    icon: Icons.shield_outlined,
                    title: "Safety & Trust",
                    content:
                        "Every caregiver on Medico goes through a thorough background verification and credential check before being listed on our platform. "
                        "We maintain strict quality standards and continuously monitor service quality through user feedback.\n\n"
                        "Your personal data is encrypted and stored securely. We never share your information with third parties without your consent.",
                  ),
                  _buildSection(
                    icon: Icons.workspace_premium_outlined,
                    title: "Why Choose Medico?",
                    bullets: [
                      "🏆  Trusted by thousands of families",
                      "⚡  Book a caregiver in under 2 minutes",
                      "💰  Transparent & affordable pricing",
                      "🕐  24/7 caregiver availability",
                      "📞  Dedicated customer support team",
                      "🔄  Easy cancellation & rescheduling",
                      "📱  Simple & intuitive mobile experience",
                    ],
                  ),
                  _buildSection(
                    icon: Icons.groups_outlined,
                    title: "Our Mission",
                    content:
                        "To make professional home healthcare accessible, affordable, and reliable for every family — ensuring that your loved ones receive the best care, wherever they are.",
                  ),
                  _buildContactCard(),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
  return Container(
    padding: const EdgeInsets.fromLTRB(4, 10, 20, 20),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(30),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.3),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              "About App",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  // ── LOGO CARD ────────────────────────────────────────────────────
  Widget _buildLogoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05))],
      ),
      child: Column(
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 16, color: AppColors.primary.withOpacity(0.2))],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset("assets/logo.png", fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text("MEDICO",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 5),
          Text("Healthcare Services at Home",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Text("Version 1.0.0",
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── STATS ROW ────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      {"value": "10K+", "label": "Users"},
      {"value": "500+", "label": "Caregivers"},
      {"value": "4.8★", "label": "Rating"},
      {"value": "24/7", "label": "Support"},
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.04))],
            ),
            child: Column(
              children: [
                Text(s["value"]!,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 3),
                Text(s["label"]!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── SECTION CARD ─────────────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    String? content,
    List<String>? bullets,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.04))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade100, thickness: 1.2),
          const SizedBox(height: 4),

          // Content
          if (content != null)
            Text(content,
                style: TextStyle(
                    fontSize: 13.5, height: 1.6, color: Colors.grey.shade800)),

          // Bullets
          if (bullets != null)
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(b,
                      style: TextStyle(
                          fontSize: 13.5, height: 1.5, color: Colors.grey.shade800)),
                )),
        ],
      ),
    );
  }

  // ── CONTACT CARD ─────────────────────────────────────────────────
  Widget _buildContactCard() {
    final contacts = [
      {"icon": Icons.email_outlined,    "label": "Email",   "value": "support@medico.com"},
      {"icon": Icons.phone_outlined,    "label": "Phone",   "value": "+91 9876543210"},
      {"icon": Icons.language_outlined, "label": "Website", "value": "www.medico.com"},
      {"icon": Icons.location_on_outlined, "label": "Office", "value": "Bengaluru, Karnataka, India"},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.04))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.contact_support_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("Contact & Support",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade100, thickness: 1.2),
          const SizedBox(height: 4),
          ...contacts.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(c["icon"] as IconData, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c["label"] as String,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500)),
                        Text(c["value"] as String,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── FOOTER ───────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text("© 2026 Medico Healthcare Services. All rights reserved.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 6),
        Text("Made with ❤️ for better healthcare access",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ],
    );
  }
}