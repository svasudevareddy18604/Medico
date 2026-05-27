// lib/screens/care_seeker/processing_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/screens/care_seeker/order_success_screen.dart';
import 'package:medico/screens/care_seeker/payment_failed_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final bool isCOD;
  final Future<Map<String, dynamic>?> apiFuture;
  final int userId;
  final double subtotal, serviceCharge, discount, total;

  const ProcessingScreen({
    super.key,
    this.isCOD = false,
    required this.apiFuture,
    required this.userId,
    this.subtotal      = 0.0,
    this.serviceCharge = 0.0,
    this.discount      = 0.0,
    this.total         = 0.0,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  late final AnimationController _ringCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..repeat();

  late final AnimationController _ring2Ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  late final AnimationController _particleCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  late final AnimationController _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  late final AnimationController _waveCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  // FIX: _successCtrl drives a TweenAnimationBuilder, not a ScaleTransition
  // with CurvedAnimation(elasticOut) — that combination lets the value exceed
  // 1.0, which Flutter's matrix transform asserts against.
  late final AnimationController _successCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  late final Animation<double> _pulseAnim = Tween<double>(begin: 0.90, end: 1.10)
      .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  // ── State ────────────────────────────────────────────────────────────────
  int    _step      = 0;
  bool   _isDone    = false;
  bool   _hasError  = false;
  bool   _navigated = false;
  Timer? _stepTimer;

  List<(String, IconData)> get _steps => widget.isCOD
      ? [
          ("Placing your booking...",   Icons.medical_services_rounded),
          ("Confirming details...",     Icons.assignment_turned_in_rounded),
          ("Assigning caretakers...",   Icons.person_pin_circle_rounded),
          ("All services scheduled!",  Icons.check_circle_rounded),
        ]
      : [
          ("Initializing payment...",   Icons.currency_rupee_rounded),
          ("Securing transaction...",   Icons.lock_rounded),
          ("Confirming bookings...",    Icons.verified_rounded),
          ("Finalizing...",            Icons.check_circle_rounded),
        ];

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _startSteps();
    _waitForApi();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _ring2Ctrl.dispose();
    _particleCtrl.dispose();
    _shimmerCtrl.dispose();
    _waveCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  void _startSteps() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _step = (_step + 1) % (_steps.length - 1));
    });
  }

  Future<void> _waitForApi() async {
    try {
      final result = await widget.apiFuture;
      _stepTimer?.cancel();
      if (!mounted) return;

      if (result == null || result["success"] != true) { _goFailed(); return; }

      final rawOrders = result["orders"];
      if (rawOrders is! List || rawOrders.isEmpty) { _goFailed(); return; }

      final slot     = (result["slot"]     ?? "").toString();
      final date     = (result["date"]     ?? "").toString();
      final location = (result["location"] ?? "").toString();

      // Normalize orders — each order is ONE service
      final List<Map<String, dynamic>> orders = rawOrders.map((o) {
        final m = Map<String, dynamic>.from(o as Map);
        m["order_id"]   ??= m["orderId"];
        m["order_code"] ??= m["orderCode"] ?? "";
        if (slot.isNotEmpty)     m["slot"]     = slot;
        if (date.isNotEmpty)     m["date"]     = date;
        if (location.isNotEmpty) m["location"] = location;
        m["total"] ??= m["totalPrice"] ?? "0";
        final rawName = m["service_name"] ?? m["service_names"] ?? "";
        if (rawName is List) {
          m["service_name"] = rawName.isNotEmpty ? rawName.first.toString() : "";
        } else {
          m["service_name"] = rawName.toString();
        }
        return m;
      }).toList();

      final int    orderId   = int.tryParse(orders.first["order_id"].toString()) ?? 0;
      final String orderCode = (orders.first["order_code"] ?? "").toString();

      setState(() => _step = _steps.length - 1);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() => _isDone = true);
      _successCtrl.forward(); // drives TweenAnimationBuilder — safe with elastic
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted || _navigated) return;
      _navigated = true;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(
          orderId:       orderId,
          orderCode:     orderCode,
          orders:        orders,
          userId:        widget.userId,
          subtotal:      widget.subtotal,
          serviceCharge: widget.serviceCharge,
          discount:      widget.discount,
          total:         widget.total,
        )),
        (r) => r.isFirst,
      );
    } catch (e) {
      debugPrint("❌ ProcessingScreen error: $e");
      _stepTimer?.cancel();
      _goFailed();
    }
  }

  Future<void> _goFailed() async {
    if (!mounted) return;
    setState(() => _hasError = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PaymentFailedScreen()),
      (r) => r.isFirst);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(children: [
        _background(),
        SafeArea(child: Column(children: [
          _topBadge(),
          Expanded(child: Center(
            child: _hasError ? _errorBody() : _mainBody(),
          )),
          _bottomHint(),
        ])),
      ]),
    ),
  );

  // ── Animated gradient background ─────────────────────────────────────────
  Widget _background() => AnimatedBuilder(
    animation: _waveCtrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
            Color.lerp(AppColors.primary, const Color(0xFF021B2B),
                0.5 + sin(_waveCtrl.value * 2 * pi) * 0.15)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5 + sin(_waveCtrl.value * 2 * pi) * 0.1, 1.0],
        ),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _BackgroundBlobPainter(_waveCtrl.value),
      ),
    ),
  );

  // ── Top badge ────────────────────────────────────────────────────────────
  Widget _topBadge() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, child) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white70, Colors.white, Colors.white70],
              stops: [
                (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                _shimmerCtrl.value.clamp(0.0, 1.0),
                (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds),
            child: child!,
          ),
          child: Icon(
            widget.isCOD ? Icons.local_shipping_rounded : Icons.shield_rounded,
            color: Colors.white, size: 15),
        ),
        const SizedBox(width: 8),
        Text(
          widget.isCOD ? "Cash on Delivery" : "Secure Payment",
          style: const TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      ]),
    )),
  );

  // ── Main body ────────────────────────────────────────────────────────────
  Widget _mainBody() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _orbitIcon(),
      const SizedBox(height: 44),
      _statusText(),
      const SizedBox(height: 32),
      _stepProgress(),
    ]),
  );

  // ── Orbit icon ───────────────────────────────────────────────────────────
  // FIX: The crash was here. The original code did:
  //
  //   ScaleTransition(
  //     scale: _isDone ? _successScale : _pulseAnim,
  //     ...
  //   )
  //
  // where _successScale = CurvedAnimation(parent: _successCtrl,
  //                                       curve: Curves.elasticOut)
  //
  // Curves.elasticOut overshoots — it produces values > 1.0 while bouncing.
  // ScaleTransition passes this directly into a Matrix4 scale transform.
  // Flutter asserts t >= 0.0 && t <= 1.0 on ParametricCurve.transform,
  // which fires for any value above 1.0.
  //
  // SOLUTION: Use TweenAnimationBuilder instead of ScaleTransition for the
  // success pop.  TweenAnimationBuilder drives the Tween<double> directly and
  // passes the animated value to your builder — it does NOT go through
  // ParametricCurve.transform, so elastic overshoot is handled safely.
  Widget _orbitIcon() => SizedBox(width: 200, height: 200,
    child: Stack(alignment: Alignment.center, children: [

      AnimatedBuilder(animation: _ringCtrl, builder: (_, __) => Transform.rotate(
        angle: _ringCtrl.value * 2 * pi,
        child: CustomPaint(size: const Size(190, 190),
            painter: _OrbitRingPainter(radius: 92, dotSize: 6,
                color: Colors.white.withOpacity(0.7))),
      )),

      AnimatedBuilder(animation: _ring2Ctrl, builder: (_, __) => Transform.rotate(
        angle: -_ring2Ctrl.value * 2 * pi,
        child: CustomPaint(size: const Size(160, 160),
            painter: _OrbitRingPainter(radius: 77, dotSize: 4,
                color: Colors.white.withOpacity(0.45))),
      )),

      AnimatedBuilder(animation: _particleCtrl, builder: (_, __) =>
          CustomPaint(size: const Size(200, 200),
              painter: _FloatingParticlePainter(_particleCtrl.value))),

      Container(width: 130, height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.2),
                  blurRadius: 40, spreadRadius: 10),
            ],
          )),

      // ── Core icon bubble ─────────────────────────────────────────────
      // When NOT done: use ScaleTransition with easeInOut pulse (safe — stays in [0,1]).
      // When done: use TweenAnimationBuilder with elasticOut (safe — builder
      //            receives the raw double; no ParametricCurve.transform assert).
      if (!_isDone)
        ScaleTransition(
          scale: _pulseAnim,
          child: _iconBubble(key: ValueKey('idle_$_step')),
        )
      else
        TweenAnimationBuilder<double>(
          key: const ValueKey('success'),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,   // ← safe here; builder receives the value directly
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: _iconBubble(key: const ValueKey('done')),
        ),
    ]),
  );

  Widget _iconBubble({required Key key}) => AnimatedSwitcher(
    key: key,
    duration: const Duration(milliseconds: 450),
    switchInCurve: Curves.easeOutBack,   // easeOutBack stays in [0,1] — safe for ScaleTransition
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child)),
    child: Container(
      key: ValueKey(_isDone ? 'done_bubble' : 'step_$_step'),
      width: 110, height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18),
              blurRadius: 30, spreadRadius: 2, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(
        _isDone ? Icons.check_circle_rounded : _steps[_step].$2,
        color: _isDone ? const Color(0xFF16A34A) : AppColors.primary,
        size: 56),
    ),
  );

  // ── Status text ──────────────────────────────────────────────────────────
  Widget _statusText() => Column(children: [
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        _isDone
            ? (widget.isCOD ? "All Set! 🎉" : "Payment Done! 🎉")
            : "Please Wait",
        key: ValueKey("title_$_isDone"),
        style: const TextStyle(color: Colors.white, fontSize: 28,
            fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
    ),
    const SizedBox(height: 10),
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Text(
        _isDone
            ? (widget.isCOD
                ? "Your booking is confirmed & scheduled"
                : "Your booking is confirmed")
            : _steps[_step].$1,
        key: ValueKey(_isDone ? "done_sub" : "step_$_step"),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.82),
            fontSize: 15, height: 1.45),
      ),
    ),
  ]);

  // ── Step progress ────────────────────────────────────────────────────────
  Widget _stepProgress() {
    final activeSteps = _steps.length - 1;
    final current = _isDone ? activeSteps : _step;

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          height: 6,
          child: LinearProgressIndicator(
            value: current / activeSteps,
            backgroundColor: Colors.white.withOpacity(0.20),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_steps.length - 1, (i) {
          final done   = i < current;
          final active = i == current && !_isDone;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width:  done || _isDone ? 28 : (active ? 20 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: done || _isDone
                  ? Colors.white
                  : active
                      ? Colors.white.withOpacity(0.75)
                      : Colors.white.withOpacity(0.30),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          "Step ${(current + 1).clamp(1, activeSteps)} of $activeSteps",
          key: ValueKey(current),
          style: TextStyle(color: Colors.white.withOpacity(0.6),
              fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    ]);
  }

  // ── Error body ───────────────────────────────────────────────────────────
  Widget _errorBody() => Column(mainAxisSize: MainAxisSize.min, children: [
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(width: 90, height: 90,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15)),
        child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48)),
    ),
    const SizedBox(height: 24),
    const Text("Something went wrong",
        style: TextStyle(color: Colors.white, fontSize: 22,
            fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text("Redirecting you back...",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 14)),
  ]);

  // ── Bottom hint ──────────────────────────────────────────────────────────
  Widget _bottomHint() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Text(
          widget.isCOD
              ? "Be available at your location when the caretaker arrives."
              : "Do not close or switch apps until confirmation is complete.",
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.45),
        )),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

class _BackgroundBlobPainter extends CustomPainter {
  final double t;
  _BackgroundBlobPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = Colors.white.withOpacity(0.04 + sin(t * 2 * pi) * 0.02);
    canvas.drawCircle(
      Offset(size.width * 0.85 + sin(t * 2 * pi) * 18,
             size.height * 0.15 + cos(t * 2 * pi) * 12),
      size.width * 0.38, paint);

    paint.color = Colors.white.withOpacity(0.03 + cos(t * 2 * pi) * 0.015);
    canvas.drawCircle(
      Offset(size.width * 0.12 + cos(t * 2 * pi) * 14,
             size.height * 0.78 + sin(t * 2 * pi) * 16),
      size.width * 0.42, paint);

    paint.color = Colors.white.withOpacity(0.025);
    canvas.drawCircle(
      Offset(size.width * 0.5 + sin(t * pi) * 22,
             size.height * 0.48 + cos(t * pi) * 18),
      size.width * 0.28, paint);
  }

  @override
  bool shouldRepaint(_BackgroundBlobPainter o) => o.t != t;
}

class _OrbitRingPainter extends CustomPainter {
  final double radius;
  final double dotSize;
  final Color  color;
  const _OrbitRingPainter({required this.radius, required this.dotSize, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(center, radius,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color       = color.withOpacity(0.35));

    canvas.drawCircle(
      Offset(center.dx + radius, center.dy), dotSize,
      Paint()..color = color);

    canvas.drawCircle(
      Offset(center.dx - radius, center.dy), dotSize * 0.5,
      Paint()..color = color.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(_OrbitRingPainter o) => false;
}

class _FloatingParticlePainter extends CustomPainter {
  final double progress;
  _FloatingParticlePainter(this.progress);

  static final _rng = Random(13);
  static final _cfg = List.generate(8, (i) => (
    angle:  (i / 8) * 2 * pi,
    r:      55.0 + _rng.nextDouble() * 30,
    size:   2.0 + _rng.nextDouble() * 2.5,
    phase:  _rng.nextDouble() * 2 * pi,
  ));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in _cfg) {
      final angle = p.angle + progress * 2 * pi;
      final r     = p.r + sin(progress * 2 * pi + p.phase) * 8;
      final x     = center.dx + cos(angle) * r;
      final y     = center.dy + sin(angle) * r;
      final opacity = 0.35 + sin(progress * 2 * pi + p.phase) * 0.3;
      canvas.drawCircle(Offset(x, y), p.size,
          Paint()..color = Colors.white.withOpacity(opacity.clamp(0.0, 0.9)));
    }
  }

  @override
  bool shouldRepaint(_FloatingParticlePainter o) => o.progress != progress;
}