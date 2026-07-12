import 'dart:math';
import 'package:flutter/material.dart';

/// Instagram/Twitter-style scalloped "verified" badge —
/// an 8-point seal shape with a white checkmark, blue fill.
class VerifiedBadge extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  const VerifiedBadge({super.key, this.size = 16, this.onTap});

  static const Color start = Color(0xFF1D9BF0);
  static const Color end   = Color(0xFF0A7CD6);

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BadgePainter(),
        child: Center(
          child: Icon(Icons.check_rounded, size: size * 0.56, color: Colors.white),
        ),
      ),
    );
    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = outerR * 0.86;
    const points = 8;

    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerR : innerR;
      final angle = (pi / points) * i - pi / 2 + (pi / points);
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [VerifiedBadge.start, VerifiedBadge.end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: outerR));

    canvas.drawShadow(path, VerifiedBadge.start.withOpacity(0.5), 2, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small pill version — used for the "Professional" chip.
class VerifiedChip extends StatelessWidget {
  final VoidCallback? onTap;
  const VerifiedChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: VerifiedBadge.start.withOpacity(0.10),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: VerifiedBadge.start.withOpacity(0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const VerifiedBadge(size: 12),
          const SizedBox(width: 4),
          Text(
            "Professional",
            style: TextStyle(
              fontSize: 9.5,
              color: VerifiedBadge.start,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      ),
    );
  }
}