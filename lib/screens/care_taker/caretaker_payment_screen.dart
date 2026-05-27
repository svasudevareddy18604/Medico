import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';

class CaretakerPaymentScreen extends StatefulWidget {
  final dynamic orderId;      // int or String — handled safely
  final int caretakerId;
  const CaretakerPaymentScreen(
      {super.key, required this.orderId, required this.caretakerId});
  @override
  State<CaretakerPaymentScreen> createState() =>
      _CaretakerPaymentScreenState();
}

class _CaretakerPaymentScreenState extends State<CaretakerPaymentScreen> {
  static const _primary = Color(0xFF1B7F6E);
  static const _amber   = Color(0xFFF59E0B);
  static const _blue    = Color(0xFF1565C0);
  static const _red     = Color(0xFFEF4444);

  Map<String, dynamic> _order = {};
  bool _loading = true;
  bool _busy    = false;
  Timer? _pollTimer;

  // ── Safe id ────────────────────────────────────────────────
  int get _orderIdInt =>
      widget.orderId is int
          ? widget.orderId as int
          : int.tryParse(widget.orderId.toString()) ?? 0;

  // ── Getters ────────────────────────────────────────────────
  bool get _isCOD =>
      (_order["payment_method"] ?? "COD").toString().toUpperCase() == "COD";
  bool get _isPaid =>
      (_order["payment_status"] ?? "").toString().toUpperCase() == "PAID";
  bool get _isCompleted =>
      (_order["status"] ?? "").toString().toUpperCase() == "COMPLETED";

  String get _bookingCode =>
      (_order["order_code"] ?? "#$_orderIdInt").toString();
  String get _category =>
      (_order["category"] ?? "Service").toString();

  /// Show a clean number — 1.00 → "1", 350.00 → "350", 350.50 → "350.5"
  String get _total {
    final raw = _order["total"];
    if (raw == null) return "0";
    final n = double.tryParse(raw.toString());
    if (n == null || n == 0) return "0";
    return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
  }

  String get _upiLink =>
      "upi://pay?pa=9652296548@axl&pn=Medico&am=$_total&cu=INR&tn=$_bookingCode";

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Network ────────────────────────────────────────────────
  Future<void> _fetch() async {
    try {
      // ✅ CORRECT endpoint — /caretaker/order-detail/:id
      //    This is the working route that returns total, payment_status, etc.
      //    Do NOT use /api/orders/detail/:id — it had the u.phone crash.
      final url = "${Api.baseUrl}/caretaker/order-detail/$_orderIdInt";
      debugPrint("💳 Fetching: $url");

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      debugPrint("💳 total=${data["data"]?["total"]}  status=${data["data"]?["payment_status"]}");

      if (data["success"] == true && data["data"] != null && mounted) {
        setState(() {
          _order   = Map<String, dynamic>.from(data["data"]);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("💳 FETCH ERROR: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _red : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  /// COD — caretaker taps "I Received Payment"
  Future<void> _confirmPaymentReceived() async {
    setState(() => _busy = true);
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/caretaker/mark-payment-received"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id":     _orderIdInt,
          "caretaker_id": widget.caretakerId,
        }),
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        _snack("Payment confirmed ✓");
        await _fetch();
      } else {
        _snack(data["message"] ?? "Failed to confirm payment", error: true);
      }
    } catch (_) {
      _snack("Server error", error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Mark service as completed (only after payment is confirmed)
  Future<void> _completeService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Complete Service?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "Mark this service as completed? The careseeker will be notified."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text("Yes, Complete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/caretaker/complete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id":     _orderIdInt,
          "caretaker_id": widget.caretakerId,
        }),
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        _snack("Service marked as completed! 🎉");
        await _fetch();
        if (mounted) Navigator.pop(context, true);
      } else {
        _snack(data["message"] ?? "Failed to complete service", error: true);
      }
    } catch (_) {
      _snack("Server error", error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _primary)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(children: [

        // ── Header ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text("Payment & Completion",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(_bookingCode,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                _isCompleted ? "Completed" : _isPaid ? "Paid" : "Pending",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [

              // Amount hero card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Column(children: [
                  Text(_category.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(_bookingCode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Divider(
                        color: Colors.white.withOpacity(0.3), height: 1),
                  ),
                  const Text("TOTAL AMOUNT",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: .5)),
                  const SizedBox(height: 6),
                  Text(
                    "₹$_total",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      _isCOD ? "Cash / QR Payment" : "Online Payment",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // Status card
              _statusCard(),

              const SizedBox(height: 16),

              // COD — QR + confirm
              if (_isCOD && !_isPaid && !_isCompleted) _codSection(),

              // Online — waiting spinner
              if (!_isCOD && !_isPaid && !_isCompleted) _onlineSection(),

              const SizedBox(height: 16),

              // Complete button
              _completeButton(),

              const SizedBox(height: 8),
              if (!_isPaid && !_isCompleted)
                Text(
                  _isCOD
                      ? "Confirm payment first to enable completion."
                      : "Waiting for client to complete online payment.",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────

  Widget _statusCard() {
    IconData icon;
    Color iconColor;
    String title, subtitle;

    if (_isCompleted) {
      icon = Icons.task_alt_rounded; iconColor = _blue;
      title    = "Service Completed";
      subtitle = "Thank you! The careseeker has been notified.";
    } else if (_isPaid) {
      icon = Icons.verified_rounded; iconColor = _primary;
      title    = "Payment Received";
      subtitle = "Payment confirmed. Tap below to complete the service.";
    } else {
      icon = Icons.pending_actions_rounded; iconColor = _amber;
      title    = _isCOD ? "Awaiting Payment" : "Waiting for Online Payment";
      subtitle = _isCOD
          ? "Show the QR code below to collect payment from the careseeker."
          : "Waiting for the client to complete online payment.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(children: [
        Icon(icon, size: 60, color: iconColor),
        const SizedBox(height: 10),
        Text(title,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        if (!_isCOD &&
            (_order["payment_id"] ?? "").toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Text("Payment ID: ${_order["payment_id"]}",
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _codSection() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.3))),
            child: const Row(children: [
              Icon(Icons.qr_code_2_rounded, color: _amber, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Show this QR to the careseeker. They can scan it to pay via any UPI app.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A5C00)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: QrImageView(data: _upiLink, size: 200),
          ),
          const SizedBox(height: 8),
          Text("Scan to pay ₹$_total",
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
          _busy
              ? const CircularProgressIndicator(color: _primary)
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _confirmPaymentReceived,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text("I Received Payment",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                ),
        ]),
      );

  Widget _onlineSection() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(
                  color: _primary, strokeWidth: 3)),
          const SizedBox(height: 14),
          const Text("Waiting for payment...",
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          Text("This screen auto-refreshes every 6 seconds.",
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ]),
      );

  Widget _completeButton() {
    final canComplete = _isPaid && !_isCompleted;
    return _busy
        ? const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(color: _primary))
        : SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: canComplete ? _completeService : null,
              icon: Icon(_isCompleted
                  ? Icons.task_alt_rounded
                  : Icons.done_all_rounded),
              label: Text(
                _isCompleted
                    ? "✓  Service Completed"
                    : "Mark Service as Completed",
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCompleted
                    ? _blue
                    : canComplete
                        ? _primary
                        : Colors.grey.shade300,
                foregroundColor:
                    canComplete || _isCompleted ? Colors.white : Colors.grey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: canComplete ? 4 : 0,
              ),
            ),
          );
  }
}