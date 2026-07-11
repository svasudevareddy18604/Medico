import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';

/// Caretaker-side arrival OTP screen.
///
/// Flow: caretaker taps "Start Journey" → this screen opens → caretaker
/// asks the careseeker for the 4-digit OTP shown on their order details
/// screen → enters it here → on success the order's otp_verified flag
/// flips to 1 on the backend, which is what unlocks "Complete Service"
/// back on the order details screen.
class CaretakerOtpScreen extends StatefulWidget {
  final int orderId;
  final int caretakerId;
  final String orderCode;

  const CaretakerOtpScreen({
    super.key,
    required this.orderId,
    required this.caretakerId,
    required this.orderCode,
  });

  @override
  State<CaretakerOtpScreen> createState() => _CaretakerOtpScreenState();
}

class _CaretakerOtpScreenState extends State<CaretakerOtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 4;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  bool _verifying = false;
  bool _verified = false;
  String? _errorText;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeCtrl);
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (_errorText != null) setState(() => _errorText = null);

    if (value.length > 1) {
      // Handles paste of the full code into one box.
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < _otpLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      if (digits.length >= _otpLength) {
        _focusNodes[_otpLength - 1].unfocus();
        _verify();
      } else if (digits.isNotEmpty) {
        _focusNodes[digits.length.clamp(0, _otpLength - 1)].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == _otpLength) {
      FocusScope.of(context).unfocus();
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_verifying || _verified) return;
    if (_otp.length != _otpLength) {
      setState(() => _errorText = "Enter all $_otpLength digits");
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      final res = await http
          .post(
            Uri.parse("${Api.baseUrl}/caretaker/verify-otp"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "order_id": widget.orderId,
              "caretaker_id": widget.caretakerId,
              "otp": _otp,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final d = jsonDecode(res.body);

      if (d["success"] == true) {
        setState(() => _verified = true);
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context, true);
      } else {
        _fail(d["message"]?.toString() ?? "Invalid OTP");
      }
    } catch (e) {
      _fail("Network error. Please try again.");
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _fail(String message) {
    setState(() => _errorText = message);
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0);
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Column(
        children: [

          // ── Header ────────────────────────────────────────────
          // Same structural language as the order-details header:
          // back chip top-left, bold white title beside it, then a
          // centered icon badge + booking code + helper line below.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 26),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Verify Arrival",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (widget.orderCode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        widget.orderCode,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                ]),
                const SizedBox(height: 22),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.shield_moon_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Confirm Your Arrival",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Ask the careseeker for the OTP shown on their order details screen.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // "Enter 4-Digit OTP" label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pin_rounded,
                          color: AppColors.primary.withOpacity(0.85), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Enter 4-Digit OTP",
                        style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── OTP boxes ───────────────────────────────────
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) {
                      final t = _shakeAnim.value;
                      final dx = (t == 0)
                          ? 0.0
                          : (8 * (1 - t)) *
                              (((t * 10).floor() % 2 == 0) ? 1 : -1);
                      return Transform.translate(
                          offset: Offset(dx, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          List.generate(_otpLength, (i) => _otpBox(i)),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(_errorText!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    )
                  else if (_verified)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text("OTP Verified · Service Started",
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),

                  const Spacer(),

                  // ── Verify button ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  const Color(0xFFF59E0B).withOpacity(0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFFF59E0B), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Only enter this OTP once you have physically reached the customer's location.",
                              style: TextStyle(
                                  color: Color(0xFF7B5800),
                                  fontSize: 12,
                                  height: 1.3),
                            ),
                          ),
                        ]),
                      ),
                      GestureDetector(
                        onTap: (_verifying || _verified) ? null : _verify,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _verified
                                ? AppColors.primary
                                : (_otp.length == _otpLength
                                    ? AppColors.primary
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow:
                                (_otp.length == _otpLength && !_verifying)
                                    ? [
                                        BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.35),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6))
                                      ]
                                    : [],
                          ),
                          child: Center(
                            child: _verifying
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          _verified
                                              ? Icons.check_rounded
                                              : Icons
                                                  .verified_user_rounded,
                                          color: _otp.length == _otpLength ||
                                                  _verified
                                              ? Colors.white
                                              : Colors.grey,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _verified
                                            ? "Verified"
                                            : "Verify OTP",
                                        style: TextStyle(
                                            color: _otp.length ==
                                                        _otpLength ||
                                                    _verified
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index) {
    final filled = _controllers[index].text.isNotEmpty;
    final borderColor = _errorText != null
        ? const Color(0xFFEF4444)
        : (filled ? AppColors.primary : Colors.grey.shade300);

    return Container(
      width: 58,
      height: 66,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: filled ? 2 : 1.4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !_verified,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _otpLength, // allows paste-into-one-box handling
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _onChanged(index, v),
        ),
      ),
    );
  }
}