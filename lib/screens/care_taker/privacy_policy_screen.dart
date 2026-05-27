import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = [
    _S("Introduction", Icons.info_rounded,
        "Welcome to MEDICO. This Privacy Policy explains how we collect, use, store, and protect your personal information as a registered Caretaker on our platform. By using the app, you agree to the practices described here."),

    _S("Information We Collect", Icons.storage_rounded, null, bullets: [
      "Full name, phone number, and email address",
      "Government ID details (Aadhaar, PAN)",
      "Profile photo and professional qualifications",
      "Bank account / payment information",
      "GPS location during active bookings",
      "Device info, IP address, and app usage logs",
      "In-app chat and call metadata",
    ]),

    _S("Why We Collect Your Data", Icons.manage_search_rounded, null, bullets: [
      "To verify your identity and eligibility as a caretaker",
      "To match you with nearby care seekers",
      "To process earnings and payouts securely",
      "To enable GPS tracking during active bookings",
      "To send booking alerts and platform notifications",
      "To investigate complaints, disputes, or fraud",
      "To improve platform safety and service quality",
    ]),

    _S("Location & GPS Tracking", Icons.location_on_rounded,
        "MEDICO tracks your location during active bookings only. This data is used to verify arrival, monitor service delivery, and resolve disputes. Location spoofing is strictly prohibited and may result in a permanent ban."),

    _S("Data Sharing Policy", Icons.share_rounded, null, bullets: [
      "We NEVER sell your personal information to third parties.",
      "Data shared only with: assigned care seekers (name, rating, service info), payment processors for payouts, and law enforcement if legally required.",
      "Internal teams access data only for operations, safety, and fraud prevention.",
    ]),

    _S("Payment & Financial Data", Icons.account_balance_rounded,
        "Your bank account and UPI details are stored with encryption. Payout records are maintained for audit and tax compliance. MEDICO does not share financial data with third parties except authorized payment processors."),

    _S("Document & ID Security", Icons.verified_user_rounded,
        "Uploaded government ID documents are stored on secure, encrypted servers. Access is restricted to authorized MEDICO verification staff only. Documents are not shared publicly or with patients."),

    _S("Communications & Monitoring", Icons.headset_mic_rounded,
        "In-app chat messages and call logs may be monitored or recorded for safety, quality assurance, and dispute resolution. By using the platform, you consent to this monitoring as outlined in your caretaker agreement."),

    _S("Data Retention", Icons.history_rounded, null, bullets: [
      "Active account data is retained for the duration of your registration.",
      "After account deletion, data may be kept up to 90 days for legal compliance.",
      "Booking history and transaction records may be retained for up to 5 years.",
      "Complaint and investigation records may be retained indefinitely.",
    ]),

    _S("Your Rights", Icons.shield_rounded, null, bullets: [
      "Access and review your personal data anytime via the app.",
      "Update your profile information at any time.",
      "Request correction of inaccurate data.",
      "Request account deletion (subject to outstanding obligations).",
      "Opt out of non-essential marketing communications.",
    ]),

    _S("Data Security Measures", Icons.lock_rounded,
        "We use industry-standard encryption, secure servers, and access controls to protect your data. While we employ the best security practices, you are also responsible for keeping your login credentials confidential."),

    _S("Third-Party Services", Icons.extension_rounded,
        "MEDICO uses third-party services such as Razorpay (payments), Cloudinary (media storage), and Google Maps (location). These services have their own privacy policies. MEDICO is not liable for their data practices."),

    _S("Children's Privacy", Icons.child_care_rounded,
        "MEDICO does not knowingly collect data from individuals under the age of 18. Caretaker registration requires you to be at least 18 years old. If we discover underage accounts, they will be removed immediately."),

    _S("Policy Updates", Icons.update_rounded,
        "This Privacy Policy may be updated periodically. You will be notified of significant changes via the app or email. Continued use of the platform after updates constitutes acceptance of the revised policy."),

    _S("Contact Us", Icons.mail_rounded,
        "For any privacy-related concerns, data requests, or complaints, please contact our support team at support@medico.com. We aim to respond to all privacy inquiries within 5 business days."),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(context),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          itemCount: _sections.length + 2, // +intro card +footer
          itemBuilder: (ctx, i) {
            if (i == 0) return _introBanner(isDark);
            if (i == _sections.length + 1) return _contactFooter(isDark);
            return _card(_sections[i - 1], isDark);
          },
        )),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16, right: 16, bottom: 26,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Privacy Policy",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text("Caretaker · 15 Sections",
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
      ])),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 20),
      ),
    ]),
  );

  // ── Intro banner ──────────────────────────────────────────────────────────
  Widget _introBanner(bool isDark) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.20)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_rounded, color: AppColors.primary, size: 18),
      const SizedBox(width: 10),
      const Expanded(child: Text(
        "This policy applies to all registered Caretakers on MEDICO. "
        "Please read all sections carefully. Last updated: April 2026.",
        style: TextStyle(fontSize: 12.5, height: 1.55),
      )),
    ]),
  );

  // ── Section card ──────────────────────────────────────────────────────────
  Widget _card(_S s, bool isDark) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      boxShadow: isDark ? [] : AppColors.cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Card header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(s.icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Text(s.title, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
      // Content
      Padding(
        padding: const EdgeInsets.all(14),
        child: s.bullets != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: s.bullets!.map((b) => _bullet(b, isDark)).toList())
            : Text(s.body!, style: TextStyle(
                fontSize: 13.5, height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87)),
      ),
    ]),
  );

  Widget _bullet(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Container(width: 6, height: 6,
          decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: AppColors.gradient)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(
        fontSize: 13.5, height: 1.5,
        color: isDark ? Colors.white70 : Colors.black87))),
    ]),
  );

  // ── Contact footer ────────────────────────────────────────────────────────
  Widget _contactFooter(bool isDark) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppColors.glowShadow,
    ),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: const Icon(Icons.mail_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Privacy concerns or data requests?",
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(height: 3),
        Text("support@medico.com",
            style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.bold)),
      ]),
    ]),
  );
}

// ── Data model ────────────────────────────────────────────────────────────────
class _S {
  final String title;
  final IconData icon;
  final String? body;
  final List<String>? bullets;
  const _S(this.title, this.icon, this.body, {this.bullets});
}