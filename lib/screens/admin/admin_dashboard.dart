import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

import 'admin_services.dart';
import 'admin_users.dart';
import 'admin_orders.dart';
import 'admin_caregivers.dart';
import 'admin_timeslot_screen.dart';
import 'admin_withdraw_screen.dart';

class AdminDashboard extends StatefulWidget {
  final int userId;

  const AdminDashboard({super.key, required this.userId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  /* ================= HEADER ================= */

  Widget _appHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                getGreeting(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "Admin Dashboard",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ================= BODY ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _appHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  DashboardCard(
                    title: "Services",
                    icon: Icons.medical_services_rounded,
                    color: AppColors.primary,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminServices())),
                  ),
                  DashboardCard(
                    title: "CareSeekers",
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF2979FF),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminUsers())),
                  ),
                  DashboardCard(
                    title: "Bookings",
                    icon: Icons.assignment_rounded,
                    color: const Color(0xFFFF8C00),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminOrders())),
                  ),
                  DashboardCard(
                    title: "Caregivers",
                    icon: Icons.health_and_safety_rounded,
                    color: const Color(0xFFE53935),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminCaregivers())),
                  ),
                  DashboardCard(
                    title: "Time Slots",
                    icon: Icons.access_time_rounded,
                    color: const Color(0xFF7C4DFF),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminTimeSlotScreen())),
                  ),
                  DashboardCard(
                    title: "Withdraw\nRequests",
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminWithdrawScreen())),
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

/* ================= CARD ================= */

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}