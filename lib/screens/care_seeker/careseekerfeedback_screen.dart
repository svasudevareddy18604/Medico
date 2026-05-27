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
  final String caregiverName;
  final String caregiverPhone;

  const CareSeekerFeedbackScreen({
    super.key,
    required this.caregiverId,
    required this.orderId,
    required this.caregiverName,
    required this.caregiverPhone,
  });

  @override
  State<CareSeekerFeedbackScreen> createState() =>
      _CareSeekerFeedbackScreenState();
}

class _CareSeekerFeedbackScreenState
    extends State<CareSeekerFeedbackScreen> {
  int rating = 0;
  final TextEditingController feedbackController = TextEditingController();
  bool loading = false;

  Future<void> submitFeedback() async {
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select rating")),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback submitted")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const FeedbackSuccessScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Error")),
        );
      }
    } catch (e) {
      debugPrint("Feedback Error: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  // ── STAR ─────────────────────────────────────────────────────────
  Widget buildStar(int index) {
    return IconButton(
      icon: Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: index < rating ? Colors.amber : Colors.grey,
        size: 36,
      ),
      onPressed: () => setState(() => rating = index + 1),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            "Rate Caregiver",
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── CAREGIVER CARD ───────────────────────────────────────────────
  Widget caregiverCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.withOpacity(0.1)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.green.withOpacity(0.3)
              : Colors.green.shade100,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Caretaker",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.caregiverName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  widget.caregiverPhone,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    fontSize: 13,
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
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                children: [
                  caregiverCard(context),

                  const SizedBox(height: 30),

                  // Rating Label
                  Text(
                    "Give Rating",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, buildStar),
                  ),

                  const SizedBox(height: 20),

                  // Feedback Text Field
                  TextField(
                    controller: feedbackController,
                    maxLines: 4,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: "Write feedback...",
                      hintStyle: TextStyle(
                        color:
                            isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E1E2E)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text(
                              "Submit",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
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