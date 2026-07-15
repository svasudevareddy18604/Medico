import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

import '../care_seeker/care_seeker_home.dart';

class LocationBlockScreen extends StatelessWidget {
  final int userId;

  const LocationBlockScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                children: [
                  _buildIcon(),
                  const SizedBox(height: 28),
                  _buildTitle(),
                  const SizedBox(height: 12),
                  _buildDescription(),
                  const SizedBox(height: 36),
                  _buildInfoCard(),
                  const SizedBox(height: 36),
                  _buildHomeButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────── HEADER ────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 55, 20, 30),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "LOCATION CHECK",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Location Restricted",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────── ICON ──────────────────────────────────────

  Widget _buildIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.location_off_rounded,
        size: 62,
        color: Color(0xFFD32F2F),
      ),
    );
  }

  // ─────────────────────────────── TEXT ──────────────────────────────────────

  Widget _buildTitle() {
    return const Text(
      "Service Not Available Here",
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A2E),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription() {
    return Text(
      "We're not live in your selected area just yet.\nPlease choose a different address to continue booking a service.",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.6,
        color: Colors.grey.shade600,
      ),
    );
  }

  // ─────────────────────────────── INFO CARD ─────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tips_and_updates_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "We're expanding fast — try updating your location or check back soon.",
              style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────── BUTTON ────────────────────────────────────

  Widget _buildHomeButton(BuildContext context) {
    return SizedBox(
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_rounded, size: 20),
            SizedBox(width: 10),
            Text(
              "Go Back to Home",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}