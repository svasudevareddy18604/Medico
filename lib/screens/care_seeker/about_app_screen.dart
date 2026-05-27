import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});
  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  bool get isDark => themeNotifier.value == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _header(context),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          child: Column(children: [
            _logoCard(),
            const SizedBox(height: 14),
            _statsRow(),
            const SizedBox(height: 14),
            _section(Icons.info_outline_rounded, "About Medico",
                content: "Medico bridges the gap between care seekers and trusted caregivers. "
                    "Book professional home healthcare in minutes — with complete transparency in pricing, availability, and quality."),
            _section(Icons.medical_services_outlined, "Our Services", bullets: const [
              "🏥  Home nursing & medical care",
              "👴  Elderly care & companionship",
              "🤱  Babysitting & child care",
              "🦽  Post-hospitalization support",
              "🧘  Physiotherapy at home",
              "🧹  Non-medical daily assistance",
            ]),
            _section(Icons.star_outline_rounded, "Key Features", bullets: const [
              "✅  Verified & background-checked caregivers",
              "📍  Real-time caregiver tracking",
              "📅  Flexible scheduling & booking",
              "🔒  Secure login & data protection",
              "🎟️  Coupon codes & special offers",
            ]),
            _section(Icons.shield_outlined, "Safety & Trust",
                content: "Every caregiver undergoes thorough background verification before listing. "
                    "Your personal data is encrypted and stored securely — never shared without your consent."),
            _section(Icons.workspace_premium_outlined, "Why Medico?", bullets: const [
              "🏆  Trusted by thousands of families",
              "⚡  Book a caregiver in under 2 minutes",
              "💰  Transparent & affordable pricing",
              "🕐  24/7 caregiver availability",
            ]),
            _contactCard(),
            const SizedBox(height: 20),
            _footer(),
          ]),
        )),
      ]),
    );
  }

  Widget _header(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 10, 20, 20),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 5))],
    ),
    child: SafeArea(bottom: false, child: Row(children: [
      IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
      ),
      const Expanded(child: Text("About App",
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
    ])),
  );

  Widget _logoCard() {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : Colors.transparent;
    final nameColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
          boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(isDark ? 0.25 : 0.05))]),
      child: Column(children: [
        Container(width: 88, height: 88,
          decoration: BoxDecoration(shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 18, color: AppColors.primary.withOpacity(0.22))]),
          child: ClipOval(child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset("assets/logo.png", fit: BoxFit.contain),
          )),
        ),
        const SizedBox(height: 14),
        Text("MEDICO", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            letterSpacing: 2.5, color: nameColor)),
        const SizedBox(height: 4),
        Text("Healthcare Services at Home", style: TextStyle(color: subColor, fontSize: 13)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3))),
          child: Text("Version 1.0.0",
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _statsRow() {
    final stats = [("10K+", "Users"), ("500+", "Caregivers"), ("4.8★", "Rating"), ("24/7", "Support")];
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : Colors.transparent;
    final subColor = isDark ? const Color(0xFF64748B) : Colors.grey.shade500;
    return Row(children: stats.map((s) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
            boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(isDark ? 0.2 : 0.04))]),
        child: Column(children: [
          Text(s.$1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 3),
          Text(s.$2, style: TextStyle(fontSize: 11, color: subColor)),
        ]),
      ),
    )).toList());
  }

  Widget _section(IconData icon, String title, {String? content, List<String>? bullets}) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : Colors.transparent;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800;
    final divColor = isDark ? const Color(0xFF334155) : Colors.grey.shade100;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(isDark ? 0.22 : 0.04))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primary, size: 20)),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor)),
        ]),
        const SizedBox(height: 4),
        Divider(color: divColor, thickness: 1),
        const SizedBox(height: 4),
        if (content != null) Text(content,
            style: TextStyle(fontSize: 13.5, height: 1.65, color: bodyColor)),
        if (bullets != null) ...bullets.map((b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(b, style: TextStyle(fontSize: 13.5, height: 1.5, color: bodyColor)),
        )),
      ]),
    );
  }

  Widget _contactCard() {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : Colors.transparent;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? const Color(0xFF64748B) : Colors.grey.shade500;
    final valueColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final divColor = isDark ? const Color(0xFF334155) : Colors.grey.shade100;

    final contacts = [
      (Icons.email_outlined, "Email", "support@medico.com"),
      (Icons.phone_outlined, "Phone", "+91 9876543210"),
      (Icons.language_outlined, "Website", "www.medico.com"),
      (Icons.location_on_outlined, "Office", "Bengaluru, Karnataka, India"),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(isDark ? 0.22 : 0.04))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.contact_support_outlined, color: AppColors.primary, size: 20)),
          const SizedBox(width: 12),
          Text("Contact & Support", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor)),
        ]),
        const SizedBox(height: 4),
        Divider(color: divColor, thickness: 1),
        const SizedBox(height: 4),
        ...contacts.map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(c.$1, color: AppColors.primary, size: 20),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.$2, style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500)),
              Text(c.$3, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: valueColor)),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _footer() {
    final divColor = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final c1 = isDark ? const Color(0xFF64748B) : Colors.grey.shade500;
    final c2 = isDark ? const Color(0xFF475569) : Colors.grey.shade400;
    return Column(children: [
      Divider(color: divColor),
      const SizedBox(height: 10),
      Text("© 2026 Medico Healthcare Services. All rights reserved.",
          textAlign: TextAlign.center, style: TextStyle(color: c1, fontSize: 12)),
      const SizedBox(height: 5),
      Text("Made with ❤️ for better healthcare access",
          style: TextStyle(color: c2, fontSize: 11)),
    ]);
  }
}