import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';

import '../../config/api.dart';
import 'careseeker_location.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'service_screen.dart';
import 'profile_screen.dart';
import 'nearby_caretakers_screen.dart';

class CareSeekerHome extends StatefulWidget {
  final int userId;
  const CareSeekerHome({super.key, required this.userId});
  @override
  State<CareSeekerHome> createState() => _CareSeekerHomeState();
}

class _CareSeekerHomeState extends State<CareSeekerHome> with WidgetsBindingObserver {
  int selectedIndex = 0;
  String location = "Add Address";
  int cartCount = 0;
  String firstName = "", lastName = "", profileImage = "";
  List<dynamic> promotions = [];
  final PageController promoController = PageController();
  Timer? promoTimer;

  // ── Key so we can call _refresh() on CartScreen from outside ──────────────
  final GlobalKey<CartScreenState> _cartKey = GlobalKey<CartScreenState>();

  // ── Screens built ONCE — never recreated ─────────────────────────────────
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeNotifier.addListener(_onThemeChange);

    // Build screens once here so IndexedStack never rebuilds them
    _screens = [
      const _HomeBodyPlaceholder(), // replaced in build() with real home body
      CartScreen(key: _cartKey, userId: widget.userId),
      OrdersScreen(userId: widget.userId),
      SettingsScreen(userId: widget.userId),
    ];

    _loadData();
    _startAutoPromoScroll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_onThemeChange);
    promoTimer?.cancel();
    promoController.dispose();
    super.dispose();
  }

  void _onThemeChange() { if (mounted) setState(() {}); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadLocation();
  }

  Future<void> _loadData() async =>
      Future.wait([_loadLocation(), _loadCartCount(), _loadProfile(), _fetchPromotions()]);

  Future<void> _loadLocation() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/user/address/${widget.userId}"));
      if (res.statusCode == 200) {
        final addr = (jsonDecode(res.body)["address"] ?? "").toString().trim();
        final prefs = await SharedPreferences.getInstance();
        addr.isEmpty
            ? await prefs.remove("user_location_${widget.userId}")
            : await prefs.setString("user_location_${widget.userId}", addr);
        if (mounted) setState(() => location = addr.isEmpty ? "Add Address" : addr);
        return;
      }
    } catch (_) {}
    final saved = (await SharedPreferences.getInstance())
            .getString("user_location_${widget.userId}") ?? "";
    if (mounted) setState(() => location = saved.isEmpty ? "Add Address" : saved);
  }

  Future<void> _loadCartCount() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/cart/${widget.userId}"));
      if (res.statusCode == 200 && mounted) {
        setState(() => cartCount = (jsonDecode(res.body) as List).length);
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final res = await http.get(Uri.parse("${Api.userProfile}/${widget.userId}"));
      if (res.statusCode == 200 && mounted) {
        final d = jsonDecode(res.body);
        setState(() {
          firstName    = d["first_name"]    ?? "";
          lastName     = d["last_name"]     ?? "";
          profileImage = d["profile_image"] ?? "";
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPromotions() async {
    try {
      final res = await http.get(Uri.parse(Api.adminPromotions));
      if (res.statusCode == 200 && mounted) setState(() => promotions = jsonDecode(res.body));
    } catch (_) {}
  }

  void _startAutoPromoScroll() {
    promoTimer?.cancel();
    promoTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!promoController.hasClients || promotions.isEmpty) return;
      final next = (promoController.page?.toInt() ?? 0) + 1;
      promoController.animateToPage(next % promotions.length,
          duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    });
  }

  // ── Tab switching ─────────────────────────────────────────────────────────

  void _onTabTap(int i) {
    setState(() => selectedIndex = i);
    switch (i) {
      case 0: _loadLocation(); break;
      case 1:
        // Always refresh cart when user taps cart tab
        _cartKey.currentState?.refresh();
        _loadCartCount();
        break;
      default: break;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String getGreeting() {
    final h = DateTime.now().hour;
    return h < 12 ? "Good Morning" : h < 17 ? "Good Afternoon" : "Good Evening";
  }

  String get fullName => firstName.isEmpty ? "User" : "$firstName $lastName";
  bool get isDark => themeNotifier.value == ThemeMode.dark;

  String? _buildImageUrl() {
    final img = profileImage.trim();
    if (img.isEmpty) return null;
    if (img.startsWith("http://") || img.startsWith("https://")) return img;
    final base = Api.imageBase.endsWith("/")
        ? Api.imageBase.substring(0, Api.imageBase.length - 1)
        : Api.imageBase;
    return "$base${img.startsWith("/") ? img : "/$img"}";
  }

  Widget _buildAvatar(double radius) {
    final url = _buildImageUrl();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: url == null
            ? Icon(Icons.person_rounded, size: radius, color: Colors.grey.shade400)
            : ClipOval(child: Image.network(url,
                width: radius * 2, height: radius * 2, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person_rounded, size: radius, color: Colors.grey.shade400))),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 28),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => CareSeekerLocation(userId: widget.userId)));
            await _loadLocation();
            // Also refresh cart's address
            _cartKey.currentState?.refresh();
          },
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text("Service Address",
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 15),
              ]),
            ),
            const SizedBox(height: 10),
            Text(location,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ]),
        ),
      ),
      GestureDetector(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId)));
          await _loadProfile();
        },
        child: _buildAvatar(29),
      ),
    ]),
  );

  Widget _buildPromoCarousel() {
    if (promotions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: promoController,
        itemCount: promotions.length,
        itemBuilder: (context, index) {
          final promo = promotions[index];
          final media = promo['media']?.toString();
          String? promoImageUrl;
          if (media != null && media.trim().isNotEmpty) {
            final base = Api.imageBase.endsWith("/")
                ? Api.imageBase.substring(0, Api.imageBase.length - 1)
                : Api.imageBase;
            promoImageUrl = "$base${media.trim().startsWith("/") ? media.trim() : "/${media.trim()}"}";
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(fit: StackFit.expand, children: [
                Container(decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1E88E5), Color(0xFF26C6DA), Color(0xFF00BFA5)]))),
                if (promoImageUrl != null)
                  Image.network(promoImageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                Container(decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.55)]))),
                Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(promo['title'] ?? "Special Offer",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.bold, height: 1.3,
                          shadows: [Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black45)]),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  static const _serviceConfigs = [
    _ServiceConfig("Nurse", Icons.medical_services_rounded, Color(0xFFE91E63),
        Color(0xFFFCE4EC), Color(0xFF3D0017)),
    _ServiceConfig("Physiotherapy", Icons.fitness_center_rounded, Color(0xFF1E88E5),
        Color(0xFFE3F2FD), Color(0xFF0A1929)),
    _ServiceConfig("Non-Medical Support", Icons.elderly_rounded, Color(0xFFFF8F00),
        Color(0xFFFFF8E1), Color(0xFF3E2000)),
    _ServiceConfig("Caretakers Near You", Icons.location_on_rounded, Color(0xFF00897B),
        Color(0xFFE0F2F1), Color(0xFF002923)),
  ];

  Widget _buildServiceCard(_ServiceConfig svc) {
    final cardBg = isDark ? svc.darkBg : svc.lightBg;
    final textColor = isDark ? Colors.white.withOpacity(0.92) : const Color(0xFF1A1A2E);
    return GestureDetector(
      onTap: () {
        if (svc.name == "Caretakers Near You") {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => NearbyCaretakersScreen(userId: widget.userId)));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ServiceScreen(category: svc.name, userId: widget.userId)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: svc.color.withOpacity(isDark ? 0.35 : 0.25), width: 1.5),
          boxShadow: [BoxShadow(color: svc.color.withOpacity(isDark ? 0.22 : 0.18),
              blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: svc.color.withOpacity(isDark ? 0.22 : 0.16), shape: BoxShape.circle),
            child: Icon(svc.icon, color: svc.color, size: 34),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(svc.name, textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5,
                    color: textColor, height: 1.25)),
          ),
        ]),
      ),
    );
  }

  Widget _buildHomeBody() {
    final greetingColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor      = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final chipBg        = isDark ? const Color(0xFF1E293B) : Colors.white;
    final chipBorder    = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(children: [
      _buildHeader(),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildPromoCarousel(),
          const SizedBox(height: 28),
          Text("${getGreeting()},",
              style: TextStyle(fontSize: 15.5, color: subColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(fullName,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                  color: greetingColor, height: 1.15)),
          const SizedBox(height: 6),
          Text("What care do you need today?",
              style: TextStyle(fontSize: 15, color: subColor)),
          const SizedBox(height: 26),
          Row(children: [
            Container(width: 4, height: 22,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 10),
            Text("Care Services",
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: greetingColor)),
          ]),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text("Trusted professionals, just a tap away.",
                style: TextStyle(fontSize: 13, color: subColor, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _serviceConfigs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 16,
                mainAxisSpacing: 16, childAspectRatio: 1.05),
            itemBuilder: (_, i) => _buildServiceCard(_serviceConfigs[i]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: chipBg, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipBorder, width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildStatItem("24/7",  "Support", Icons.support_agent_rounded, AppColors.primary),
              Container(width: 1, height: 36, color: chipBorder),
              _buildStatItem("100+", "Experts", Icons.verified_rounded,      const Color(0xFF1E88E5)),
              Container(width: 1, height: 36, color: chipBorder),
              _buildStatItem("4.9★", "Rated",   Icons.star_rounded,          const Color(0xFFFF8F00)),
            ]),
          ),
        ]),
      )),
    ]);
  }

  Widget _buildStatItem(String val, String label, IconData icon, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 5),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A))),
        Text(label, style: TextStyle(fontSize: 11,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
      ]);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    // Home body is stateful (theme/location), rebuild it each time, rest are stable
    final bodies = [
      _buildHomeBody(),
      _screens[1], // CartScreen — stable instance with key
      _screens[2], // OrdersScreen
      _screens[3], // SettingsScreen
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: selectedIndex, children: bodies),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final navBg        = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFEEF2F7);

    const tabs = [
      (Icons.home_rounded,         Icons.home_outlined,          "Home"),
      (Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, "Cart"),
      (Icons.receipt_long_rounded,  Icons.receipt_long_outlined,  "My Services"),
      (Icons.settings_rounded,      Icons.settings_outlined,      "Settings"),
    ];

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: dividerColor, width: 1)),
        boxShadow: [BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.08),
          blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final isActive    = selectedIndex == i;
              final activeColor = AppColors.primary;
              final inactiveColor = isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BAC9);

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabTap(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                            horizontal: isActive ? 18 : 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? activeColor.withOpacity(0.13) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(isActive ? tabs[i].$1 : tabs[i].$2,
                            color: isActive ? activeColor : inactiveColor, size: 23),
                      ),
                      if (i == 1 && cartCount > 0)
                        Positioned(
                          top: -1, right: isActive ? 8 : 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: navBg, width: 1.5)),
                            child: Text("$cartCount",
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? activeColor : inactiveColor,
                        letterSpacing: isActive ? 0.2 : 0,
                      ),
                      child: Text(tabs[i].$3),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// Placeholder so _screens list can be initialized before home body is built
class _HomeBodyPlaceholder extends StatelessWidget {
  const _HomeBodyPlaceholder();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ServiceConfig {
  final String name; final IconData icon; final Color color, lightBg, darkBg;
  const _ServiceConfig(this.name, this.icon, this.color, this.lightBg, this.darkBg);
}