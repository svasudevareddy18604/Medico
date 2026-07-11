import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medico/utils/app_colors.dart';
import 'config/api.dart';
import 'services/fcm_sync.dart'; // ← ADDED: shared FCM sync helper
import 'screens/care_seeker/care_seeker_home.dart';
import 'screens/admin/admin_homepage.dart';
import 'splash_screen.dart';
import 'register_page.dart';
import 'terms_conditions.dart';
import 'forgot_password_page.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true, loading = false, acceptTerms = false;

  // ── TOAST ────────────────────────────────────────────────────────────────
  void showToast(String msg, {ToastType type = ToastType.error}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: msg,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  // ── LOGIN ────────────────────────────────────────────────────────────────
  Future<void> loginUser() async {
    if (!acceptTerms) {
      return showToast("Please accept Terms & Conditions", type: ToastType.warning);
    }
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      return showToast("Enter email and password", type: ToastType.warning);
    }

    try {
      setState(() => loading = true);

      // ✅ FIX: Login immediately — no FCM wait before hitting backend.
      // Previously getFcmToken() ran FIRST and awaited requestPermission()
      // + a Firebase network round-trip (~1–3 s on cold start) before
      // even sending the login request. Now we skip it entirely here.
      final response = await http.post(
        Uri.parse("${Api.baseUrl}/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email":    emailController.text.trim(),
          "password": passwordController.text.trim(),
          // fcm_token intentionally omitted — sent in background after nav
        }),
      );

      setState(() => loading = false);
      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        return showToast(data["message"] ?? "Login failed", type: ToastType.error);
      }

      final int    userId = data["id"];
      final String role   = data["role"];

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("user_id", userId);
      await prefs.setString("role", role);
      await prefs.setBool("is_logged_in", true);

      // ✅ FIX: FCM sync runs in background via shared helper — does NOT
      // block navigation. Same function is also called from splash_screen.dart
      // on every subsequent app open, so the token stays fresh even when
      // this login screen never runs again for a returning user.
      syncFcmToken(userId);

      // Local notification / foreground-message setup (unrelated to token sync).
      setupFCMWithUser(userId);

      showToast("Welcome back! Login successful", type: ToastType.success);
      if (!mounted) return;

      // Navigate by role
      if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminHomePage(userId: userId)),
        );
      } else if (role == "care_seeker") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CareSeekerHome(userId: userId)),
        );
      } else if (role == "care_taker") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      } else {
        showToast("Unknown user role", type: ToastType.error);
      }
    } catch (e) {
      setState(() => loading = false);
      showToast("Server error. Please try again.", type: ToastType.error);
    }
  }

  // ── INPUT DECORATION ─────────────────────────────────────────────────────
  InputDecoration _field(String label, IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary),
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F4),
      body: Column(
        children: [

          // ── HEADER ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 32,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(children: [
              Image.asset("assets/logo.png", height: 90),
              const SizedBox(height: 10),
              const _ShimmerMedicoText(),
              const SizedBox(height: 4),
              const Text(
                "Healthcare Services at Home",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ]),
          ),

          // ── FORM ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome Back 👋",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E2B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Sign in to continue your care journey",
                    style: TextStyle(fontSize: 13.5, color: Colors.black45),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _field("Email Address", Icons.email_outlined),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: _field("Password", Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.primary,
                        ),
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ForgotPasswordPage()),
                      ),
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(children: [
                    Checkbox(
                      value: acceptTerms,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) => setState(() => acceptTerms = v!),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 13.5, color: Colors.black87),
                          children: [
                            const TextSpan(text: "I agree to the "),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TermsConditions()),
                                ),
                                child: const Text(
                                  "Terms & Conditions",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── LOGIN BUTTON ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: loading ? null : loginUser,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "LOGIN",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: Colors.black54)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterPage()),
                      ),
                      child: const Text(
                        "Create Account",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ANIMATED SHIMMER MEDICO TEXT
// ══════════════════════════════════════════════════════════════════════════════

class _ShimmerMedicoText extends StatefulWidget {
  const _ShimmerMedicoText();
  @override
  State<_ShimmerMedicoText> createState() => _ShimmerMedicoTextState();
}

class _ShimmerMedicoTextState extends State<_ShimmerMedicoText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _anim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Colors.white,
              Colors.white,
              Color(0xFFB2FFEE),
              Colors.white,
              Colors.white,
            ],
            stops: [
              0.0,
              (_anim.value - 0.25).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.25).clamp(0.0, 1.0),
              1.0,
            ],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            "MEDICO",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TOAST SYSTEM
// ══════════════════════════════════════════════════════════════════════════════

enum ToastType { success, error, warning, info }

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  _ToastStyle get _style {
    switch (widget.type) {
      case ToastType.success:
        return _ToastStyle(const Color(0xFF1B7A4A), const Color(0xFF34C97B),
            Icons.check_circle_rounded, "Success");
      case ToastType.error:
        return _ToastStyle(const Color(0xFFC0392B), const Color(0xFFFF6B6B),
            Icons.cancel_rounded, "Error");
      case ToastType.warning:
        return _ToastStyle(const Color(0xFFB7600A), const Color(0xFFFFB347),
            Icons.warning_amber_rounded, "Warning");
      case ToastType.info:
        return _ToastStyle(const Color(0xFF1A6FA8), const Color(0xFF4FC3F7),
            Icons.info_rounded, "Info");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: s.bg.withOpacity(0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.icon, color: s.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.6),
                      size: 18,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStyle {
  final Color bg, accent;
  final IconData icon;
  final String label;
  const _ToastStyle(this.bg, this.accent, this.icon, this.label);
}