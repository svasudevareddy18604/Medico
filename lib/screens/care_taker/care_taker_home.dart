import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:medico/utils/app_colors.dart';

import '../../config/api.dart';
import 'available_orders_screen.dart';
import 'my_jobs_screen.dart';
import 'caretaker_settings_screen.dart';
import 'caretaker_profile_screen.dart';
import 'caretaker_earnings_screen.dart';

class CareTakerHome extends StatefulWidget {
  final int userId;
  final String category;
  const CareTakerHome({super.key, required this.userId, required this.category});
  @override
  State<CareTakerHome> createState() => _CareTakerHomeState();
}

class _CareTakerHomeState extends State<CareTakerHome>
    with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  String addressText = "Fetching address...";
  late String caretakerCategory;
  Timer? timer;

  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> earnings = {"total": 0, "pending": 0, "paid": 0};
  String profileImage = "";
  bool loadingProfile = true;
  double avgRating = 0.0;
  int totalReviews = 0;

  // ── Availability ───────────────────────────────────────────────────────────
  bool isAvailable = false;
  bool togglingAvailability = false;

  // ── Pulse animation for availability indicator ─────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ─────────────────────────────── INIT ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    caretakerCategory = widget.category;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    loadAddress();
    loadProfile();
    loadEarnings();
    loadRating();

    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      loadEarnings();
      loadRating();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────── API ───────────────────────────────────────

  static const Map<String, String> _noCache = {
    "Cache-Control": "no-cache, no-store, must-revalidate",
    "Pragma": "no-cache",
    "Expires": "0",
  };

  Future<void> loadEarnings() async {
    try {
      final res = await http.get(
        Uri.parse(
            "${Api.baseUrl}/earnings/${widget.userId}?t=${DateTime.now().millisecondsSinceEpoch}"),
        headers: _noCache,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true && mounted) {
          setState(() {
            earnings = {
              "total": data["data"]["total"] ?? 0,
              "pending": data["data"]["pending"] ?? 0,
              "paid": data["data"]["paid"] ?? 0,
            };
          });
        }
      }
    } catch (_) {}
  }

  Future<void> loadRating() async {
    try {
      final res = await http.get(
        Uri.parse(
            "${Api.caregiverRating(widget.userId)}&t=${DateTime.now().millisecondsSinceEpoch}"),
        headers: _noCache,
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true && mounted) {
        setState(() {
          avgRating = double.tryParse(data["avgRating"].toString()) ?? 0.0;
          totalReviews = data["total"] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> loadProfile() async {
    try {
      final res = await http
          .get(Uri.parse("${Api.caretakerProfile}/${widget.userId}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            profileImage = data["profile_image"] ?? "";
            loadingProfile = false;
            // ✅ Load availability from profile API
            isAvailable = (data["is_available"] == 1 || data["is_available"] == true);
          });
        }
      } else {
        if (mounted) setState(() => loadingProfile = false);
      }
    } catch (_) {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  Future<void> loadAddress() async {
    try {
      final res = await http.get(Uri.parse(
          "${Api.baseUrl}/caretaker/location/default/${widget.userId}"));
      final data = jsonDecode(res.body);
      if (data["success"] == true && data["address"] != null) {
        final addr = data["address"];
        if (mounted) {
          setState(() =>
              addressText =
                  "${addr["address_line"]}, ${addr["area"]}, ${addr["pincode"]}");
        }
      }
    } catch (_) {}
  }

  // ✅ Toggle availability — calls PUT /api/caretaker-profile/availability/:userId
  Future<void> toggleAvailability() async {
    if (togglingAvailability) return;
    setState(() => togglingAvailability = true);

    final newVal = isAvailable ? 0 : 1;

    try {
      final res = await http.put(
        Uri.parse("${Api.caretakerProfile}/availability/${widget.userId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_available": newVal}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true && mounted) {
          setState(() => isAvailable = newVal == 1);
          _showAvailabilitySnackbar(newVal == 1);
        }
      } else {
        _showErrorSnackbar();
      }
    } catch (_) {
      _showErrorSnackbar();
    } finally {
      if (mounted) setState(() => togglingAvailability = false);
    }
  }

  void _showAvailabilitySnackbar(bool available) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: available
            ? const Color(0xFF00C853)
            : const Color(0xFFD32F2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          Icon(
            available ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Text(
            available
                ? "You are now Available for jobs!"
                : "You are now Unavailable.",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ]),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Text("Failed to update availability. Try again.",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  String getImageUrl() => profileImage.startsWith("http")
      ? profileImage
      : "${Api.imageBase}/${profileImage.replaceFirst(RegExp(r'^/+'), '')}";

  // ─────────────────────────────── HEADER ────────────────────────────────────

  Widget appHeader({required String title, bool showLocation = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) =>
                            CareTakerProfileScreen(userId: widget.userId)))
                    .then((_) => loadProfile()),
                child: loadingProfile
                    ? const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: profileImage.isNotEmpty
                              ? Image.network(getImageUrl(),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 28,
                                      color: Colors.black))
                              : const Icon(Icons.person,
                                  size: 28, color: Colors.black),
                        ),
                      ),
              ),
            ],
          ),
          if (showLocation) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.location_on, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(addressText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── AVAILABILITY CARD ─────────────────────────────

  Widget _buildAvailabilityCard() {
    final Color activeColor = const Color(0xFF00C853);
    final Color inactiveColor = const Color(0xFFD32F2F);
    final Color currentColor = isAvailable ? activeColor : inactiveColor;
    final Color currentBg = isAvailable
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: currentBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: currentColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: currentColor.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            // ── Pulse dot + icon ──────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                if (isAvailable)
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: activeColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: currentColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isAvailable
                        ? Icons.wifi_tethering_rounded
                        : Icons.wifi_tethering_off_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // ── Status text ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAvailable ? "You're Online" : "You're Offline",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: currentColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isAvailable
                        ? "Visible to CareSeekers · Accepting Services"
                        : "Hidden from CareSeekers · Not accepting Services",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: currentColor.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Toggle switch ─────────────────────────────────────────────
            togglingAvailability
                ? SizedBox(
                    width: 44,
                    height: 26,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: currentColor,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: toggleAvailability,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      width: 54,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: isAvailable ? activeColor : Colors.grey.shade300,
                        boxShadow: [
                          BoxShadow(
                            color: isAvailable
                                ? activeColor.withOpacity(0.35)
                                : Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        alignment: isAvailable
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────── HOME BODY ─────────────────────────────────

  Widget homeScreen() {
    return Column(
      children: [
        appHeader(title: "Location", showLocation: true),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await Future.wait([loadEarnings(), loadRating(), loadProfile()]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  // ✅ AVAILABILITY STATUS CARD — prominent, top of home
                  _buildAvailabilityCard(),

                  // ── Welcome card ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Colors.white, Colors.green.shade50]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.08))
                      ],
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.primary.withOpacity(0.15),
                        child:
                            Icon(Icons.person, color: AppColors.primary),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Welcome",
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(caretakerCategory,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(avgRating.toStringAsFixed(1)),
                            const SizedBox(width: 6),
                            Text("($totalReviews reviews)",
                                style:
                                    const TextStyle(color: Colors.grey)),
                          ]),
                        ],
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // ── Earnings cards ────────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _statCard(
                        "Total",
                        "₹${earnings["total"]}",
                        Colors.green,
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        "Pending",
                        "₹${earnings["pending"]}",
                        Colors.orange,
                        Icons.warning_amber_rounded,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 15),

                  // ── View full earnings ────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaretakerEarningsScreen(
                            caretakerId: widget.userId),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF0F9D58),
                          Color(0xFF34A853)
                        ]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(children: [
                        Icon(Icons.account_balance_wallet,
                            color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text("View Full Earnings",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 16),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionTitle("Quick Actions"),
                  const SizedBox(height: 10),
                  _actionCard(Icons.work, "Available Services",
                      () => setState(() => currentIndex = 1)),
                  _actionCard(Icons.assignment, "My Services",
                      () => setState(() => currentIndex = 2)),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── HELPERS ───────────────────────────────────

  Widget _statCard(
          String title, String value, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [color, color.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white70)),
        ]),
      );

  Widget _sectionTitle(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _actionCard(IconData icon, String text, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  blurRadius: 5,
                  color: Colors.black.withOpacity(0.05))
            ],
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ]),
        ),
      );

  // ─────────────────────────────── SCREENS ───────────────────────────────────

  Widget getScreen() {
    switch (currentIndex) {
      case 0:
        return homeScreen();
      case 1:
        return Column(children: [
          appHeader(title: "Services"),
          Expanded(
            child: AvailableOrdersScreen(
                userId: widget.userId, category: caretakerCategory),
          ),
        ]);
      case 2:
        return Column(children: [
          appHeader(title: "My Services"),
          Expanded(child: MyJobsScreen(userId: widget.userId)),
        ]);
      case 3:
        return Column(children: [
          appHeader(title: "Settings"),
          Expanded(
              child: CareTakerSettingsScreen(userId: widget.userId)),
        ]);
      default:
        return homeScreen();
    }
  }

  // ─────────────────────────────── BUILD ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: getScreen(),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            onTap: (i) => setState(() => currentIndex = i),
            items: [
              BottomNavigationBarItem(
                  icon: Icon(Icons.home,
                      size: currentIndex == 0 ? 28 : 24),
                  label: "Home"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.work,
                      size: currentIndex == 1 ? 28 : 24),
                  label: "Services"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.assignment,
                      size: currentIndex == 2 ? 28 : 24),
                  label: "Accepted"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings,
                      size: currentIndex == 3 ? 28 : 24),
                  label: "Settings"),
            ],
          ),
        ),
      ),
    );
  }
}