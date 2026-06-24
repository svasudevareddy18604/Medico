import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class TermsConditions extends StatelessWidget {
  const TermsConditions({super.key});

  Widget _sectionCard(IconData icon, String title, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: points
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("•  ",
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(e,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF3A3A3A),
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F4),
      body: Column(
        children: [

          // ── GRADIENT HEADER ─────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 22),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Terms & Conditions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Please read carefully before using MEDICO",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          // ── BODY ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                children: [

                  // Intro banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Text(
                      "Welcome to MEDICO. By registering or using our platform, you agree to abide by these Terms & Conditions. These terms are legally binding and govern the use of our caregiver services platform. Non-compliance may result in immediate account suspension.",
                      style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF2A4A45),
                          height: 1.6),
                    ),
                  ),

                  _sectionCard(Icons.gavel, "General Terms of Use", [
                    "Users must be at least 18 years old to register on MEDICO.",
                    "All personal information provided must be accurate, complete, and up to date.",
                    "Account credentials must not be shared. Each account is strictly personal.",
                    "MEDICO reserves the right to suspend or terminate accounts that violate any terms.",
                    "Impersonation of any person, organization, or caregiver role is strictly prohibited.",
                    "Any attempt to manipulate, hack, or exploit the platform will result in legal action.",
                  ]),

                  _sectionCard(Icons.person_search, "Care Seeker Responsibilities", [
                    "Care seekers must provide accurate details about the patient's medical condition and care requirements.",
                    "A safe, respectful, and non-threatening environment must be maintained for visiting caregivers.",
                    "Any form of physical, verbal, or sexual harassment toward a caregiver is strictly prohibited and punishable.",
                    "Seekers must not request caregivers to perform tasks outside the agreed scope of service.",
                    "Cancellation of booked services must be done within the allowed cancellation window.",
                    "Care seekers must make full and timely payments through authorized platform channels only.",
                    "Providing false medical information that puts the caregiver at risk is a breach of these terms.",
                  ]),

                  _sectionCard(Icons.health_and_safety, "Caregiver Responsibilities", [
                    "Caregivers must submit valid, government-issued identity documents and professional certifications before onboarding.",
                    "All documents submitted are subject to background verification. False documents will result in permanent ban.",
                    "Services must be delivered with professionalism, empathy, and adherence to medical ethics.",
                    "Caregivers must strictly maintain patient confidentiality and never disclose personal medical information.",
                    "Punctuality is mandatory. Repeated no-shows without valid reason will lead to account suspension.",
                    "Caregivers must not solicit direct payments outside the platform under any circumstance.",
                    "Any behavior that compromises patient safety or dignity will result in immediate removal.",
                  ]),

                  _sectionCard(Icons.payment, "Payments & Refund Policy", [
                    "All transactions must be completed through MEDICO's authorized payment gateway only.",
                    "Off-platform cash transactions are strictly prohibited and not covered by any dispute policy.",
                    "Refund requests must be raised within 24 hours of the service date with valid reason.",
                    "Approved refunds will be processed within 5–7 business days to the original payment method.",
                    "Partial refunds may apply if a portion of the service has been rendered.",
                    "MEDICO charges a platform service fee which is non-refundable in all circumstances.",
                  ]),

                  _sectionCard(Icons.verified_user, "Background Verification & Safety", [
                    "All caregivers undergo mandatory police background verification before activation.",
                    "Care seekers are encouraged to verify caregiver identity badges before service commencement.",
                    "MEDICO uses encrypted data protocols to protect all user information.",
                    "Any suspicious activity must be reported immediately to MEDICO support.",
                    "MEDICO does not guarantee medical outcomes and is not a substitute for emergency medical services.",
                    "In case of medical emergency, users must contact emergency services (108/112) immediately.",
                  ]),

                  _sectionCard(Icons.report_problem, "Prohibited Activities", [
                    "Using the platform for any illegal, fraudulent, or harmful activity is strictly prohibited.",
                    "Posting false reviews, ratings, or misleading information about any user is not allowed.",
                    "Sharing or selling user data obtained through the platform is a criminal offense.",
                    "Caregivers must not administer medications or perform procedures beyond their verified qualifications.",
                    "Any form of discrimination based on race, religion, gender, or disability is strictly forbidden.",
                  ]),

                  _sectionCard(Icons.balance, "Liability Disclaimer", [
                    "MEDICO acts solely as a digital intermediary connecting care seekers and caregivers.",
                    "MEDICO is not liable for any injury, loss, or damage arising from caregiver services.",
                    "Users agree to use the platform and its services entirely at their own risk.",
                    "Any disputes between care seekers and caregivers must first be raised through MEDICO's resolution portal.",
                    "MEDICO's liability, in any case, shall not exceed the amount paid for the disputed service.",
                  ]),

                  _sectionCard(Icons.lock, "Privacy Policy", [
                    "User data is collected solely for the purpose of facilitating caregiver services.",
                    "Personal information is stored on encrypted, secure servers and never sold to third parties.",
                    "Location data is used only during active service sessions and is not stored permanently.",
                    "Users may request data deletion by contacting MEDICO support at any time.",
                    "MEDICO complies with applicable data protection regulations.",
                  ]),

                  _sectionCard(Icons.edit_document, "Amendments & Acceptance", [
                    "MEDICO reserves the right to update these Terms & Conditions at any time.",
                    "Users will be notified of major changes via registered email or in-app notification.",
                    "Continued use of the platform after updates constitutes acceptance of revised terms.",
                    "If you disagree with any terms, you must discontinue use and deactivate your account immediately.",
                  ]),

                  // Contact section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.support_agent, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Contact Support",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          "For any queries regarding these terms, reach out to our team:",
                          style: TextStyle(color: Colors.white70, fontSize: 13.5),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.email_outlined, color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              "medicoteam@gmail.com",
                              style: TextStyle(color: Colors.white, fontSize: 13.5),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              "+91 9652296548",
                              style: TextStyle(color: Colors.white, fontSize: 13.5),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined, color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              "Support: Mon–Sat, 9 AM – 6 PM",
                              style: TextStyle(color: Colors.white, fontSize: 13.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Last updated note
                  Center(
                    child: Text(
                      "Last updated: April 2026  •  Version 1.1.0",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}