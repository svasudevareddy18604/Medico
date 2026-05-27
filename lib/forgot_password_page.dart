import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import 'package:medico/utils/app_colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController       = TextEditingController();
  final otpController         = TextEditingController();
  final newPasswordController = TextEditingController();

  bool otpSent = false, loading = false, hidePassword = true;

  // ── Toast ─────────────────────────────────────────────
  void showToast(String msg, {ToastType type = ToastType.error}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ToastWidget(message: msg, type: type, onDismiss: () => entry.remove()));
    overlay.insert(entry);
  }

  Future<void> sendOtp() async {
    if (emailController.text.trim().isEmpty) return showToast("Email required", type: ToastType.warning);
    setState(() => loading = true);
    try {
      final res = await http.post(Uri.parse("${Api.baseUrl}/auth/send-otp"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": emailController.text.trim()}));
      if (res.statusCode == 200) { setState(() => otpSent = true); showToast("OTP sent to your email", type: ToastType.success); }
      else {
        showToast("Failed to send OTP", type: ToastType.error);
      }
    } catch (e) { showToast("Server error", type: ToastType.error); }
    setState(() => loading = false);
  }

  Future<void> resetPassword() async {
    if (otpController.text.trim().isEmpty)         return showToast("Enter OTP", type: ToastType.warning);
    if (newPasswordController.text.trim().isEmpty) return showToast("Enter new password", type: ToastType.warning);
    setState(() => loading = true);
    try {
      final res = await http.post(Uri.parse("${Api.baseUrl}/auth/reset-password"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": emailController.text.trim(), "otp": otpController.text.trim(), "newPassword": newPasswordController.text.trim()}));
      if (res.statusCode == 200) { showToast("Password updated successfully", type: ToastType.success); Navigator.pop(context); }
      else {
        showToast("Invalid OTP or failed", type: ToastType.error);
      }
    } catch (e) { showToast("Server error", type: ToastType.error); }
    setState(() => loading = false);
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary),
        
        labelText: label, filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      );

  Widget _button(String text, VoidCallback? onTap) => Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: loading ? null : onTap,
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F4),
      body: Column(
        children: [

          // ── HEADER — full bleed to status bar ─────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24, bottom: 32),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(children: [
              Image.asset("assets/logo.png", height: 80),
              const SizedBox(height: 10),
              const Text("MEDICO", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text("Healthcare Services at Home", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),

          // ── FORM ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Forgot Password? 🔐",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A2E2B))),
                  const SizedBox(height: 4),
                  Text(
                    otpSent ? "Enter the OTP sent to your email and set a new password."
                            : "Enter your registered email to receive an OTP.",
                    style: const TextStyle(fontSize: 13.5, color: Colors.black45),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !otpSent,
                    decoration: _field("Email Address", Icons.email_outlined),
                  ),
                  const SizedBox(height: 20),

                  if (!otpSent) _button("SEND OTP", sendOtp),

                  if (otpSent) ...[
                    TextField(controller: otpController, keyboardType: TextInputType.number, decoration: _field("Enter OTP", Icons.verified_outlined)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: hidePassword,
                      decoration: _field("New Password", Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primary),
                          onPressed: () => setState(() => hidePassword = !hidePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _button("RESET PASSWORD", resetPassword),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: loading ? null : () => setState(() => otpSent = false),
                        child: const Text("Didn't receive OTP? Try again",
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Remember your password? ", style: TextStyle(color: Colors.black54)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text("Login", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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


// ══════════════════════════════════════════════════════════════
//  SHARED TOAST SYSTEM
// ══════════════════════════════════════════════════════════════

enum ToastType { success, error, warning, info }

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  const _ToastWidget({required this.message, required this.type, required this.onDismiss});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  _ToastStyle get _style {
    switch (widget.type) {
      case ToastType.success: return _ToastStyle(const Color(0xFF1B7A4A), const Color(0xFF34C97B), Icons.check_circle_rounded,  "Success");
      case ToastType.error:   return _ToastStyle(const Color(0xFFC0392B), const Color(0xFFFF6B6B), Icons.cancel_rounded,         "Error");
      case ToastType.warning: return _ToastStyle(const Color(0xFFB7600A), const Color(0xFFFFB347), Icons.warning_amber_rounded,  "Warning");
      case ToastType.info:    return _ToastStyle(const Color(0xFF1A6FA8), const Color(0xFF4FC3F7), Icons.info_rounded,            "Info");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16, right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: s.bg, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: s.bg.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(s.icon, color: s.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text(widget.message, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13, height: 1.3)),
                  ])),
                  GestureDetector(onTap: _dismiss, child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.6), size: 18)),
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