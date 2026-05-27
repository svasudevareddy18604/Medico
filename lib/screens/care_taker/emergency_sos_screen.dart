import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medico/utils/app_colors.dart';

class EmergencySOSScreen extends StatelessWidget {
  const EmergencySOSScreen({super.key});

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse("tel:$number");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
        "https://wa.me/919652296548?text=Emergency%20SOS%20from%20MEDICO%20caretaker");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareLocation(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Live location sharing feature coming soon"),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _reportUnsafeHome(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Report Unsafe Home", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "Your safety report will be sent to the MEDICO emergency team immediately."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text("Emergency report submitted"),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              },
              child: const Text("Submit"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: danger ? AppColors.danger : Colors.black87)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4)),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _quickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(children: [

        // ── APP-STYLE CURVED HEADER ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 28),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(children: [
            // top row — back + title
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text("Emergency SOS",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.sos_rounded, color: Colors.white, size: 20),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SOS ALERT BANNER (red accent inside app-coloured header) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.danger.withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Emergency Assistance",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text("Use only for urgent medical, safety,\nor abuse situations.",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),

        // ── SCROLLABLE BODY ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              const Text("Emergency Actions",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),

              _actionCard(
                context: context,
                icon: Icons.call_rounded,
                title: "Call Emergency Support",
                subtitle: "Instantly contact MEDICO emergency assistance team.",
                danger: true,
                onTap: () => _callNumber("9652296548"),
              ),
              _actionCard(
                context: context,
                icon: Icons.chat_rounded,
                title: "Emergency WhatsApp",
                subtitle: "Quickly connect with support through WhatsApp.",
                onTap: _openWhatsApp,
              ),
              _actionCard(
                context: context,
                icon: Icons.location_on_rounded,
                title: "Share Live Location",
                subtitle: "Share your current location with emergency support.",
                onTap: () => _shareLocation(context),
              ),
              _actionCard(
                context: context,
                icon: Icons.warning_amber_rounded,
                title: "Report Unsafe Home",
                subtitle: "Report harassment, abuse, violence, or unsafe conditions.",
                danger: true,
                onTap: () => _reportUnsafeHome(context),
              ),
              _actionCard(
                context: context,
                icon: Icons.medical_services_rounded,
                title: "Medical Emergency",
                subtitle: "Patient collapsed, unconscious, or severe condition.",
                danger: true,
                onTap: () => _callNumber("108"),
              ),

              const SizedBox(height: 24),

              const Text("Quick Emergency Contacts",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),

              Row(children: [
                Expanded(
                  child: _quickButton(
                      icon: Icons.local_police_rounded,
                      label: "Police",
                      color: Colors.blue,
                      onTap: () => _callNumber("100")),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickButton(
                      icon: Icons.local_hospital_rounded,
                      label: "Ambulance",
                      color: Colors.red,
                      onTap: () => _callNumber("108")),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _quickButton(
                      icon: Icons.support_agent_rounded,
                      label: "Support",
                      color: Colors.green,
                      onTap: () => _callNumber("9652296548")),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}