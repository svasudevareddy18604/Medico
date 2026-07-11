import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feedback_success_screen.dart';
import 'package:medico/utils/app_colors.dart';

class CareSeekerFeedbackScreen extends StatefulWidget {
  final int caregiverId;
  final int orderId;
  final String orderCode;
  final String caregiverName;
  final String caregiverPhone;

  const CareSeekerFeedbackScreen({
    super.key,
    required this.caregiverId,
    required this.orderId,
    required this.orderCode,
    required this.caregiverName,
    required this.caregiverPhone,
  });

  @override
  State<CareSeekerFeedbackScreen> createState() =>
      _CareSeekerFeedbackScreenState();
}

class _CareSeekerFeedbackScreenState extends State<CareSeekerFeedbackScreen>
    with TickerProviderStateMixin {
  int rating = 0;
  final TextEditingController feedbackController = TextEditingController();
  bool loading = false;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Per-star scale animation controllers
  late final List<AnimationController> _starControllers;

  static const List<String> ratingLabels = [
    "Tap a star to rate",
    "Poor",
    "Fair",
    "Good",
    "Very Good",
    "Excellent",
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _starControllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        lowerBound: 0.0,
        upperBound: 0.25,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    for (final c in _starControllers) {
      c.dispose();
    }
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> submitFeedback() async {
    if (rating == 0) {
      _showSnack("Please select a rating before submitting", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt("user_id") ?? 0;

      final res = await http.post(
        Uri.parse(Api.submitFeedback),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "caregiver_id": widget.caregiverId,
          "order_id": widget.orderId,
          "user_id": userId,
          "rating": rating,
          "feedback": feedbackController.text,
        }),
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        // Persist locally so OrderDetailsScreen can hide the
        // "Rate & Give Feedback" button once submitted, even if the
        // backend order payload doesn't yet return a feedback flag.
        await prefs.setBool("feedback_given_${widget.orderId}", true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FeedbackSuccessScreen()),
          );
        }
      } else {
        _showSnack(data["message"] ?? "Something went wrong", isError: true);
      }
    } catch (e) {
      debugPrint("Feedback Error: $e");
      _showSnack("Unable to submit feedback. Please try again.",
          isError: true);
    }

    if (mounted) setState(() => loading = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  // ── STAR (animated) ─────────────────────────────────────────────
  Widget buildStar(int index) {
    final controller = _starControllers[index];
    final filled = index < rating;

    return GestureDetector(
      onTap: () {
        setState(() => rating = index + 1);
        controller.forward(from: 0).then((_) => controller.reverse());
      },
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final scale = 1.0 + controller.value;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            key: ValueKey(filled),
            color: filled ? const Color(0xFFFFB300) : Colors.grey.shade400,
            size: 42,
          ),
        ),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 26),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Share Your Feedback",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Your review helps us improve our service",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SERVICE SUMMARY CARD (no name / phone shown) ──────────────────
  Widget serviceSummaryCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.task_alt_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Service Completed",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Booking ID: ${widget.orderCode}",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          header(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    20,
                    18,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      serviceSummaryCard(context),

                      const SizedBox(height: 28),

                      // Rating Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 26, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "How would you rate the service?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, buildStar),
                            ),
                            const SizedBox(height: 14),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                ratingLabels[rating],
                                key: ValueKey(rating),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: rating == 0
                                      ? (isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[500])
                                      : const Color(0xFFFFB300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      Text(
                        "Additional Comments",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Feedback Text Field
                      TextField(
                        controller: feedbackController,
                        maxLines: 5,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              "Tell us about your experience (optional)...",
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                            fontSize: 13.5,
                          ),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Submit Button (animated)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: rating == 0
                              ? null
                              : LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.75),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: rating == 0
                              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                              : null,
                          boxShadow: rating == 0
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: loading ? null : submitFeedback,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: loading
                                    ? const SizedBox(
                                        key: ValueKey("loading"),
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : Text(
                                        "Submit Feedback",
                                        key: const ValueKey("label"),
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                          color: rating == 0
                                              ? (isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600])
                                              : Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: Text(
                          "Your feedback is anonymous to the caretaker",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
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