import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(context),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            _intro(isDark),
            const SizedBox(height: 20),

            _section(isDark, "1. Eligibility Requirements", Icons.verified_user_rounded, [
              "Must be minimum 18 years of age.",
              "Must provide valid government-issued ID proof.",
              "Must provide real phone number and residential address.",
              "Fake identity will result in a permanent ban.",
              "Caretaker must be legally authorized to work in India.",
              "MEDICO reserves the right to reject registration without explanation.",
            ]),

            _section(isDark, "2. Background Verification", Icons.verified_user_rounded, [
              "MEDICO may verify Aadhaar, PAN, or Driving License.",
              "Police verification may be required for onboarding.",
              "Criminal history can lead to immediate rejection.",
              "Submission of fake documents results in permanent blacklisting.",
              "Caretaker agrees to background verification checks at any time.",
            ]),

            _section(isDark, "3. Profile Accuracy", Icons.badge_rounded, [
              "All profile information must be genuine and up to date.",
              "Fake or exaggerated experience is strictly prohibited.",
              "Fake or stolen profile photos are not allowed.",
              "Duplicate accounts are prohibited.",
              "Wrong specialization or misleading details may result in account suspension.",
              "❌ BAD: Claiming ICU experience without certification.",
              "✅ GOOD: Mentioning "
            ]),

            _section(isDark, "4. Service Conduct Rules", Icons.handshake_rounded, [
              "Caretaker MUST: behave respectfully, maintain hygiene, wear proper dress, arrive on time, speak professionally, and follow patient instructions carefully.",
              "Caretaker must NOT: smoke or drink during duty, fight with patients or family, use drugs or alcohol, harass anyone, sleep during active duty, or bring outsiders to the patient's location.",
            ]),

            _section(isDark, "5. Patient Safety Rules", Icons.health_and_safety_rounded, [
              "Caretaker must prioritize patient safety at all times.",
              "Negligence causing harm may result in legal action.",
              "Incorrect medicine administration is solely the caretaker's responsibility.",
              "Physical abuse leads to immediate termination.",
              "Theft or misconduct will be reported to police.",
              "❌ Critical: Giving wrong medicine or leaving elderly patient unattended.",
            ]),

            _section(isDark, "6. Attendance & Punctuality", Icons.schedule_rounded, [
              "Repeated late arrivals will reduce account rating.",
              "No-shows may lead to financial penalties.",
              "Continuous cancellations may result in account suspension.",
              "Caretaker must keep availability updated at all times.",
              "3 last-minute cancellations within 30 days = temporary block.",
              "5 severe violations = permanent ban.",
            ]),

            _section(isDark, "7. Cancellation Policy", Icons.cancel_rounded, [
              "Caretaker CANNOT cancel: after reaching the location, during emergency bookings, or repeatedly without a valid reason.",
              "✅ Valid reasons: medical emergency, accident, or natural disaster.",
              "❌ Invalid reasons: 'Not interested', 'Too far', or 'Got another booking'.",
            ]),

            _section(isDark, "8. Payment & Earnings", Icons.payments_rounded, [
              "All earnings are processed only through the MEDICO platform.",
              "Collecting cash outside the app is strictly prohibited.",
              "Platform commission may apply on each completed booking.",
              "Fraudulent payment activity leads to immediate suspension.",
              "MEDICO can hold payments during active investigations.",
            ]),

            _section(isDark, "9. COD Abuse Protection", Icons.shield_rounded, [
              "Excessive cancellations by caretaker may disable COD booking eligibility.",
              "Fraudulent order acceptance may result in payout hold.",
              "Fake service completion leads to permanent removal from platform.",
            ]),

            _section(isDark, "10. Location & GPS Tracking", Icons.location_on_rounded, [
              "Caretaker agrees to GPS tracking during all active bookings.",
              "Fake GPS or location spoofing is strictly prohibited.",
              "Turning off location during an active service may negatively affect account standing.",
              "❌ Fraud: Marking 'arrived' from a different location.",
            ]),

            _section(isDark, "11. Emergency Situations", Icons.emergency_rounded, [
              "Caretaker must contact emergency services immediately if required.",
              "Patient relatives must be informed immediately in case of emergency.",
              "MEDICO support must be notified during all emergency situations.",
            ]),

            _section(isDark, "12. Medical Limitations", Icons.medical_information_rounded, [
              "Caretakers cannot perform medical procedures beyond their qualification.",
              "Non-certified caretakers cannot administer injections or advanced medical treatment.",
              "MEDICO is NOT responsible for unauthorized medical actions taken by caretakers.",
            ]),

            _section(isDark, "13. Ratings & Reviews", Icons.star_rounded, [
              "Poor ratings may reduce profile visibility in search results.",
              "Continuous negative reviews may result in account suspension.",
              "Fake review manipulation is strictly prohibited.",
            ]),

            _section(isDark, "14. Device & App Usage", Icons.phone_android_rounded, [
              "Caretaker is responsible for maintaining internet and mobile access.",
              "App misuse, hacking, or modification is prohibited.",
              "Sharing your account credentials with others is not allowed.",
            ]),

            _section(isDark, "15. Privacy & Confidentiality", Icons.privacy_tip_rounded, [
              "Caretaker must NOT share patient photos without consent.",
              "Leaking patient information is strictly prohibited.",
              "Recording videos at the patient's location without permission is not allowed.",
              "Sharing patient medical history publicly is a serious violation.",
            ]),

            _section(isDark, "16. Uniform & Identification", Icons.badge_rounded, [
              "Caretaker may be required to wear an ID badge during service.",
              "Proper grooming and professional appearance is mandatory.",
              "MEDICO branding rules may apply when on duty.",
            ]),

            _section(isDark, "17. Service Completion Fraud", Icons.task_alt_rounded, [
              "Marking a service as completed without finishing it is strictly prohibited.",
              "Leaving early but marking the booking as completed is fraud.",
              "Fake attendance entries may lead to a permanent ban.",
            ]),

            _section(isDark, "18. Commission & Penalties", Icons.account_balance_rounded, [
              "MEDICO may deduct penalties for severe misconduct.",
              "Refund liabilities may be adjusted from caretaker earnings.",
              "Fraud-related losses may be recovered through legal action.",
            ]),

            _section(isDark, "19. Suspension & Termination", Icons.block_rounded, [
              "MEDICO can suspend accounts for: fake documents, abuse, poor ratings, frequent cancellations, theft, patient complaints, fraud activity, or unsafe behavior.",
              "Permanent bans are not easily reversible and are at MEDICO's sole discretion.",
            ]),

            _section(isDark, "20. Legal Liability", Icons.gavel_rounded, [
              "Caretaker is fully responsible for their own actions during service.",
              "MEDICO acts solely as a technology platform connecting users.",
              "Serious misconduct may be reported to law enforcement authorities.",
              "Caretaker agrees to indemnify MEDICO against any misuse of the platform.",
            ]),

            _section(isDark, "21. Consent to Monitoring", Icons.monitor_rounded, [
              "Calls and in-app chats may be monitored for safety and quality.",
              "Booking history is stored securely as per our privacy policy.",
              "Complaint investigations may utilize chat history and location data.",
            ]),

            _section(isDark, "22. Prohibited Activities", Icons.do_not_disturb_on_rounded, [
              "Asking patients for extra money outside the app.",
              "Sharing personal payment QR codes with patients.",
              "Taking patients outside the app for repeat bookings.",
              "Promoting competitor platforms to patients.",
              "Religious, political, or personal harassment of any kind.",
              "Misleading patients about qualifications or services.",
            ]),

            _section(isDark, "23. Insurance Disclaimer", Icons.info_rounded, [
              "MEDICO does not currently guarantee medical insurance coverage for caretakers.",
              "If insurance coverage is added in the future, separate terms and coverage details will be communicated.",
            ]),

            _section(isDark, "24. Force Majeure", Icons.warning_amber_rounded, [
              "MEDICO is not responsible for service disruptions caused by: floods, riots, internet outages, natural disasters, or government restrictions.",
            ]),

            _section(isDark, "25. Account Inactivity", Icons.hourglass_empty_rounded, [
              "Long-inactive accounts may be disabled without prior notice.",
              "Re-verification may be required after a period of inactivity.",
            ]),

            _section(isDark, "26. Tax Responsibility", Icons.receipt_long_rounded, [
              "Caretaker is solely responsible for their personal tax filings.",
              "MEDICO is not liable for any tax obligations of caretakers.",
            ]),

            _section(isDark, "27. Training & Compliance", Icons.school_rounded, [
              "Caretakers may be required to complete mandatory training modules.",
              "Safety guidelines issued by MEDICO must be followed at all times.",
              "Failure to comply with training requirements may affect account access.",
            ]),

            _section(isDark, "28. Rescheduling Policy", Icons.event_repeat_rounded, [
              "Caretakers cannot repeatedly reschedule confirmed bookings.",
              "Emergency rescheduling is permitted with valid reason.",
              "Excessive rescheduling will reduce caretaker ranking and visibility.",
            ]),

            _section(isDark, "29. Complaint Investigation", Icons.find_in_page_rounded, [
              "MEDICO can investigate any complaint filed by patients or users.",
              "Caretaker must cooperate fully with all investigations.",
              "Refusing to cooperate during an investigation may result in account suspension.",
            ]),

            _section(isDark, "30. Intellectual Property", Icons.copyright_rounded, [
              "All app logos, content, and branding belong exclusively to MEDICO.",
              "Unauthorized use of MEDICO branding or content is strictly prohibited.",
            ]),

            _contactCard(isDark),
            const SizedBox(height: 10),
          ]),
        )),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16, right: 16, bottom: 24,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Terms & Conditions",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text("Caretaker Agreement · 30 Sections",
            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text("v1.0", style: TextStyle(color: Colors.white, fontSize: 11)),
      ),
    ]),
  );

  // ── Intro banner ──────────────────────────────────────────────────────────
  Widget _intro(bool isDark) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: AppColors.softGradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.20)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_rounded, color: AppColors.primary, size: 20),
      const SizedBox(width: 10),
      const Expanded(child: Text(
        "By registering as a Caretaker on MEDICO, you agree to all the following terms. "
        "Please read each section carefully. Violations may result in suspension or permanent removal.",
        style: TextStyle(fontSize: 13, height: 1.55),
      )),
    ]),
  );

  // ── Section card ──────────────────────────────────────────────────────────
  Widget _section(bool isDark, String title, IconData icon, List<String> points) =>
    Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
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
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5))),
          ]),
        ),
        // Points
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: points.map((p) => _point(p, isDark)).toList(),
          ),
        ),
      ]),
    );

  Widget _point(String text, bool isDark) {
    final isGood    = text.startsWith("✅");
    final isBad     = text.startsWith("❌");
    final isSpecial = isGood || isBad;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isSpecial) ...[
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradient,
            ),
          ),
          const SizedBox(width: 10),
        ] else
          const SizedBox(width: 2),
        Expanded(child: Text(
          text,
          style: TextStyle(
            fontSize: 13.5, height: 1.5,
            color: isGood
                ? Colors.green.shade700
                : isBad
                    ? AppColors.danger
                    : isDark ? Colors.white70 : Colors.black87,
          ),
        )),
      ]),
    );
  }

  // ── Contact card ──────────────────────────────────────────────────────────
  Widget _contactCard(bool isDark) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppColors.glowShadow,
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mail_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Questions about these terms?",
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(height: 3),
        Text("support@medico.com",
            style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.bold)),
      ]),
    ]),
  );
}