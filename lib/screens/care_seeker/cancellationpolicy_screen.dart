import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class CancellationPolicyScreen extends StatelessWidget {
  const CancellationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF6F7FB),

      body: Column(
        children: [

          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 55, 18, 24),

            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),

            child: Row(
              children: [

                GestureDetector(
                  onTap: () => Navigator.pop(context),

                  child: Container(
                    padding: const EdgeInsets.all(7),

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    "Cancellation Policy",

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // BODY
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: Column(
                children: [

                  _card(
                    context,
                    Icons.access_time_rounded,
                    "Free Cancellation",
                    "Cancel before 3 hours to get full refund.",
                  ),

                  _card(
                    context,
                    Icons.warning_amber_rounded,
                    "Late Cancellation",
                    "Within 3 hours only 50% refund applies.",
                  ),

                  _card(
                    context,
                    Icons.cancel_rounded,
                    "No Refund",
                    "No refund after caregiver arrival/service start.",
                  ),

                  _card(
                    context,
                    Icons.payments_outlined,
                    "Refund Processing",
                    "Refunds may take 5–7 business days.",
                  ),

                  _card(
                    context,
                    Icons.credit_card_off_outlined,
                    "Payment Condition",
                    "COD bookings are not eligible for refunds.",
                  ),

                  const SizedBox(height: 10),

                  // IMPORTANT NOTE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.withOpacity(0.08)
                          : Colors.orange.shade50,

                      borderRadius: BorderRadius.circular(16),

                      border: Border.all(
                        color: Colors.orange.withOpacity(0.25),
                      ),
                    ),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.orange,
                          size: 18,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            "Repeated cancellations or suspicious refund activity may lead to temporary account restrictions.",

                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: isDark
                                  ? Colors.orange[200]
                                  : Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B1B1B)
            : Colors.white,

        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(
            height: 36,
            width: 36,

            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),

            child: Icon(
              icon,
              color: AppColors.primary,
              size: 18,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,

                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.45,
                    color: isDark
                        ? Colors.grey[400]
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}