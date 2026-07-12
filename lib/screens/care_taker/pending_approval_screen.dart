import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';
import '../../login_page.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String status;

  const PendingApprovalScreen({
    super.key,
    this.status = "pending",
  });

  // 🔥 Helper: navigate to Login and clear the entire stack
  void _goToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()), // ✅ correct class name
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool rejected = status == "rejected";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 🔥 GRADIENT HEADER (SAME STYLE)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rejected
                    ? [Colors.red, Colors.red.withOpacity(0.7)]
                    : [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(25),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _goToLogin(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  rejected ? "Application Rejected" : "Verification Pending",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 🔥 BODY
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ICON
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: rejected
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        rejected ? Icons.cancel : Icons.hourglass_top,
                        size: 70,
                        color: rejected ? Colors.red : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // TITLE
                    Text(
                      rejected
                          ? "Your application was rejected"
                          : "Your documents are under review",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    // DESCRIPTION
                    Text(
                      rejected
                          ? "Unfortunately your caretaker application was rejected by the admin."
                          : "The admin will review your documents shortly. Once approved, you will be notified via email and notification.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 35),

                    // BUTTON (ONLY FOR REJECTED)
                    if (rejected)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _goToLogin(context),
                          child: const Text(
                            "Back to Login",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}