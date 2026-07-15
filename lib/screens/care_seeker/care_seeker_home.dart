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
  int _currentPromoPage = 0;

  final GlobalKey<CartScreenState> _cartKey = GlobalKey<CartScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeNotifier.addListener(_onThemeChange);

    _screens = [
      const _HomeBodyPlaceholder(),
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

  // ---------------------------------------------------------------------
  // ADDRESS LOADING LOGIC
  //
  // Key used to persist the last known address locally:
  //   "user_location_<userId>"
  //
  // Key used to track an EXPLICIT delete from the location screen:
  //   "address_deleted_<userId>"
  //
  // Rule: if the server call returns an empty address, we only clear the
  // cached address (and show "Add Address") when the user has explicitly
  // deleted it from CareSeekerLocation. If that flag isn't set (e.g. right
  // after a fresh login where the server call is empty/slow/fails), we keep
  // showing the last cached address instead of wiping it.
  //
  // IMPORTANT: In careseeker_location.dart, wherever you currently delete
  // the address (your deleteAddress() function), add:
  //
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool("address_deleted_${widget.userId}", true);
  //
  // And wherever the user successfully SETS/ADDS a new address, add:
  //
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool("address_deleted_${widget.userId}", false);
  //
  // so a future delete is tracked correctly again.
  // ---------------------------------------------------------------------
  Future<void> _loadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final key = "user_location_${widget.userId}";
    final deletedKey = "address_deleted_${widget.userId}";

    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/user/address/${widget.userId}"));
      if (res.statusCode == 200) {
        final addr = (jsonDecode(res.body)["address"] ?? "").toString().trim();

        if (addr.isNotEmpty) {
          // Server has a real address — cache it and reset the deleted flag.
          await prefs.setString(key, addr);
          await prefs.setBool(deletedKey, false);
          if (mounted) setState(() => location = addr);
          return;
        }

        // Server returned no address. Only wipe the cache if the user
        // actually deleted it from the location screen.
        final wasDeleted = prefs.getBool(deletedKey) ?? false;
        if (wasDeleted) {
          await prefs.remove(key);
          if (mounted) setState(() => location = "Add Address");
          return;
        }
        // else: fall through and use whatever is cached locally, so
        // logging out/in doesn't make a saved address disappear.
      }
    } catch (_) {
      // network/error — fall through to cached value below
    }

    final saved = prefs.getString(key) ?? "";
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

  void _onTabTap(int i) {
    setState(() => selectedIndex = i);
    switch (i) {
      case 0: _loadLocation(); break;
      case 1:
        _cartKey.currentState?.refresh();
        _loadCartCount();
        break;
      default: break;
    }
  }

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
            // Re-fetch the active address whenever we return from the
            // location screen. If the address was explicitly deleted there,
            // _loadLocation() will now correctly show "Add Address". If it
            // wasn't deleted, the cached address is preserved.
            await _loadLocation();
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

  static const List<List<Color>> _promoGradients = [
    [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    [Color(0xFF1A2980), Color(0xFF26D0CE)],
    [Color(0xFF134E5E), Color(0xFF71B280)],
    [Color(0xFF232526), Color(0xFF414345)],
  ];

  Widget _buildPromoCarousel() {
    if (promotions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 188,
          child: PageView.builder(
            controller: promoController,
            itemCount: promotions.length,
            onPageChanged: (i) => setState(() => _currentPromoPage = i),
            itemBuilder: (context, index) {
              final promo = promotions[index];
              final media = promo['media']?.toString();
              String? promoImageUrl;
              if (media != null && media.trim().isNotEmpty) {
                final base = Api.imageBase.endsWith("/")
                    ? Api.imageBase.substring(0, Api.imageBase.length - 1)
                    : Api.imageBase;
                promoImageUrl =
                    "$base${media.trim().startsWith("/") ? media.trim() : "/${media.trim()}"}";
              }
              final gradient = _promoGradients[index % _promoGradients.length];
              final title = (promo['title'] ?? "Special Offer").toString();
              final subtitle = (promo['subtitle'] ?? "Limited time offer").toString();

              return AnimatedBuilder(
                animation: promoController,
                builder: (context, child) {
                  double scale = 1.0;
                  if (promoController.position.haveDimensions) {
                    final page = promoController.page ?? index.toDouble();
                    scale = (1 - ((page - index).abs() * 0.05)).clamp(0.95, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: gradient.last.withOpacity(0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -30,
                          top: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 20,
                          bottom: -40,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        if (promoImageUrl != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 130,
                            child: ShaderMask(
                              shaderCallback: (rect) => LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                                stops: const [0.0, 0.35],
                              ).createShader(rect),
                              blendMode: BlendMode.dstIn,
                              child: Image.network(promoImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox()),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8),
                                ),
                                child: const Text("LIMITED OFFER",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6)),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          height: 1.18)),
                                  const SizedBox(height: 3),
                                  Text(subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.78),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Book Now",
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 13),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promotions.length, (i) {
            final active = i == _currentPromoPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    final bodies = [
      _buildHomeBody(),
      _screens[1],
      _screens[2],
      _screens[3],
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

class _HomeBodyPlaceholder extends StatelessWidget {
  const _HomeBodyPlaceholder();
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ServiceConfig {
  final String name; final IconData icon; final Color color, lightBg, darkBg;
  const _ServiceConfig(this.name, this.icon, this.color, this.lightBg, this.darkBg);
}