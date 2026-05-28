import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';

class PaymentFailedScreen extends StatefulWidget {
  const PaymentFailedScreen({super.key});

  @override
  State<PaymentFailedScreen> createState() => _PaymentFailedScreenState();
}

class _PaymentFailedScreenState extends State<PaymentFailedScreen>
    with TickerProviderStateMixin {

  // ── Controllers ────────────────────────────────────────────────────────────
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  late final AnimationController _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  late final AnimationController _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  late final AnimationController _particleCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..repeat();

  late final AnimationController _rippleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat();

  late final AnimationController _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  // ── Entry animations ───────────────────────────────────────────────────────
  late final Animation<double> _fadeIn = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut));

  late final Animation<Offset> _slideUp = Tween<Offset>(
          begin: const Offset(0, 0.18), end: Offset.zero)
      .animate(CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic)));

  late final Animation<double> _iconEntry = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.25, 1.0, curve: Curves.elasticOut));

  // ── Shake ──────────────────────────────────────────────────────────────────
  late final Animation<double> _shake =
      Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));

  // ── Pulse ring ─────────────────────────────────────────────────────────────
  late final Animation<double> _pulse = Tween<double>(begin: 0.96, end: 1.06)
      .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _entryCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _shakeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _rippleCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          _animatedBackground(),
          Column(
            children: [
              _header(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: Column(
                        children: [
                          const SizedBox(height: 36),
                          _iconSection(),
                          const SizedBox(height: 36),
                          _messageSection(),
                          const SizedBox(height: 36),
                          _errorCard(),
                          const SizedBox(height: 32),
                          _retryButton(),
                          const SizedBox(height: 14),
                          _cancelButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Animated background ────────────────────────────────────────────────────
  Widget _animatedBackground() => AnimatedBuilder(
        animation: _particleCtrl,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _FailureBgPainter(
            progress: _particleCtrl.value,
            isDark: _isDark,
          ),
        ),
      );

  // ── Header — app gradient theme ────────────────────────────────────────────
  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 22),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title
            const Expanded(
              child: Text(
                "Payment Status",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            // Failed badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    "Failed",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Icon section ───────────────────────────────────────────────────────────
  Widget _iconSection() => SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple rings
            ...List.generate(3, _rippleRing),

            // Outer pulsing ring
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935).withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Inner static ring
            Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE53935).withOpacity(0.10),
                  width: 1,
                ),
              ),
            ),

            // Main icon — shake + elastic scale entry
            AnimatedBuilder(
              animation: Listenable.merge([_shake, _iconEntry]),
              builder: (_, child) {
                final shakeOffset =
                    sin(_shake.value * pi * 4) * 6.0 * (1 - _shake.value);
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: Transform.scale(
                    scale: _iconEntry.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDark ? const Color(0xFF1E1012) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withOpacity(0.28),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(_isDark ? 0.4 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFE53935),
                  size: 58,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _rippleRing(int index) {
    final delay = index / 3.0;
    return AnimatedBuilder(
      animation: _rippleCtrl,
      builder: (_, __) {
        final progress = (_rippleCtrl.value - delay).clamp(0.0, 1.0);
        final size = 110.0 + progress * 80;
        final opacity = (1 - progress) * 0.18;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE53935).withOpacity(opacity),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }

  // ── Message section ────────────────────────────────────────────────────────
  Widget _messageSection() => Column(
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, child) => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: _isDark
                    ? [Colors.white70, Colors.white, Colors.white70]
                    : [Colors.black54, Colors.black87, Colors.black54],
                stops: [
                  (_shimmerCtrl.value - 0.35).clamp(0.0, 1.0),
                  _shimmerCtrl.value.clamp(0.0, 1.0),
                  (_shimmerCtrl.value + 0.35).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: child!,
            ),
            child: Text(
              "Payment Failed",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "We couldn't complete your transaction.\nDon't worry — no money was deducted.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color:
                  _isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );

  // ── Error detail card ──────────────────────────────────────────────────────
  Widget _errorCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.07),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(_isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _errorRow(
              icon: Icons.error_outline_rounded,
              iconColor: const Color(0xFFE53935),
              label: "Reason",
              value: "Transaction declined",
              valueColor: const Color(0xFFE53935),
            ),
            _divider(),
            _errorRow(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF4CAF50),
              label: "Amount charged",
              value: "₹0.00",
              valueColor: const Color(0xFF2E7D32),
            ),
            _divider(),
            _errorRow(
              icon: Icons.support_agent_rounded,
              iconColor: AppColors.primary,
              label: "Support",
              value: "Available 24/7",
            ),
          ],
        ),
      );

  Widget _errorRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.1),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 13),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: _isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ??
                    (_isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Divider(
        height: 1,
        thickness: 0.5,
        color: _isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.06),
      );

  // ── Retry button ───────────────────────────────────────────────────────────
  Widget _retryButton() => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppColors.gradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.38),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Try Again",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );

  // ── Go to Home button ──────────────────────────────────────────────────────
  Widget _cancelButton() => GestureDetector(
        onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            border: Border.all(
              color: _isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                size: 18,
                color: _isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                "Go to Home",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Background Painter
// ─────────────────────────────────────────────────────────────────────────────

class _FailureBgPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _FailureBgPainter({required this.progress, required this.isDark});

  static final _rng = Random(42);
  static final _particles = List.generate(12, (i) => (
        x: 0.1 + _rng.nextDouble() * 0.8,
        y: 0.05 + _rng.nextDouble() * 0.6,
        size: 1.5 + _rng.nextDouble() * 2.5,
        speed: 0.2 + _rng.nextDouble() * 0.5,
        phase: _rng.nextDouble() * 2 * pi,
      ));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Soft ambient blobs
    paint.color = const Color(0xFFE53935).withOpacity(
        isDark ? 0.04 + sin(progress * 2 * pi) * 0.015 : 0.03);
    canvas.drawCircle(
      Offset(size.width * 0.85 + sin(progress * 2 * pi) * 12,
          size.height * 0.12 + cos(progress * 2 * pi) * 8),
      size.width * 0.32,
      paint,
    );

    paint.color =
        const Color(0xFFE53935).withOpacity(isDark ? 0.025 : 0.018);
    canvas.drawCircle(
      Offset(size.width * 0.1 + cos(progress * 2 * pi) * 10,
          size.height * 0.75 + sin(progress * 2 * pi) * 12),
      size.width * 0.38,
      paint,
    );

    // Floating particles
    for (final p in _particles) {
      final angle = p.phase + progress * p.speed * 2 * pi;
      final x = p.x * size.width + sin(angle) * 10;
      final y = p.y * size.height -
          (progress * p.speed * size.height * 0.25) % size.height;
      final opacity =
          (0.3 + sin(progress * 2 * pi + p.phase) * 0.2).clamp(0.0, 0.6) *
              (isDark ? 0.6 : 0.4);
      paint.color = const Color(0xFFE53935).withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_FailureBgPainter o) =>
      o.progress != progress || o.isDark != isDark;
}