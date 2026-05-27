import 'package:flutter/material.dart';

class AppColors {

  /* =========================================================
     BRAND COLORS
  ========================================================= */

  static const Color primary = Color(0xFF0B8FAC);

  static const Color secondary = Color(0xFF14B8A6);

  static const Color accent = Color(0xFF38BDF8);

  static const Color dark = Color(0xFF0F172A);

  static const Color lightBg = Color(0xFFF4F8FB);

  static const Color cardBg = Colors.white;

  static const Color border = Color(0xFFE2E8F0);

  static const Color muted = Color(0xFF94A3B8);

  /* =========================================================
     STATUS COLORS
  ========================================================= */

  static const Color success = Color.fromARGB(255, 178, 239, 200);

  static const Color warning = Color(0xFFF59E0B);

  static const Color danger = Color(0xFFEF4444);

  static const Color info = Color(0xFF2563EB);

  /* =========================================================
     MAIN GRADIENT
     IMPORTANT:
     KEEP NAME = gradient
     OTHERWISE WHOLE APP BREAKS
  ========================================================= */

  static const LinearGradient gradient = LinearGradient(
    colors: [
      Color(0xFF0B8FAC),
      Color(0xFF14B8A6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /* =========================================================
     EXTRA PREMIUM GRADIENTS
  ========================================================= */

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF021B2B),
      Color(0xFF033B57),
      Color(0xFF0B8FAC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: [
      Color(0xFFF0FDFF),
      Color(0xFFE0F7FA),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [
      Color(0xFF020617),
      Color(0xFF0F172A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /* =========================================================
     SHADOWS
  ========================================================= */

  static List<BoxShadow> cardShadow = [

    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),

  ];

  static List<BoxShadow> glowShadow = [

    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 24,
      spreadRadius: 1,
      offset: const Offset(0, 8),
    ),

  ];

}