import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      "q": "How do I register as a Caretaker on MEDICO?",
      "a": "Download the app, select 'Register as Caretaker', fill in your personal details, upload required documents (Aadhaar, certifications), and submit for verification. Our team reviews your profile within 24–48 hours.",
    },
    {
      "q": "What documents are required for registration?",
      "a": "You need a valid government ID (Aadhaar/PAN/Driving License), professional qualification certificates, a recent passport-size photo, and bank account details for payouts.",
    },
    {
      "q": "How long does profile approval take?",
      "a": "Profile verification typically takes 24 to 48 working hours. You will receive a push notification and email once your account is approved or if additional documents are needed.",
    },
    {
      "q": "How do I receive and accept job orders?",
      "a": "Once approved, new job requests appear on your Home screen. Review the booking details, patient location, and service type, then tap 'Accept' to confirm. You must respond before the request expires.",
    },
    {
      "q": "How are my earnings calculated and paid?",
      "a": "Earnings are calculated per completed booking. Payouts are processed directly to your registered bank account. You can view your full earnings history and pending amounts in the Earnings section.",
    },
    {
      "q": "When can I withdraw my earnings?",
      "a": "You can request a withdrawal anytime from the Earnings screen. Withdrawals are processed within 1–3 working days depending on your bank.",
    },
    {
      "q": "What happens if I need to cancel a booking?",
      "a": "Cancellations are only allowed for genuine emergencies (medical, accident, natural disaster). Repeated or invalid cancellations will reduce your account rating. 3 last-minute cancellations within 30 days may result in a temporary block.",
    },
    {
      "q": "How does GPS tracking work during a booking?",
      "a": "Location tracking is active during all assigned bookings. This helps verify your arrival, monitor service delivery, and protect both you and the patient. Location spoofing is strictly prohibited.",
    },
    {
      "q": "How do I mark a booking as started or completed?",
      "a": "On the active booking screen, tap 'Start Service' upon arrival and 'Complete Service' once the session ends. Always mark accurately — fake completions are a serious violation.",
    },
    {
      "q": "What should I do in a patient emergency?",
      "a": "Immediately call emergency services (112), inform the patient's family, and notify MEDICO support via the app. Your safety and the patient's safety are the top priority.",
    },
    {
      "q": "How do ratings and reviews work?",
      "a": "After each completed booking, the care seeker can rate and review your service. Maintaining a high rating increases your visibility and booking frequency. Consistently poor ratings may affect your account status.",
    },
    {
      "q": "Can I update my availability or service area?",
      "a": "Yes. Go to Settings → Profile to update your availability schedule, service radius, and the types of services you offer. Keep this updated to receive relevant booking requests.",
    },
    {
      "q": "What are the rules around patient privacy?",
      "a": "You must never share patient photos, medical information, or personal details with anyone. Recording videos or conversations without consent is strictly prohibited and may result in permanent ban.",
    },
    {
      "q": "What happens if a patient files a complaint?",
      "a": "MEDICO will investigate all complaints fairly. You will be notified and asked to provide your account of events. Cooperate fully — refusing to respond may lead to account suspension.",
    },
    {
      "q": "How do I contact MEDICO support?",
      "a": "You can reach us via email at support@medico.com or call +91 98765 43210. Our support team is available 24/7 including weekends and public holidays.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(context),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            _introBanner(isDark),
            const SizedBox(height: 18),
            _sectionLabel("Frequently Asked Questions", isDark),
            const SizedBox(height: 12),
            ..._faqs.map((f) => _faqItem(context, f["q"]!, f["a"]!, isDark)),
            const SizedBox(height: 24),
            _sectionLabel("Contact & Support", isDark),
            const SizedBox(height: 12),
            _contactCard(Icons.email_rounded,      "Email Support",  "support@medico.com", "Replies within 2 hrs", isDark),
            const SizedBox(height: 10),
            _contactCard(Icons.phone_rounded,      "Call Us",        "+91 98765 43210",    "24 / 7 Available",     isDark),
          ],
        )),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16, right: 16, bottom: 24,
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
            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Help Center",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text("Caretaker · 15 FAQs",
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
      ])),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
        child: const Icon(Icons.help_rounded, color: Colors.white, size: 20),
      ),
    ]),
  );

  // ── Intro banner ──────────────────────────────────────────────────────────
  Widget _introBanner(bool isDark) => Container(
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
        "Find answers to common caretaker questions below. "
        "Can't find what you need? Reach our 24/7 support team directly.",
        style: TextStyle(fontSize: 12.5, height: 1.55),
      )),
    ]),
  );

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text, bool isDark) => Row(children: [
    Container(
      width: 3, height: 18,
      margin: const EdgeInsets.only(right: 9),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    Text(text, style: TextStyle(
      fontWeight: FontWeight.bold, fontSize: 15,
      color: isDark ? Colors.white : Colors.black87,
    )),
  ]);

  // ── FAQ item ──────────────────────────────────────────────────────────────
  Widget _faqItem(BuildContext context, String question, String answer, bool isDark) =>
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.muted,
          leading: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.help_rounded, color: Colors.white, size: 17),
          ),
          title: Text(question, style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13.5,
            color: isDark ? Colors.white : Colors.black87,
          )),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(answer, style: TextStyle(
                fontSize: 13.5, height: 1.65,
                color: isDark ? Colors.white70 : const Color(0xFF444444),
              )),
            ),
          ],
        ),
      ),
    );

  // ── Contact card ──────────────────────────────────────────────────────────
  Widget _contactCard(IconData icon, String title, String detail, String badge, bool isDark) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.glowShadow,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          )),
          const SizedBox(height: 3),
          Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge, style: const TextStyle(
            color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
}