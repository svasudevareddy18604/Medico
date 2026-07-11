import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'care_seeker_home.dart';
import 'package:medico/utils/app_colors.dart';

class FeedbackSuccessScreen extends StatefulWidget {
  const FeedbackSuccessScreen({super.key});

  @override
  State<FeedbackSuccessScreen> createState() =>
      _FeedbackSuccessScreenState();
}

class _FeedbackSuccessScreenState extends State<FeedbackSuccessScreen>
    with TickerProviderStateMixin {
  static const Color successGreen = Color(0xFF0F9D58);
  static const int redirectSeconds = 3;

  // Icon entrance (pop + check draw)
  late final AnimationController _iconController;
  late final Animation<double> _iconScale;
  late final Animation<double> _checkProgress;

  // Gentle continuous pulse ring behind the icon
  late final AnimationController _ringController;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;

  // Burst of particles radiating from the icon
  late final AnimationController _burstController;
  late final List<_Particle> _particles;

  // Staggered text entrance
  late final AnimationController _textController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _messageFade;
  late final Animation<Offset> _messageSlide;

  // Countdown progress bar
  late final AnimationController _countdownController;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_iconController);
    _checkProgress = CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _ringScale = Tween<double>(begin: 0.9, end: 1.6).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );
    _ringOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    final rand = Random();
    _particles = List.generate(10, (i) {
      final angle = (2 * pi / 10) * i + rand.nextDouble() * 0.3;
      return _Particle(
        angle: angle,
        distance: 55 + rand.nextDouble() * 25,
        size: 4 + rand.nextDouble() * 4,
        color: [
          successGreen,
          AppColors.primary,
          const Color(0xFFFFC107),
        ][i % 3],
      );
    });
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _titleFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    _messageFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _messageSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: redirectSeconds),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    _iconController.forward();
    _burstController.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _textController.forward();
    _countdownController.forward();
    await redirectToHome();
  }

  @override
  void dispose() {
    _iconController.dispose();
    _ringController.dispose();
    _burstController.dispose();
    _textController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> redirectToHome() async {
    await Future.delayed(const Duration(seconds: redirectSeconds));

    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt("user_id") ?? 0;

    if (!mounted) return;

    if (userId == 0) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => CareSeekerHome(userId: userId),
      ),
      (route) => false,
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.verified_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text(
            "Feedback Submitted",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── ANIMATED ICON + BURST + RING ──────────────────────────────────
  Widget _successIcon(bool isDark) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (context, child) {
              return Transform.scale(
                scale: _ringScale.value,
                child: Opacity(
                  opacity: _ringOpacity.value,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: successGreen, width: 2.5),
                    ),
                  ),
                ),
              );
            },
          ),

          // Particle burst
          AnimatedBuilder(
            animation: _burstController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(220, 220),
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _burstController.value,
                ),
              );
            },
          ),

          // Soft glow backdrop
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: successGreen.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: successGreen.withOpacity(isDark ? 0.3 : 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Pop-in check circle with drawing checkmark
          ScaleTransition(
            scale: _iconScale,
            child: SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _CheckCirclePainter(
                  progress: _checkProgress.value,
                  color: successGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BODY ─────────────────────────────────────────────────────────
  Widget _body(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_iconController, _ringController, _burstController]),
                builder: (context, _) => _successIcon(isDark),
              ),

              const SizedBox(height: 18),

              // Title
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Text(
                    "Thank You!",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Message
              FadeTransition(
                opacity: _messageFade,
                child: SlideTransition(
                  position: _messageSlide,
                  child: Text(
                    "Your feedback has been submitted successfully.\nWe appreciate your time and support.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 42),

              // Countdown progress + redirect text
              FadeTransition(
                opacity: _messageFade,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 160,
                        height: 6,
                        child: AnimatedBuilder(
                          animation: _countdownController,
                          builder: (context, _) => LinearProgressIndicator(
                            value: _countdownController.value,
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Redirecting to home...",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _header(),
          _body(context),
        ],
      ),
    );
  }
}

// ── PARTICLE MODEL ───────────────────────────────────────────────────
class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

// ── PARTICLE BURST PAINTER ───────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Ease-out curve for travel, fade out toward the end
    final travel = Curves.easeOut.transform(progress);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final dx = cos(p.angle) * p.distance * travel;
      final dy = sin(p.angle) * p.distance * travel;
      final position = center + Offset(dx, dy);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, p.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── CHECK CIRCLE PAINTER (draws circle outline + checkmark) ──────────
class _CheckCirclePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _CheckCirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Filled circle backdrop
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // Checkmark path
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p1 = Offset(size.width * 0.28, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.68);
    final p3 = Offset(size.width * 0.74, size.height * 0.34);

    final path = Path()..moveTo(p1.dx, p1.dy);

    final totalLen = (p2 - p1).distance + (p3 - p2).distance;
    final drawLen = totalLen * progress.clamp(0.0, 1.0);

    final firstLen = (p2 - p1).distance;
    if (drawLen <= firstLen) {
      final t = firstLen == 0 ? 0 : drawLen / firstLen;
      final pt = Offset.lerp(p1, p2, t.toDouble())!;
      path.lineTo(pt.dx, pt.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final remaining = drawLen - firstLen;
      final secondLen = (p3 - p2).distance;
      final t = secondLen == 0 ? 0 : remaining / secondLen;
      final pt = Offset.lerp(p2, p3, t.clamp(0.0, 1.0).toDouble())!;
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CheckCirclePainter oldDelegate) =>
      oldDelegate.progress != progress;
}