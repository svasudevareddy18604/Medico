import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';
import '../../login_page.dart';
import 'document_upload_screen.dart';

class RejectedScreen extends StatelessWidget {
  final String reason;
  final int userId;
  final String caregiverType;

  /// 🔥 Comes from the status/login API (users.allow_reupload).
  /// true  → show "Re-upload Documents" button
  /// false → only show rejection info + "Contact Admin" / logout
  final bool allowReupload;

  const RejectedScreen({
    super.key,
    required this.reason,
    required this.userId,
    required this.caregiverType,
    required this.allowReupload,
  });

  /// 🔥 RESET STATUS → PENDING (only reachable when allowReupload = true)
  Future<void> resetAndReupload(BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse("${Api.baseUrl}/caretaker/reset-status/$userId"),
      );

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentUploadScreen(
              userId: userId,
              caregiverType: caregiverType,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to retry")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error")),
      );
    }
  }

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Column(
        children: [
          _buildCurvedHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: _buildRejectionCard(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 CURVED GRADIENT HEADER
  Widget _buildCurvedHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 28,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                "Verification Status",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  /// 🔥 REJECTION CARD
  Widget _buildRejectionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// 🔴 ICON
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel, color: AppColors.danger, size: 60),
          ),

          const SizedBox(height: 20),

          const Text(
            "Account Rejected",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            allowReupload
                ? "Your documents were not approved.\nPlease review the reason and re-upload."
                : "Your application could not be approved.\nPlease review the reason below.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),

          const SizedBox(height: 20),

          /// 🔥 REASON BOX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Rejection Reason",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: const TextStyle(fontSize: 14, color: AppColors.dark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          /// 🔥 STATUS TAG — tells the caregiver clearly what to do next
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (allowReupload ? AppColors.secondary : AppColors.warning).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (allowReupload ? AppColors.secondary : AppColors.warning).withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  allowReupload ? Icons.upload_file_rounded : Icons.support_agent_rounded,
                  size: 18,
                  color: allowReupload ? AppColors.secondary : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    allowReupload
                        ? "You can fix this by re-uploading your documents."
                        : "This cannot be resolved by re-uploading documents. Please contact admin support.",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: allowReupload ? AppColors.secondary : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          /// 🔥 REUPLOAD BUTTON — only when admin explicitly allowed it
          if (allowReupload)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => resetAndReupload(context),
                child: const Text(
                  "Re-upload Documents",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),

          if (allowReupload) const SizedBox(height: 10),

          /// 🔥 LOGOUT BUTTON
          TextButton(
            onPressed: () => _logout(context),
            child: const Text(
              "Back to Login",
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}