import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../login_page.dart';
import 'document_upload_screen.dart';

class RejectedScreen extends StatelessWidget {

  final String reason;
  final int userId;
  final String caregiverType;

  const RejectedScreen({
    super.key,
    required this.reason,
    required this.userId,
    required this.caregiverType,
  });

  /// 🔥 RESET STATUS → PENDING
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F9D58),
        elevation: 0,
        title: const Text("Verification Status"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginPage(),
              ),
              (route) => false,
            );
          },
        ),
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Container(
            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// 🔴 ICON
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel,
                    color: Colors.red,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 20),

                /// TITLE
                const Text(
                  "Account Rejected",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 12),

                /// SUBTEXT
                const Text(
                  "Your documents were not approved.\nPlease review the reason and re-upload.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),

                /// 🔥 REASON BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Rejection Reason",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),

                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// 🔥 REUPLOAD BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9D58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    onPressed: () => resetAndReupload(context),

                    child: const Text(
                      "Re-upload Documents",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// 🔥 LOGOUT BUTTON (PROPER FIX)
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    "Back to Login",
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}