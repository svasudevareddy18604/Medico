import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class PaymentFailedScreen extends StatefulWidget {
  const PaymentFailedScreen({super.key});

  @override
  State<PaymentFailedScreen> createState() => _PaymentFailedScreenState();
}

class _PaymentFailedScreenState extends State<PaymentFailedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> scaleAnimation;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 40),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: const Center(
              child: Text(
                "Payment Status",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: Center(
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Failure icon
                          Container(
                            height: 130,
                            width: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.red.withOpacity(0.12)
                                  : Colors.red.shade50,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(
                                      isDark ? 0.25 : 0.15),
                                  blurRadius: 25,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.cancel_rounded,
                              color: Colors.red,
                              size: 85,
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Title
                          Text(
                            "Payment Failed",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Description
                          Text(
                            "We couldn't process your payment.\nPlease check your details and try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 50),

                          // Retry Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                "Retry Payment",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Cancel Button
                          TextButton(
                            onPressed: () {
                              Navigator.popUntil(
                                  context, (route) => route.isFirst);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                            child: Text(
                              "Cancel & Go Back",
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}