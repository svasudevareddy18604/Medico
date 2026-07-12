import 'package:flutter/material.dart';

/// Classic "blue tick" verified badge — Twitter/Instagram style.
class VerifiedBadge extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  const VerifiedBadge({super.key, this.size = 16, this.onTap});

  // True platform-blue, deliberately distinct from AppColors.primary/secondary.
  static const Color start = Color(0xFF1D9BF0);
  static const Color end   = Color(0xFF0A7CD6);

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: start.withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, size: size * 0.66, color: Colors.white),
    );
    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
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
          const VerifiedBadge(size: 11),
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