import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import 'orders_screen.dart';
import '../../models/invoice_data.dart';
import '../../services/invoice_pdf_service.dart';
import 'invoice_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OrderSuccessScreen
// ─────────────────────────────────────────────────────────────────────────────
class OrderSuccessScreen extends StatefulWidget {
  final int    userId;
  final int    orderId;
  final String orderCode;
  final List<dynamic> orders;
  final double subtotal, serviceCharge, discount, total;

  const OrderSuccessScreen({
    super.key,
    required this.userId,
    required this.orderId,
    this.orderCode     = "",
    this.orders        = const [],
    this.subtotal      = 0.0,
    this.serviceCharge = 0.0,
    this.discount      = 0.0,
    this.total         = 0.0,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _mainCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  late final AnimationController _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  // Confetti: phase-1 burst (1.5 s), phase-2 drift (2.5 s)
  late final AnimationController _burstCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();

  late final AnimationController _driftCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
    ..forward();

  late final Animation<double> _scale =
      CurvedAnimation(parent: _mainCtrl, curve: Curves.elasticOut);

  late final Animation<double> _fade =
      CurvedAnimation(parent: _mainCtrl, curve: Curves.easeIn);

  late final Animation<double> _slideY =
      Tween<double>(begin: 40, end: 0).animate(
          CurvedAnimation(parent: _mainCtrl, curve: Curves.easeOut));

  bool get _dark => themeNotifier.value == ThemeMode.dark;

  // ── Data helpers ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _orders =>
      widget.orders.map((o) => Map<String, dynamic>.from(o as Map)).toList();

  String get _displayCode {
    if (_orders.isNotEmpty) {
      final codes = _orders
          .map((o) => (o["order_code"] ?? "").toString())
          .where((s) => s.isNotEmpty)
          .join(", ");
      return codes.isNotEmpty ? codes : "#${widget.orderId}";
    }
    return widget.orderCode.isNotEmpty ? widget.orderCode : "#${widget.orderId}";
  }

  String get _bookingDate {
    if (_orders.isNotEmpty) {
      final raw = (_orders.first["date"] ?? "").toString();
      if (raw.isNotEmpty) return _fmtDate(raw);
    }
    return _fmtDate(DateTime.now().toIso8601String());
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day.toString().padLeft(2,'0')} ${mo[dt.month-1]} ${dt.year}";
    } catch (_) { return raw; }
  }

  String _fmtSlot(String raw) {
    try {
      final parts = raw.split(":");
      int h = int.parse(parts[0]);
      final m = parts.length > 1 ? parts[1] : "00";
      final suffix = h >= 12 ? "PM" : "AM";
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      return "$h:$m $suffix";
    } catch (_) { return raw; }
  }

  // ── Invoice ──────────────────────────────────────────────────────────────
  InvoiceData get _invoiceData => InvoiceData.fromOrders(
        orderId: widget.orderId,
        orderCode: widget.orderCode,
        orders: widget.orders,
        subtotal: widget.subtotal,
        serviceCharge: widget.serviceCharge,
        discount: widget.discount,
        total: widget.total,
      );

  void _openInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceScreen(invoice: _invoiceData)),
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_rebuild);
    _mainCtrl.dispose();
    _pulseCtrl.dispose();
    _burstCtrl.dispose();
    _driftCtrl.dispose();
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _displayCode));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Order ID copied!"),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg     = _dark ? const Color(0xFF0A1628) : AppColors.lightBg;
    final cardBg = _dark ? const Color(0xFF1A2744) : AppColors.cardBg;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          _header(),
          Expanded(child: Stack(children: [
            // ── Celebration layer ──────────────────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_burstCtrl, _driftCtrl]),
              builder: (_, __) => IgnorePointer(
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width,
                             MediaQuery.of(context).size.height * 0.72),
                  painter: _CelebrationPainter(
                      burst: _burstCtrl.value, drift: _driftCtrl.value),
                ),
              ),
            ),
            // ── Scrollable content ─────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
              child: Column(children: [
                _checkIcon(),
                const SizedBox(height: 22),
                _titleBlock(),
                const SizedBox(height: 26),
                _ordersCard(cardBg),
                const SizedBox(height: 12),
                _billingCard(cardBg),
                const SizedBox(height: 12),
                _infoTile(cardBg, Icons.calendar_today_rounded,
                    "Booking Date", _bookingDate, false),
                const SizedBox(height: 10),
                _infoTile(cardBg, Icons.confirmation_number_rounded,
                    "Booking ID", _displayCode, true),
                const SizedBox(height: 30),
                _invoiceButtons(),
                const SizedBox(height: 12),
                _ctaTrack(),
                const SizedBox(height: 12),
                _ctaHome(),
              ]),
            ),
          ])),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(16, 54, 16, 22),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: const Center(
      child: Text("Booking Confirmed",
          style: TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.w800)),
    ),
  );

  // ── Animated check icon ───────────────────────────────────────────────────
  Widget _checkIcon() => AnimatedBuilder(
    animation: Listenable.merge([_pulseCtrl, _mainCtrl]),
    builder: (_, __) => Stack(alignment: Alignment.center, children: [
      // Pulse ring
      Container(
        width:  148 + _pulseCtrl.value * 28,
        height: 148 + _pulseCtrl.value * 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary
              .withOpacity(0.045 * (1 - _pulseCtrl.value)),
        ),
      ),
      Container(width: 122, height: 122,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.09))),
      // Check badge
      ScaleTransition(
        scale: _scale,
        child: Container(
          width: 94, height: 94,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradient,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.45),
                  blurRadius: 28, spreadRadius: 4,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 50),
        ),
      ),
    ]),
  );

  // ── Title block ───────────────────────────────────────────────────────────
  Widget _titleBlock() => AnimatedBuilder(
    animation: _mainCtrl,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, _slideY.value),
      child: Opacity(
          opacity: _mainCtrl.value.clamp(0.0, 1.0), child: child)),
    child: Column(children: [
      Text("Booking Successful!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
              color: _dark ? Colors.white : const Color(0xFF0F172A))),
      const SizedBox(height: 8),
      Text(
        _orders.isNotEmpty
            ? "${_orders.length} Booking ${_orders.length > 1 ? 's' : ''} placed successfully."
            : "Your service has been booked successfully.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, height: 1.55,
            color: _dark ? Colors.white54 : AppColors.muted),
      ),
    ]),
  );

  // ── Billing card ──────────────────────────────────────────────────────────
  Widget _billingCard(Color cardBg) {
    final hasSC   = widget.serviceCharge > 0;
    final hasDisc = widget.discount > 0;
    if (!hasSC && !hasDisc) return const SizedBox.shrink();

    final sub = _dark ? Colors.white54 : AppColors.muted;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          boxShadow: _dark ? [] : AppColors.cardShadow,
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.receipt_long_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text("Bill Summary",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: _dark ? Colors.white : const Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 12),
          Divider(thickness: 0.6,
              color: _dark ? Colors.white12 : AppColors.border),
          const SizedBox(height: 10),
          _billRow("Subtotal",
              "₹${widget.subtotal.toStringAsFixed(2)}", sub),
          if (hasSC) ...[
            const SizedBox(height: 8),
            _billRow("Service Charge",
                "+₹${widget.serviceCharge.toStringAsFixed(2)}", sub,
                valueColor: _dark
                    ? Colors.orange.shade300
                    : Colors.orange.shade700),
          ],
          if (hasDisc) ...[
            const SizedBox(height: 8),
            _billRow("Discount",
                "−₹${widget.discount.toStringAsFixed(2)}", sub,
                valueColor: AppColors.success),
          ],
          const SizedBox(height: 10),
          Divider(thickness: 0.6,
              color: _dark ? Colors.white12 : AppColors.border),
          const SizedBox(height: 8),
          Row(children: [
            Text("Total Paid",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: _dark ? Colors.white : const Color(0xFF0F172A))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("₹${widget.total.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _billRow(String label, String value, Color subColor,
      {Color? valueColor}) =>
      Row(children: [
        Text(label, style: TextStyle(fontSize: 13, color: subColor)),
        const Spacer(),
        Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: valueColor ??
                    (_dark ? Colors.white : const Color(0xFF0F172A)))),
      ]);

  // ── Orders card ───────────────────────────────────────────────────────────
  Widget _ordersCard(Color cardBg) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: _dark ? [] : AppColors.cardShadow,
      ),
      child: Column(children: [
        // Header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 17),
            const SizedBox(width: 10),
            Text(
              _orders.length > 1
                  ? "${_orders.length} Services Booked"
                  : "Service Booked",
              style: const TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("CONFIRMED",
                  style: TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ]),
        ),
        // Rows
        if (_orders.isNotEmpty)
          ...List.generate(_orders.length, (i) {
            final o = _orders[i];
            return _orderRow(
              code: (o["order_code"] ?? "").toString().isNotEmpty
                  ? o["order_code"].toString()
                  : "#${o["order_id"] ?? widget.orderId}",
              slot: (o["slot"] ?? "").toString().isNotEmpty
                  ? _fmtSlot(o["slot"].toString()) : "-",
              category:    (o["category"]   ?? "Service").toString(),
              serviceName: (o["service_name"] ?? o["service_names"] ?? "").toString(),
              total:       (o["total"] ?? o["totalPrice"] ?? "0").toString(),
              isLast:      i == _orders.length - 1,
            );
          })
        else
          _orderRow(
            code: widget.orderCode.isNotEmpty
                ? widget.orderCode : "#${widget.orderId}",
            slot: "-", category: "Service",
            serviceName: "", total: "0", isLast: true,
          ),
      ]),
    ),
  );

  Widget _orderRow({
    required String code, required String slot,
    required String category, required String serviceName,
    required String total, required bool isLast,
  }) {
    final sub = _dark ? Colors.white54 : AppColors.muted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(
            color: _dark ? Colors.white10 : AppColors.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: const Icon(Icons.local_hospital_rounded,
              color: AppColors.primary, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            const Icon(Icons.tag_rounded, size: 12,
                color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(child: Text(code,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary, letterSpacing: 0.4))),
          ]),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(category,
                style: const TextStyle(fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700)),
          ),
          if (serviceName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(serviceName,
                style: TextStyle(fontSize: 12, color: sub,
                    fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.access_time_rounded, size: 13, color: sub),
            const SizedBox(width: 5),
            Text(slot, style: TextStyle(fontSize: 12.5,
                fontWeight: FontWeight.w600, color: sub)),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text("₹$total",
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── Info tile ─────────────────────────────────────────────────────────────
  Widget _infoTile(Color cardBg, IconData icon, String label,
      String value, bool copyable) =>
      FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: copyable ? _copy : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: copyable
                  ? Border.all(color: AppColors.primary.withOpacity(0.22))
                  : null,
              boxShadow: _dark ? [] : AppColors.cardShadow,
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(fontSize: 13,
                      color: _dark ? Colors.white54 : AppColors.muted)),
              const Spacer(),
              Flexible(child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: copyable
                          ? AppColors.primary
                          : (_dark ? Colors.white : const Color(0xFF0F172A))))),
              if (copyable) ...[
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded,
                    size: 14, color: AppColors.primary),
              ],
            ]),
          ),
        ),
      );

  // ── Invoice buttons ──────────────────────────────────────────────────────
  Widget _invoiceButtons() => FadeTransition(
    opacity: _fade,
    child: Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _openInvoice,
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text("View Invoice",
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 205, 205, 124),
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: const Color.fromARGB(255, 229, 15, 51).withOpacity(0.35)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            try {
              await InvoicePdfService.shareInvoice(_invoiceData);
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Couldn't generate the invoice.")),
                );
              }
            }
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text("Download PDF",
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 105, 127, 66),
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: const Color.fromARGB(255, 215, 15, 15).withOpacity(0.35)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]),
  );

  // ── CTAs ──────────────────────────────────────────────────────────────────
  Widget _ctaTrack() => FadeTransition(
    opacity: _fade,
    child: GestureDetector(
      onTap: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => OrdersScreen(userId: widget.userId)),
        (r) => r.isFirst),
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.glowShadow,
        ),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.track_changes_rounded,
              color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text("Track Service Status",
              style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );

  Widget _ctaHome() => FadeTransition(
    opacity: _fade,
    child: SizedBox(width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.home_rounded, size: 18),
        label: const Text("Go to Home",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () =>
            Navigator.popUntil(context, (r) => r.isFirst),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Celebration painter  —  burst rings + drifting confetti + sparkles
// ─────────────────────────────────────────────────────────────────────────────
class _CelebrationPainter extends CustomPainter {
  final double burst; // 0→1 over 1.5 s
  final double drift; // 0→1 over 2.5 s

  _CelebrationPainter({required this.burst, required this.drift});

  static final _rng = Random(77);

  // ── Confetti particles (shape, color, position seed)
  static final _pieces = List.generate(80, (i) => _ConfettiPiece(
    xSeed:  _rng.nextDouble(),
    ySeed:  _rng.nextDouble() * 0.3,
    size:   _rng.nextDouble() * 10 + 5,
    angle:  _rng.nextDouble() * 2 * pi,
    spin:   (_rng.nextBool() ? 1 : -1) * (_rng.nextDouble() * 6 + 2),
    colorI: _rng.nextInt(_palette.length),
    shape:  _rng.nextInt(3), // 0=rect, 1=circle, 2=star
    wave:   _rng.nextDouble() * 2 * pi,
    drift:  _rng.nextDouble() * 60 + 20,
  ));

  // ── Burst sparks
  static final _sparks = List.generate(24, (i) => _Spark(
    angle:  (i / 24) * 2 * pi,
    speed:  _rng.nextDouble() * 180 + 80,
    colorI: _rng.nextInt(_palette.length),
  ));

  static const _palette = [
    Color(0xFF0B8FAC), Color(0xFF14B8A6), Color(0xFF38BDF8),
    Color(0xFFFF6B6B), Color(0xFFFFD93D), Color(0xFF6BCB77),
    Color(0xFFFF9F1C), Color(0xFFC77DFF), Color(0xFFFF4D6D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.28; // centred around check icon area

    _drawBurstRings(canvas, cx, cy);
    _drawSparks(canvas, cx, cy, size);
    _drawConfetti(canvas, size);
  }

  void _drawBurstRings(Canvas canvas, double cx, double cy) {
    if (burst >= 1.0) return;
    final t = Curves.easeOut.transform(burst);
    for (int r = 0; r < 3; r++) {
      final delay = r * 0.18;
      final progress = ((burst - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final radius  = progress * (90 + r * 50.0);
      final opacity = (1 - progress).clamp(0.0, 0.35);
      canvas.drawCircle(Offset(cx, cy), radius,
          Paint()
            ..color = _palette[r * 2].withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * (1 - progress));
    }
  }

  void _drawSparks(Canvas canvas, double cx, double cy, Size size) {
    if (burst >= 1.0) return;
    final t = Curves.easeOutCubic.transform(burst);
    for (final s in _sparks) {
      final opacity = (1 - burst * 1.2).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final dx = cos(s.angle) * s.speed * t;
      final dy = sin(s.angle) * s.speed * t + 30 * t * t;
      final x = cx + dx;
      final y = cy + dy;
      final len = (1 - t) * 18 + 4;
      final paint = Paint()
        ..color = _palette[s.colorI].withOpacity(opacity)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x - cos(s.angle) * len, y - sin(s.angle) * len),
        Offset(x, y),
        paint,
      );
      // Star dot at tip
      canvas.drawCircle(Offset(x, y), 2.5,
          Paint()..color = _palette[s.colorI].withOpacity(opacity));
    }
  }

  void _drawConfetti(Canvas canvas, Size size) {
    final t = drift;
    if (t <= 0) return;
    final fadeEnd = (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);

    for (final p in _pieces) {
      final startDelay = p.xSeed * 0.3;
      final localT = ((t - startDelay) / (1 - startDelay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final x = p.xSeed * size.width +
          sin(localT * 2 * pi + p.wave) * p.drift * 0.4;
      final y = p.ySeed * size.height * 0.4 + localT * size.height * 0.85;

      if (y > size.height + 20) continue;

      final opacity = (localT < 0.1
          ? localT / 0.1
          : 1 - ((localT - 0.7) / 0.3).clamp(0.0, 1.0)) * 0.9;
      if (opacity <= 0) continue;

      final rot = p.angle + localT * p.spin;
      final color = _palette[p.colorI].withOpacity(opacity);
      final paint = Paint()..color = color;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      switch (p.shape) {
        case 0: // rounded rect
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: p.size, height: p.size * 0.42),
              const Radius.circular(2)),
            paint);
          break;
        case 1: // circle
          canvas.drawCircle(Offset.zero, p.size * 0.36, paint);
          break;
        case 2: // triangle
          final path = Path()
            ..moveTo(0, -p.size * 0.45)
            ..lineTo(p.size * 0.4, p.size * 0.3)
            ..lineTo(-p.size * 0.4, p.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter o) =>
      o.burst != burst || o.drift != drift;
}

class _ConfettiPiece {
  final double xSeed, ySeed, size, angle, spin, wave, drift;
  final int colorI, shape;
  const _ConfettiPiece({
    required this.xSeed, required this.ySeed, required this.size,
    required this.angle, required this.spin, required this.colorI,
    required this.shape, required this.wave, required this.drift,
  });
}

class _Spark {
  final double angle, speed;
  final int colorI;
  const _Spark({required this.angle, required this.speed, required this.colorI});
}