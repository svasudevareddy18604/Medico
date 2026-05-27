import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config/api.dart';
import 'login_page.dart';
import 'screens/admin/admin_homepage.dart';
import 'screens/care_seeker/care_seeker_home.dart';
import 'screens/care_taker/care_taker_home.dart';
import 'screens/care_taker/caretaker_setup_screen.dart';
import 'screens/care_taker/document_upload_screen.dart';
import 'screens/care_taker/pending_approval_screen.dart';
import 'screens/care_taker/add_location_screen.dart';
import 'screens/care_taker/rejected_screen.dart';
import 'package:medico/utils/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _bg   = _ctrl(3000, repeat: true);
  late final AnimationController _logo = _ctrl(1000);
  late final AnimationController _text = _ctrl(1200);
  late final AnimationController _prog = _ctrl(4200);
  late final AnimationController _part = _ctrl(3000, repeat: true);
  late final AnimationController _pulse= _ctrl(1600, repeat: true, reverse: true);
  late final AnimationController _spin = _ctrl(8000, repeat: true);

  AnimationController _ctrl(int ms, {bool repeat = false, bool reverse = false}) {
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
    if (repeat) reverse ? c.repeat(reverse: true) : c.repeat();
    return c;
  }

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _play();
    Future.delayed(const Duration(milliseconds: 4500), _navigate);
  }

  Future<void> _play() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logo.forward();
    _prog.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    _text.forward();
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final p      = await SharedPreferences.getInstance();
    final loggedIn = p.getBool("is_logged_in") ?? false;
    final userId   = p.getInt("user_id") ?? 0;
    final role     = p.getString("role") ?? "";
    if (!mounted) return;
    if (!loggedIn)          { _go(const LoginPage()); return; }
    if (role == "admin")    { _go(AdminHomePage(userId: userId)); return; }
    if (role == "care_seeker") { _go(CareSeekerHome(userId: userId)); return; }
    if (role == "care_taker") {
      try {
        final res  = await http.get(Uri.parse("${Api.baseUrl}/caretaker/status/$userId"));
        final data = jsonDecode(res.body);
        final pc = data["profile_completed"]  ?? 0;
        final du = data["documents_uploaded"] ?? 0;
        final st = data["approval_status"]    ?? "pending";
        final ct = data["caregiver_type"]     ?? "";
        final la = data["location_added"]     ?? 0;
        if (pc == 0) { _go(CaretakerSetupScreen(userId: userId)); return; }
        if (du == 0) { _go(DocumentUploadScreen(userId: userId, caregiverType: ct)); return; }
        if (st == "rejected") { _go(RejectedScreen(reason: data["reject_reason"] ?? "", userId: userId, caregiverType: ct)); return; }
        if (st == "pending")  { _go(const PendingApprovalScreen()); return; }
        if (la == 0) { _go(AddLocationScreen(userId: userId, category: ct, onLocationAdded: () {})); return; }
        _go(CareTakerHome(userId: userId, category: ct));
      } catch (_) { _go(CareTakerHome(userId: userId, category: "")); }
    }
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 700),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    for (final c in [_bg, _logo, _text, _prog, _part, _pulse, _spin]) c.dispose();
    super.dispose();
  }

  // ── Tween helpers ─────────────────────────────────────────────────────────
  Animation<T> _tween<T>(AnimationController c, Tween<T> t, {Curve curve = Curves.easeOut}) =>
      t.animate(CurvedAnimation(parent: c, curve: curve));
  Animation<T> _interval<T>(AnimationController c, Tween<T> t, double b, double e) =>
      t.animate(CurvedAnimation(parent: c, curve: Interval(b, e, curve: Curves.easeOut)));

  // ── Brand colors (from AppColors) ────────────────────────────────────────
  static const _c1 = AppColors.primary;    // 0xFF0B8FAC
  static const _c2 = AppColors.secondary;  // 0xFF14B8A6
  static const _c3 = AppColors.accent;     // 0xFF38BDF8
  static const _c4 = Color(0xFF7DD3FC);    // sky-300 — light accent highlight

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ── Animations ───────────────────────────────────────────────────────
    final logoScale   = _tween(_logo, Tween(begin: 0.0, end: 1.0), curve: Curves.elasticOut);
    final logoOpacity = _tween(_logo, Tween(begin: 0.0, end: 1.0));
    final logoSlide   = _tween(_logo, Tween(begin: const Offset(0, .35), end: Offset.zero), curve: Curves.easeOutCubic);
    final nameOpacity = _interval(_text, Tween(begin: 0.0, end: 1.0), 0.0, 0.5);
    final nameSlide   = _interval(_text, Tween(begin: const Offset(0, .4), end: Offset.zero), 0.0, 0.6);
    final tagOpacity  = _interval(_text, Tween(begin: 0.0, end: 1.0), 0.3, 0.7);
    final tagSlide    = _interval(_text, Tween(begin: const Offset(0, .4), end: Offset.zero), 0.3, 0.7);
    final badgeOpacity= _interval(_text, Tween(begin: 0.0, end: 1.0), 0.6, 1.0);
    final progressVal = _tween(_prog, Tween(begin: 0.0, end: 1.0), curve: Curves.easeInOutCubic);
    final pulse       = _tween(_pulse, Tween(begin: 1.0, end: 1.3), curve: Curves.easeInOut);
    final pulse2      = Tween(begin: 1.15, end: 1.55).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    final orb1Y       = _tween(_bg, Tween(begin: 0.0, end: 28.0), curve: Curves.easeInOut);
    final orb2Y       = _tween(_bg, Tween(begin: 28.0, end: 0.0), curve: Curves.easeInOut);
    final spinVal     = _tween(_spin, Tween(begin: 0.0, end: 2 * pi));

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bg, _logo, _text, _prog, _part, _pulse, _spin]),
        builder: (_, __) => Stack(fit: StackFit.expand, children: [

          // ── Deep dark background from AppColors.dark ──────────────────
          Container(decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.dark, const Color(0xFF0C2233), _c1],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          )),

          // ── Radial glows ──────────────────────────────────────────────
          Opacity(opacity: 0.16, child: Container(decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.5, -0.6), radius: 1.0,
              colors: [_c3, Colors.transparent],
            ),
          ))),
          Opacity(opacity: 0.10, child: Container(decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.7, 0.8), radius: 0.9,
              colors: [_c4, Colors.transparent],
            ),
          ))),

          // ── Floating orbs ─────────────────────────────────────────────
          Positioned(top: -70 + orb1Y.value, left: -50,
              child: _orb(240, _c3.withOpacity(0.12))),
          Positioned(bottom: -50 + orb2Y.value, right: -30,
              child: _orb(200, _c2.withOpacity(0.14))),
          Positioned(top: size.height * 0.40 + orb1Y.value * 0.4, right: -20,
              child: _orb(120, _c1.withOpacity(0.10))),

          // ── Spinning ring ─────────────────────────────────────────────
          Center(child: Transform.rotate(
            angle: spinVal.value,
            child: Container(width: 310, height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _c3.withOpacity(0.06), width: 1.2),
              )),
          )),
          Center(child: Transform.rotate(
            angle: -spinVal.value * 0.6,
            child: Container(width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _c2.withOpacity(0.08), width: 1),
              )),
          )),

          // ── Particles ─────────────────────────────────────────────────
          ..._particles(size),

          // ── Subtle grid ───────────────────────────────────────────────
          Opacity(opacity: 0.03, child: CustomPaint(
            size: Size(size.width, size.height), painter: _GridPainter())),

          // ═══════════════════════════════════════════════════════════════
          //  MAIN CONTENT
          // ═══════════════════════════════════════════════════════════════
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [

            // ── LOGO ──────────────────────────────────────────────────
            SlideTransition(position: logoSlide, child: FadeTransition(
              opacity: logoOpacity, child: ScaleTransition(scale: logoScale,
              child: Stack(alignment: Alignment.center, children: [

                // Outer glow ring
                ScaleTransition(scale: pulse2, child: Container(
                  width: 170, height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _c3.withOpacity(0.12), width: 1.5),
                  ),
                )),

                // Inner pulse ring
                ScaleTransition(scale: pulse, child: Container(
                  width: 155, height: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [_c1.withOpacity(0.18), Colors.transparent]),
                    border: Border.all(color: _c2.withOpacity(0.30), width: 1.5),
                  ),
                )),

                // Logo container — gradient ring border, no white bg
                Container(
                  width: 128, height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_c1.withOpacity(0.25), _c2.withOpacity(0.15)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: _c3.withOpacity(0.35), width: 2),
                    boxShadow: [
                      BoxShadow(color: _c1.withOpacity(0.55), blurRadius: 45, spreadRadius: 6),
                      BoxShadow(color: _c3.withOpacity(0.20), blurRadius: 20),
                    ],
                  ),
                  child: ClipOval(child: Image.asset("assets/logo.png", fit: BoxFit.contain)),
                ),
              ]),
            ))),

            const SizedBox(height: 44),

            // ── APP NAME ──────────────────────────────────────────────
            SlideTransition(position: nameSlide, child: FadeTransition(
              opacity: nameOpacity,
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Colors.white, _c4],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ).createShader(b),
                child: const Text("MEDICO", style: TextStyle(
                  fontSize: 52, fontWeight: FontWeight.w900,
                  letterSpacing: 12, color: Colors.white, height: 1.0,
                )),
              ),
            )),

            const SizedBox(height: 10),

            // ── TAGLINE ───────────────────────────────────────────────
            SlideTransition(position: tagSlide, child: FadeTransition(
              opacity: tagOpacity,
              child: const Text("Healthcare Services at Home",
                style: TextStyle(fontSize: 15, color: Colors.white54,
                    letterSpacing: 2.0, fontWeight: FontWeight.w300)),
            )),

            const SizedBox(height: 28),

            // ── TRUST BADGES ──────────────────────────────────────────
            FadeTransition(opacity: badgeOpacity, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                _TrustBadge(icon: Icons.verified_user_rounded,   label: "Trusted"),
                _TrustDivider(),
                _TrustBadge(icon: Icons.workspace_premium_rounded, label: "Certified"),
                _TrustDivider(),
                _TrustBadge(icon: Icons.favorite_rounded,        label: "Caring"),
              ]),
            )),
          ]),

          // ── PROGRESS BAR ──────────────────────────────────────────────
          Positioned(bottom: 55, left: 44, right: 44,
            child: FadeTransition(opacity: nameOpacity, child: Column(children: [
              Stack(children: [
                Container(height: 3.5, decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                )),
                FractionallySizedBox(widthFactor: progressVal.value,
                  child: Container(height: 3.5, decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(colors: [_c1, _c2, _c3]),
                    boxShadow: [BoxShadow(color: _c2.withOpacity(0.7), blurRadius: 10)],
                  )),
                ),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final t = ((_part.value - i * 0.33) % 1.0);
                  final b = sin(t * pi * 2).abs();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Transform.translate(
                      offset: Offset(0, -8 * b),
                      child: Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.25 + 0.75 * b),
                          boxShadow: [BoxShadow(color: _c2.withOpacity(b * 0.9), blurRadius: 6)],
                        )),
                    ),
                  );
                }),
              ),
            ])),
          ),

          // ── VERSION ───────────────────────────────────────────────────
          Positioned(bottom: 20, left: 0, right: 0,
            child: FadeTransition(opacity: badgeOpacity,
              child: const Text("v1.0.0", textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 2)))),
        ]),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 50, spreadRadius: 12)],
    ),
  );

  List<Widget> _particles(Size size) {
    final rng = Random(42);
    return List.generate(22, (i) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final s = 1.5 + rng.nextDouble() * 3.5;
      final phase = rng.nextDouble();
      final t = ((_part.value + phase) % 1.0);
      final b = sin(t * pi * 2).abs();
      final color = [_c3, _c2, _c4, Colors.white][i % 4];
      return Positioned(left: x, top: y - t * 80,
        child: Opacity(opacity: b * 0.45,
          child: Container(width: s, height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 5)],
            ))));
    });
  }
}

// ── Trust badge widget ────────────────────────────────────────────────────────

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [AppColors.accent, AppColors.secondary],
        ).createShader(b),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
        color: Colors.white70, fontSize: 10.5,
        letterSpacing: 0.8, fontWeight: FontWeight.w500,
      )),
    ]),
  );
}

class _TrustDivider extends StatelessWidget {
  const _TrustDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 28,
    color: Colors.white.withOpacity(0.15),
  );
}

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white..strokeWidth = 0.4;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}