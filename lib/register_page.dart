import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import 'config/api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final otp = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  String? role;
  bool otpSent = false, otpVerified = false, loading = false;
  int secondsRemaining = 0;
  Timer? timer;

  // ── Toast ─────────────────────────────────────────────
  void showToast(String msg, {ToastType type = ToastType.error}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(message: msg, type: type, onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  void showMsg(String msg) => showToast(msg, type: ToastType.error);

  bool isValidGmail(String v) => RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(v);
  bool isValidMobile(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);

  void startTimer() {
    secondsRemaining = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  Future sendOTP() async {
    if (!isValidGmail(email.text.trim())) return showToast("Enter valid Gmail (example@gmail.com)", type: ToastType.warning);
    if (!isValidMobile(mobile.text.trim())) return showToast("Enter valid 10-digit mobile number", type: ToastType.warning);
    setState(() => loading = true);
    var res = await http.post(Uri.parse("${Api.baseUrl}/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.text.trim()}));
    setState(() => loading = false);
    var data = jsonDecode(res.body);
    if (data["message"] == "OTP sent") { setState(() => otpSent = true); startTimer(); showToast(data["message"], type: ToastType.success); }
    else {
      showToast(data["message"], type: ToastType.error);
    }
  }

  Future verifyOTP() async {
    if (otp.text.length < 4) return showToast("Enter valid OTP", type: ToastType.warning);
    setState(() => loading = true);
    var res = await http.post(Uri.parse("${Api.baseUrl}/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.text.trim(), "otp": otp.text.trim()}));
    setState(() => loading = false);
    var data = jsonDecode(res.body);
    if (data["message"] == "OTP verified") { setState(() => otpVerified = true); showToast(data["message"], type: ToastType.success); }
    else {
      showToast(data["message"], type: ToastType.error);
    }
  }

  Future register() async {
    if (role == null) return showToast("Select role", type: ToastType.warning);
    if (!isValidMobile(mobile.text.trim())) return showToast("Enter valid 10-digit mobile number", type: ToastType.warning);
    if (!isValidGmail(email.text.trim())) return showToast("Enter valid Gmail", type: ToastType.warning);
    if (password.text.length < 6) return showToast("Password must be at least 6 characters", type: ToastType.warning);
    if (password.text != confirmPassword.text) return showToast("Passwords mismatch", type: ToastType.warning);
    setState(() => loading = true);
    var res = await http.post(Uri.parse("${Api.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "first_name": firstName.text.trim(), "last_name": lastName.text.trim(),
          "mobile": mobile.text.trim(), "email": email.text.trim(),
          "password": password.text, "role": role,
        }));
    setState(() => loading = false);
    var data = jsonDecode(res.body);
    if (data["message"] == "Account created") { showToast(data["message"], type: ToastType.success); Navigator.pop(context); }
    else {
      showToast(data["message"], type: ToastType.error);
    }
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primary),
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      );

  Widget _input(TextEditingController c, String label, IconData icon,
          {bool pass = false, bool enabled = true, TextInputType type = TextInputType.text, List<TextInputFormatter>? formatters}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(controller: c, obscureText: pass, enabled: enabled, keyboardType: type, inputFormatters: formatters, decoration: _field(label, icon)),
      );

  Widget _button(String text, VoidCallback? onTap) => Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: onTap != null ? AppColors.gradient : null,
          color: onTap == null ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap != null ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

          // ── HEADER — touches top of screen ────────────
          Container(
            width: double.infinity,
            // top padding = status bar height so content clears it
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 32,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(children: [
              Image.asset("assets/logo.png", height: 80),
              const SizedBox(height: 10),
              const Text("MEDICO",
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text("Create your healthcare account",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),

          // ── FORM ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Get Started",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A2E2B))),
                  const SizedBox(height: 4),
                  const Text("Fill in the details to create your account",
                      style: TextStyle(fontSize: 13.5, color: Colors.black45)),
                  const SizedBox(height: 22),

                  DropdownButtonFormField<String>(
                    initialValue: role,
                    hint: const Text("Select Role"),
                    decoration: _field("Role", Icons.person),
                    items: const [
                      DropdownMenuItem(value: "care_seeker", child: Text("Care Seeker")),
                      DropdownMenuItem(value: "care_taker", child: Text("Care Taker")),
                    ],
                    onChanged: (v) => setState(() => role = v),
                  ),
                  const SizedBox(height: 14),

                  _input(firstName, "First Name", Icons.person),
                  _input(lastName, "Last Name", Icons.person_outline),
                  _input(mobile, "Mobile Number", Icons.phone,
                      type: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                  _input(email, "Email (Gmail only)", Icons.email, type: TextInputType.emailAddress),

                  const SizedBox(height: 4),
                  if (!otpSent) _button("SEND OTP", sendOTP),

                  if (otpSent) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: otp,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          decoration: _field("Enter OTP", Icons.lock),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: verifyOTP,
                          child: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (secondsRemaining > 0)
                      Text("Resend OTP in $secondsRemaining sec", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    if (secondsRemaining == 0)
                      TextButton(
                        onPressed: sendOTP,
                        child: const Text("Resend OTP", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    if (otpVerified)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text("Email verified", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ],

                  const SizedBox(height: 14),
                  _input(password, "Password", Icons.lock, pass: true, enabled: otpVerified),
                  _input(confirmPassword, "Confirm Password", Icons.lock_outline, pass: true, enabled: otpVerified),
                  const SizedBox(height: 6),

                  _button("CREATE ACCOUNT", otpVerified ? register : null),

                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Already have an account? ", style: TextStyle(color: Colors.black54)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text("Login", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 10),
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      case ToastType.success: return _ToastStyle(const Color(0xFF1B7A4A), const Color(0xFF34C97B), Icons.check_circle_rounded, "Success");
      case ToastType.error:   return _ToastStyle(const Color(0xFFC0392B), const Color(0xFFFF6B6B), Icons.cancel_rounded,        "Error");
      case ToastType.warning: return _ToastStyle(const Color(0xFFB7600A), const Color(0xFFFFB347), Icons.warning_amber_rounded,  "Warning");
      case ToastType.info:    return _ToastStyle(const Color(0xFF1A6FA8), const Color(0xFF4FC3F7), Icons.info_rounded,           "Info");
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
                  color: s.bg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: s.bg.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(s.icon, color: s.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(s.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(widget.message, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13, height: 1.3)),
                    ]),
                  ),
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