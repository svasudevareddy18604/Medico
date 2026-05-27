import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      "q": "How do I book a caregiver?",
      "a": "From the Home screen, select a service, choose your preferred date and time slot, and complete the secure payment. You'll receive instant booking confirmation.",
    },
    {
      "q": "What services are available?",
      "a": "We offer home nursing, elderly care, post-hospitalization support, medication management, physiotherapy at home, and general daily assistance.",
    },
    {
      "q": "What payment methods are accepted?",
      "a": "We accept UPI, credit/debit cards, net banking, and popular digital wallets. All payments are encrypted and processed via a PCI-DSS compliant gateway.",
    },
    {
      "q": "Can I view a caregiver's profile before booking?",
      "a": "Caregivers are assigned after booking based on availability and requirements. Once assigned, you will be able to view full caregiver details including experience and contact information",
    },
    {
      "q": "Can I cancel or reschedule my booking?",
      "a": "Cancellation is allowed up to 3 hours before the service start time. so please review your slot carefully before confirming.",
    },
    {
      "q": "How do I track my caregiver in real time?",
      "a": "Once assigned, track your caregiver's live location from 'My Services'. Push notifications are sent when they depart, are nearby, and have arrived.",
    },
    {
      "q": "What if my caregiver doesn't show up?",
      "a": "Our support team will arrange a replacement at no extra charge. Contact us via phone or email for immediate assistance.",
    },
    {
      "q": "How are caregivers verified?",
      "a": "All caregivers go through government ID verification, professional credential checks, reference verification, and a background screening before being listed.",
    },
    {
      "q": "Is my personal data safe?",
      "a": "Yes. Your data is encrypted in transit and at rest. We never share your information with third parties without your consent. Review our Privacy Policy from Settings.",
    },
    {
      "q": "How do I leave a review?",
      "a": "After service completion, go to 'My Services', select the completed booking, and bottom you can see feedback & tap 'Write a Review'. Your feedback helps us maintain quality.",
    },
    {
      "q": "Are there discount codes or offers?",
      "a": "Yes! Medico offers promo codes, referral discounts, and seasonal deals. Apply coupon codes at the Cart screen and enable notifications to stay updated.",
    },
    {
      "q": "What are your support hours?",
      "a": "Our support team is available 24/7, including public holidays — via email or phone.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context, "Frequently Asked Questions"),
                  const SizedBox(height: 10),
                  ..._faqs
                      .map((f) => _faqItem(context, f["q"]!, f["a"]!)),
                  const SizedBox(height: 24),
                  _sectionLabel(context, "Contact & Support"),
                  const SizedBox(height: 10),
                  _contactCard(context, Icons.email_outlined, "Email Support",
                      "support@medico.com", "Replies within 2 hrs"),
                  _contactCard(context, Icons.phone_outlined, "Call Us",
                      "+91 98765 43210", "24 / 7 Available"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 20, 22),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(30)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                ),
                const Expanded(
                  child: Text(
                    "Help Center",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 18, top: 2),
              child: Text(
                "How can we help you today?",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _faqItem(BuildContext context, String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.primary,
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.help_outline,
                color: AppColors.primary, size: 17),
          ),
          title: Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A3E)
                    : const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.65,
                  color: isDark
                      ? Colors.grey[300]
                      : const Color(0xFF444444),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, IconData icon, String title,
      String subtitle, String badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.04),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}