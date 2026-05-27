import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'care_seeker_home.dart';
import 'package:medico/utils/app_colors.dart';

class FeedbackSuccessScreen extends StatefulWidget {
  const FeedbackSuccessScreen({super.key});

  @override
  State<FeedbackSuccessScreen> createState() =>
      _FeedbackSuccessScreenState();
}

class _FeedbackSuccessScreenState extends State<FeedbackSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color successGreen = Color(0xFF0F9D58);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    redirectToHome();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> redirectToHome() async {
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt("user_id") ?? 0;

    if (!mounted) return;

    if (userId == 0) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => CareSeekerHome(userId: userId),
      ),
      (route) => false,
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.verified, color: Colors.white),
          SizedBox(width: 10),
          Text(
            "Feedback Submitted",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── BODY ─────────────────────────────────────────────────────────
  Widget _body(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated success icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: successGreen.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: successGreen.withOpacity(
                            isDark ? 0.3 : 0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: successGreen,
                    size: 90,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Title
              Text(
                "Thank You!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              // Message
              Text(
                "Your feedback has been submitted successfully.\nWe appreciate your time and support.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Loader with text
              Column(
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Redirecting to home...",
                    style: TextStyle(
                      color:
                          isDark ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _header(),
          _body(context),
        ],
      ),
    );
  }
}