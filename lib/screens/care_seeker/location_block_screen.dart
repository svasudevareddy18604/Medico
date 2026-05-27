import 'package:flutter/material.dart';

// 🔥 IMPORTANT: Adjust path if needed
import '../care_seeker/care_seeker_home.dart';

class LocationBlockScreen extends StatelessWidget {
  final int userId; // ✅ REQUIRED

  const LocationBlockScreen({super.key, required this.userId});

  static const Color primary = Color(0xFF0F9D58);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      body: Column(
        children: [

          /// 🔥 HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: const Center(
              child: Text(
                "Location Restricted",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          /// 🔥 BODY
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  /// ICON
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      size: 70,
                      color: Colors.red,
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// TITLE
                  const Text(
                    "Service Not Available",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  /// DESCRIPTION
                  Text(
                    "Sorry! Our services are not available in your selected location.\n\nPlease choose another address where service is active.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),

                  const SizedBox(height: 50),

                  /// 🔥 BUTTON (FINAL FIXED)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CareSeekerHome(userId: userId),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Go Back to Home",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
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