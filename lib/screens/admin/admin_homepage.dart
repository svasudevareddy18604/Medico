import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medico/utils/app_colors.dart';

import 'admin_dashboard.dart';
import 'admin_profile.dart';
import 'admin_settings.dart';

class AdminHomePage extends StatefulWidget {
  final int userId;

  const AdminHomePage({super.key, required this.userId});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int selectedIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      AdminDashboard(userId: widget.userId),
      AdminProfile(userId: widget.userId),
      const AdminSettings(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar icons white over the green header
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      extendBodyBehindAppBar: true,
      body: pages[selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[400],
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: (index) => setState(() => selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: "Profile",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}