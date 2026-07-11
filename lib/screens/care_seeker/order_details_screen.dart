import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'careseekerfeedback_screen.dart';
import 'cancellationpolicy_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final List<dynamic> orders;
  const OrderDetailsScreen({super.key, required this.orders});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────────
  Map          _live       = {};
  bool         _loading    = true;
  bool         _cancelling = false;
  Timer?       _timer;
  final _mapCtrl = MapController();
  bool         _mapReady   = false;
  List<LatLng> _routePoints = [];

  // Tracks whether screenshot/screen-recording protection is currently ON,
  // so we only toggle the native flag when the state actually changes.
  // NOTE: protection still runs silently in the background — we simply no
  // longer surface any UI copy about it to the user.
  bool _screenshotBlocked = false;

  late AnimationController _anim;
  late Animation<double>   _fade;

  // ── Rich green for total amount (better contrast than a washed-out success) ──
  static const Color _totalGreen = Color(0xFF16A34A);

  // ── Instagram-style verified blue for professional caretakers ────────────────
  static const Color _verifiedBlue = Color(0xFF0095F6);

  // ── Dark mode ─────────────────────────────────────────────────────────────────
  bool get _dark => themeNotifier.value == ThemeMode.dark;

  Color get _surface => _dark ? const Color(0xFF1E293B) : AppColors.cardBg;
  Color get _bg      => _dark ? const Color(0xFF0F172A) : AppColors.lightBg;
  Color get _text    => _dark ? Colors.white : AppColors.dark;
  Color get _subText => _dark ? Colors.white60 : AppColors.muted;
  Color get _divider => _dark ? Colors.white.withOpacity(0.07) : AppColors.border;

  // ── Derived getters ───────────────────────────────────────────────────────────
  Map    get _order      => _live.isNotEmpty ? _live : Map.from(widget.orders.first);
  String get _status     => (_order["status"] ?? "").toString().toUpperCase();
  bool   get _cancelled  => _status == "CANCELLED";
  bool   get _completed  => _status == "COMPLETED";
  bool   get _cancellable => ["CONFIRMED", "ACCEPTED"].contains(_status);

  // Screenshots are allowed only while the booking is still pending
  // (CONFIRMED / awaiting a caretaker). The moment it's ACCEPTED — and for
  // every stage after that — screenshots & screen recording get blocked to
  // protect the caretaker's live location, phone number, etc. This runs
  // silently; no banner is shown to the user about it.
  bool get _shouldBlockScreenshot =>
      ["ACCEPTED", "ON_THE_WAY", "COMPLETED"].contains(_status);

  num  get _subtotal      => num.tryParse(_order["subtotal"]?.toString()       ?? "0") ?? 0;
  num  get _serviceCharge => num.tryParse(_order["service_charge"]?.toString() ?? "0") ?? 0;
  num  get _total         => num.tryParse(_order["total"]?.toString()           ?? "0") ?? 0;
  bool get _hasCharge     => _serviceCharge > 0;

String get _svcName    => (_order["service_names"] ?? _order["service_name"] ?? _order["category"] ?? "Service").toString();

  num    get _discount    => num.tryParse(_order["discount_amount"]?.toString() ?? "0") ?? 0;
  bool   get _hasDiscount => _discount > 0;
  String get _couponCode  => (_order["coupon_code"] ?? "").toString();

  // ── Privacy guard: hide carer details once service is completed ───────────────
  bool   get _hasCarer   =>
      !_completed &&
      (_order["caregiver_name"]?.toString().trim().isNotEmpty ?? false);
  String get _carerPhone => _completed ? "" : (_order["caregiver_phone"]?.toString() ?? "");

  // ── Professional / verified caretaker badge (Instagram-style blue tick) ──────
  bool get _isVerifiedCarer {
    final v = _order["caregiver_verified"] ??
        _order["caregiver_is_professional"] ??
        _order["is_verified"] ??
        _order["caretaker_verified"];
    if (v == null) return false;
    if (v is bool) return v;
    return v.toString().trim().toLowerCase() == "true" || v.toString() == "1";
  }

  double? get _cLat => double.tryParse(_order["caretaker_latitude"]?.toString()  ?? "");
  double? get _cLng => double.tryParse(_order["caretaker_longitude"]?.toString() ?? "");
  double? get _uLat => double.tryParse(_order["latitude"]?.toString()            ?? "");
  double? get _uLng => double.tryParse(_order["longitude"]?.toString()           ?? "");

  bool get _tracking =>
      _status == "ON_THE_WAY" &&
      _cLat != null && _cLng != null &&
      _uLat != null && _uLng != null;

  double get _meters {
    if (!_tracking) return 0;
    return const Distance().as(LengthUnit.Meter, LatLng(_cLat!, _cLng!), LatLng(_uLat!, _uLng!));
  }

  String get _distLabel {
    final m = _meters;
    return m < 1000 ? "${m.round()} m away" : "${(m / 1000).toStringAsFixed(1)} km away";
  }

  String get _etaLabel {
    final mins = _meters <= 0 ? 0 : ((_meters / 1000 / 25) * 60).ceil();
    if (mins <= 0) return "Arriving soon";
    return "Arriving in ~$mins min${mins == 1 ? '' : 's'}";
  }

  int get _step => switch (_status) {
    "CONFIRMED"  => 0,
    "ACCEPTED"   => 1,
    "ON_THE_WAY" => 2,
    "COMPLETED"  => 3,
    _            => 0,
  };

  Color get _statusColor => switch (_status) {
    "COMPLETED"  => _totalGreen,
    "ACCEPTED"   => AppColors.primary,
    "ON_THE_WAY" => AppColors.accent,
    "CONFIRMED"  => AppColors.warning,
    "CANCELLED"  => AppColors.danger,
    _            => AppColors.muted,
  };

  String get _statusLabel => switch (_status) {
    "CONFIRMED"  => "Awaiting Caretaker",
    "ACCEPTED"   => "Caretaker Assigned",
    "ON_THE_WAY" => "On The Way",
    "COMPLETED"  => "Service Completed",
    "CANCELLED"  => "Booking Cancelled",
    _            => _status,
  };

  String get _fmtDate {
    try {
      final d = DateTime.parse(_order["date"].toString()).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}";
    } catch (_) { return _order["date"]?.toString() ?? "-"; }
  }

  Map<String, dynamic> get _refundPreview {
    final method  = (_order["payment_method"] ?? "").toString();
    final pStatus = (_order["payment_status"] ?? "").toString().toUpperCase();
    final sub     = double.tryParse(_order["subtotal"]?.toString() ?? "0") ??
                    double.tryParse(_order["total"]?.toString()    ?? "0") ?? 0;
    if (method != "RAZORPAY" || pStatus != "PAID") {
      return {"percent": 0, "amount": 0.0, "note": "COD bookings are not eligible for refund."};
    }
    try {
      final slot = DateTime.parse(
          "${_order["date"].toString().split("T").first}T${_order["slot"] ?? "00:00:00"}");
      final diff = slot.difference(DateTime.now());
      if (diff.inHours >= 3) return {"percent": 100, "amount": sub,      "note": "Full refund. Service charge is non-refundable."};
      if (!diff.isNegative) return {"percent": 50,  "amount": sub * 0.5, "note": "50% refund. Service charge is non-refundable."};
      return {"percent": 0, "amount": 0.0, "note": "Slot time passed — no refund applicable."};
    } catch (_) { return {"percent": 0, "amount": 0.0, "note": "Unable to calculate refund."}; }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    themeNotifier.addListener(_rb);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    themeNotifier.removeListener(_rb);
    _anim.dispose();
    // Always release the screenshot lock when leaving this screen so it
    // doesn't leak into the rest of the app.
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  void _rb() { if (mounted) setState(() {}); }

  // ── Screenshot / screen-recording protection ─────────────────────────────────
  // Enabled the instant the booking moves to ACCEPTED (and stays enabled
  // through ON_THE_WAY / COMPLETED). Disabled while still CONFIRMED
  // (pending) or if the booking is CANCELLED. This is purely a native-layer
  // protection — intentionally silent, no UI copy is shown for it.
  Future<void> _syncScreenshotProtection() async {
    final shouldBlock = _shouldBlockScreenshot;
    if (shouldBlock == _screenshotBlocked) return;
    _screenshotBlocked = shouldBlock;
    try {
      if (shouldBlock) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      debugPrint("SCREENSHOT PROTECTION ERROR: $e");
      debugPrint("ORDER PAYLOAD: ${jsonEncode(_live)}");
    }
  }

  // ── OSRM Route ────────────────────────────────────────────────────────────────
  Future<void> _loadRoute() async {
    try {
      final url =
          "https://router.project-osrm.org/route/v1/driving/"
          "${_cLng!.toStringAsFixed(6)},${_cLat!.toStringAsFixed(6)};"
          "${_uLng!.toStringAsFixed(6)},${_uLat!.toStringAsFixed(6)}"
          "?overview=full&geometries=geojson";
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data   = jsonDecode(res.body);
      final coords = data["routes"][0]["geometry"]["coordinates"] as List;
      final pts    = coords
          .map((e) => LatLng((e[1] as num).toDouble(), (e[0] as num).toDouble()))
          .toList();
      if (mounted) setState(() => _routePoints = pts);
    } catch (e) {
      debugPrint("ROUTE ERROR: $e");
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/orders/detail/${widget.orders.first["id"]}"))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["order"] != null && mounted) {
          setState(() { _live = data["order"]; _loading = false; });
          await _syncScreenshotProtection();
          if (_tracking) await _loadRoute();
          if (_tracking && !_mapReady) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapCtrl.move(LatLng(_cLat!, _cLng!), 15);
              _mapReady = true;
            });
          }
          if (!silent) _anim.forward(from: 0);
        }
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _cancelOrder(int id, String reason) async {
    setState(() => _cancelling = true);
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/orders/$id/cancel"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"reason": reason}),
      );
      final d = jsonDecode(res.body);
      if (mounted) {
        if (d["success"] == true) {
          _showRefundSheet(d["refund"] as Map?);
          _refresh();
        } else {
          _snack(d["message"] ?? "Could not cancel.", AppColors.danger);
        }
      }
    } catch (_) {
      if (mounted) _snack("Network error.", AppColors.danger);
    }
    if (mounted) setState(() => _cancelling = false);
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: c,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Column(children: [
      _header(),
      Expanded(
        child: _loading
            ? _loadingView()
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: _surface,
                onRefresh: _refresh,
                child: FadeTransition(
                  opacity: _fade,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel("Booking Progress"),
                      _progressCard(),
                      if (_tracking) ...[
                        const SizedBox(height: 20),
                        _sectionLabel("Live Tracking"),
                        _trackingCard(),
                      ],
                      const SizedBox(height: 20),
                      _sectionLabel("Service Details"),
                      _serviceCard(),
                      const SizedBox(height: 20),
                      _sectionLabel("Payment"),
                      _paymentCard(),
                      const SizedBox(height: 20),
                      _sectionLabel("Location & Schedule"),
                      _locationCard(),
                      const SizedBox(height: 20),
                      if (_cancellable) _cancelBtn(),
                      if (!_cancellable && !_completed && !_cancelled)
                        _blockedCancelNote(),
                      if (_completed && _order["caretaker_id"] != null) ...[
                        const SizedBox(height: 10),
                        _feedbackBtn(),
                      ],
                    ]),
                  ),
                ),
              ),
      ),
    ]),
  );

  Widget _loadingView() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 44, height: 44,
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
          backgroundColor: AppColors.primary.withOpacity(0.1),
        ),
      ),
      const SizedBox(height: 14),
      Text("Loading order…",
          style: TextStyle(color: _subText, fontSize: 13)),
    ]),
  );

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16, right: 16, bottom: 26,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: Row(children: [
      _hBtn(Icons.chevron_left_rounded, () => Navigator.pop(context)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "Booking Details",
            style: TextStyle(
              color: Colors.white, fontSize: 21,
              fontWeight: FontWeight.w800, letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 7, height: 7,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cancelled
                    ? AppColors.danger
                    : _completed
                        ? Colors.white
                        : AppColors.warning,
                boxShadow: [BoxShadow(
                  color: (_cancelled
                      ? AppColors.danger
                      : _completed ? Colors.white : AppColors.warning).withOpacity(0.7),
                  blurRadius: 8,
                )],
              ),
            ),
            Text(
              _statusLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ]),
      ),
      GestureDetector(
        onTap: _refresh,
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFF4ADE80),
            ),
          ),
          const Text("LIVE",
              style: TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 0.8,
              )),
        ]),
      ),
    ]),
  );

  Widget _hBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );

  // ── Progress Card ─────────────────────────────────────────────────────────────
  Widget _progressCard() {
    final steps = [
      {"label": "Pending",    "icon": Icons.hourglass_top_rounded},
      {"label": "Accepted",   "icon": Icons.verified_user_rounded},
      {"label": "On The Way", "icon": Icons.electric_bike_rounded},
      {"label": "Completed",  "icon": Icons.check_circle_rounded},
    ];

    final pillColor = _cancelled
        ? AppColors.danger
        : (_completed || _status == "ACCEPTED" || _status == "ON_THE_WAY")
            ? AppColors.primary
            : AppColors.warning;

    final infoMsg = _cancelled ? null : switch (_status) {
      "CONFIRMED"  => "Looking for a caretaker — you'll be notified soon",
      "ACCEPTED"   => "Caretaker accepted your booking and preparing to travel",
      "ON_THE_WAY" => "Your caretaker is currently travelling to your location",
      "COMPLETED"  => "Service completed successfully — thank you for using Medico!",
      _            => "Booking is active",
    };

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Status pill ──────────────────────────────────────────────────────────
      AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: pillColor.withOpacity(0.09),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: pillColor.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _PulseDot(color: pillColor),
          const SizedBox(width: 8),
          Text(_statusLabel,
              style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700,
                color: pillColor, letterSpacing: 0.15,
              )),
        ]),
      ),

      const SizedBox(height: 28),

      // ── Step progress — single continuous connecting line, perfectly
      // aligned through every dot's center, so it never looks broken. ────────
      _stepperRow(steps),

      const SizedBox(height: 20),

      // ── Info / cancel note ────────────────────────────────────────────────────
      AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: _cancelled
              ? AppColors.danger.withOpacity(0.04)
              : (_dark ? Colors.white.withOpacity(0.03) : AppColors.lightBg),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _cancelled
                ? AppColors.danger.withOpacity(0.15)
                : AppColors.primary.withOpacity(0.08),
          ),
        ),
        child: _cancelled
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.cancel_outlined, color: AppColors.danger, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _order["cancel_reason"]?.toString().trim().isNotEmpty == true
                          ? "Reason: ${_order["cancel_reason"]}"
                          : "This booking was cancelled.",
                      style: TextStyle(
                        color: AppColors.danger, fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
                if (_order["refund_status"] != null &&
                    _order["refund_status"] != "NOT_ELIGIBLE") ...[
                  const SizedBox(height: 10),
                  _refundBadge(_order["refund_status"].toString()),
                ],
              ])
            : Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.primary.withOpacity(0.60)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    infoMsg ?? "",
                    style: TextStyle(
                      fontSize: 11.5, height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary.withOpacity(0.72),
                    ),
                  ),
                ),
              ]),
      ),
    ]));
  }

  // ── Stepper: a single background line + a single animated foreground line,
  // both laid out under a Row of evenly-spaced dots so the line always meets
  // dead-center of every dot — no matter the screen width. ─────────────────────
  Widget _stepperRow(List<Map<String, dynamic>> steps) {
    final n = steps.length;
    final fraction = _cancelled ? 0.0 : _step / (n - 1);
    const dotSize = 46.0;

    return LayoutBuilder(builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      final segment    = totalWidth / n;
      final sidePad    = segment / 2;
      final lineWidth  = totalWidth - sidePad * 2;

      return SizedBox(
        height: 92,
        child: Stack(children: [
          // Background (incomplete) line
          Positioned(
            top: dotSize / 2 - 2,
            left: sidePad,
            right: sidePad,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: _dark ? const Color(0xFF243445) : AppColors.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          // Foreground (completed) line
          Positioned(
            top: dotSize / 2 - 2,
            left: sidePad,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              height: 4,
              width: lineWidth * fraction,
              decoration: BoxDecoration(
                gradient: _cancelled ? null : AppColors.gradient,
                color: _cancelled ? AppColors.danger.withOpacity(0.4) : null,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.22),
                    blurRadius: 6, offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Dots + labels
          Row(
            children: List.generate(n, (i) {
              final isDone    = !_cancelled && i <= _step;
              final isCurrent = !_cancelled && i == _step;

              return Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDone ? AppColors.gradient : null,
                      color: isDone ? null : (_dark ? const Color(0xFF1C2838) : Colors.white),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary
                            : (isDone
                                ? Colors.transparent
                                : (_dark ? const Color(0xFF31465C) : AppColors.border)),
                        width: isCurrent ? 2.4 : 1.6,
                      ),
                      boxShadow: isCurrent
                          ? [BoxShadow(
                              color: AppColors.primary.withOpacity(0.36),
                              blurRadius: 16, spreadRadius: 2, offset: const Offset(0, 4))]
                          : isDone
                              ? [BoxShadow(
                                  color: AppColors.primary.withOpacity(0.15),
                                  blurRadius: 8, offset: const Offset(0, 2))]
                              : [],
                    ),
                    child: Icon(
                      steps[i]["icon"] as IconData,
                      color: isDone
                          ? Colors.white
                          : (_dark ? const Color(0xFF5C738A) : AppColors.muted),
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    steps[i]["label"] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.2,
                      color: isDone
                          ? AppColors.primary
                          : (_dark ? const Color(0xFF5C738A) : AppColors.muted),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ]),
      );
    });
  }

  // ── Live Tracking Card ────────────────────────────────────────────────────────
  Widget _trackingCard() {
    final carer = LatLng(_cLat!, _cLng!);
    final user  = LatLng(_uLat!, _uLng!);
    final carerName = _order["caregiver_name"]?.toString().trim().isNotEmpty == true
        ? _order["caregiver_name"].toString()
        : "Your Caretaker";

    return _card(child: Column(children: [

      // ── Carer banner ─────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.glowShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
              ),
              child: const Icon(Icons.electric_bike_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(carerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  if (_isVerifiedCarer) ...[
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: _showVerifiedInfo,
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                const Text("is on the way to you",
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ]),
            ),
            GestureDetector(
              onTap: _refresh,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Row(children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text("$_etaLabel  •  $_distLabel",
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 14),

      // ── Map (OpenStreetMap tiles) ────────────────────────────────────────────
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 300,
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: carer,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.medico.app",
                maxZoom: 19,
                tileProvider: NetworkTileProvider(),
                errorTileCallback: (tile, error, stackTrace) =>
                    debugPrint("MAP TILE ERROR: $error"),
              ),
              PolylineLayer(polylines: [
                Polyline(
                  points: _routePoints.isNotEmpty ? _routePoints : [carer, user],
                  strokeWidth: 7,
                  color: AppColors.primary,
                  borderStrokeWidth: 2.5,
                  borderColor: Colors.white.withOpacity(0.7),
                ),
              ]),
              MarkerLayer(markers: [
                Marker(
                  point: carer, width: 80, height: 80,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: AppColors.glowShadow,
                      ),
                      child: const Icon(Icons.electric_bike_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: AppColors.primary.withOpacity(0.4), blurRadius: 6)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          carerName.split(" ").first,
                          style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        if (_isVerifiedCarer) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.verified_rounded, size: 9, color: Colors.white),
                        ],
                      ]),
                    ),
                  ]),
                ),
                Marker(
                  point: user, width: 64, height: 64,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(
                            color: AppColors.danger.withOpacity(0.4),
                            blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: AppColors.danger.withOpacity(0.35), blurRadius: 6)],
                      ),
                      child: const Text("You",
                          style: TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                ),
              ]),
            ],
          ),
        ),
      ),

      const SizedBox(height: 12),

      _noteRow(
        icon: Icons.info_outline_rounded,
        text: "Route updates every 3 seconds. Tap the refresh icon to update instantly.",
        color: AppColors.primary,
      ),
    ]));
  }

  // ── Service Card ──────────────────────────────────────────────────────────────
  Widget _serviceCard() {
    final code = (_order["order_code"] ?? "").toString();
    final slot = (_order["slot"]       ?? "-").toString();
    final cat  = (_order["category"]   ?? "").toString();

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Text(_svcName,
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800,
              letterSpacing: -0.3, color: _text)),

      const SizedBox(height: 10),

      Row(children: [
        _tag(Icons.access_time_rounded, slot),
        if (cat.isNotEmpty) ...[
          const SizedBox(width: 8),
          _tag(Icons.local_hospital_outlined, cat, outline: true),
        ],
      ]),

      const SizedBox(height: 12),

      // Order code copy
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          _snack("Order ID copied!", AppColors.primary);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          ),
          child: Row(children: [
            const Icon(Icons.tag_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(code,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.primary,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                SizedBox(width: 4),
                Text("Copy",
                    style: TextStyle(
                        fontSize: 11, color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),

      const SizedBox(height: 16),
      _div(),
      const SizedBox(height: 16),

      // ── Carer info — hidden once completed ───────────────────────────────────
      if (_completed)
        _privacyBlock()
      else if (_hasCarer) ...[
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.gradient, shape: BoxShape.circle,
              boxShadow: AppColors.glowShadow,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(_order["caregiver_name"].toString(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          letterSpacing: -0.2, color: _text)),
                ),
                if (_isVerifiedCarer) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showVerifiedInfo,
                    child: const Icon(Icons.verified_rounded, size: 15, color: _verifiedBlue),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              if (_carerPhone.isNotEmpty)
                Row(children: [
                  Icon(Icons.phone_rounded, size: 12, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(_carerPhone,
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    _status == "ON_THE_WAY" ? "En Route 🏍" : "Assigned",
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                if (_isVerifiedCarer) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _showVerifiedInfo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _verifiedBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _verifiedBlue.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.verified_rounded, size: 10, color: _verifiedBlue),
                        const SizedBox(width: 3),
                        Text("Professional",
                            style: TextStyle(
                                fontSize: 9.5, color: _verifiedBlue,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
          if (_carerPhone.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse("tel:$_carerPhone")),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient, shape: BoxShape.circle,
                  boxShadow: AppColors.glowShadow,
                ),
                child: const Icon(Icons.call_rounded, size: 20, color: Colors.white),
              ),
            ),
        ]),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Looking for a caretaker…",
                    style: TextStyle(
                        color: AppColors.warning, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text("We'll notify you once someone accepts.",
                    style: TextStyle(color: AppColors.warning, fontSize: 11.5)),
              ]),
            ),
          ]),
        ),
      ],
    ]));
  }

  // ── Verified caretaker info (Instagram-style tap-on-badge sheet) ─────────────
  void _showVerifiedInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: _handle()),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _verifiedBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: _verifiedBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text("Professional (Verified) Caretaker",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
            ),
          ]),
          const SizedBox(height: 14),
          Text(
            "This blue tick means the caretaker's identity, certifications and "
            "background have been checked and verified by Medico, so you can "
            "book with confidence.",
            style: TextStyle(fontSize: 13.5, height: 1.5, color: _subText),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.glowShadow,
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Got it",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Privacy Block (shown when service is COMPLETED) ───────────────────────────
  Widget _privacyBlock() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _dark
          ? Colors.white.withOpacity(0.04)
          : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _dark
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFCBD5E1),
      ),
    ),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: _dark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.lock_rounded,
          color: _dark ? Colors.white38 : const Color(0xFF94A3B8),
          size: 22,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            "Caretaker details hidden",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Contact information is blocked after service completion to protect caretaker privacy.",
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: _dark ? Colors.white38 : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    ]),
  );

  // ── Payment Card ──────────────────────────────────────────────────────────────
  Widget _paymentCard() {
    final method  = (_order["payment_method"] ?? "COD").toString();
    final pStatus = (_order["payment_status"] ?? "PENDING").toString().toUpperCase();
    final rStatus = (_order["refund_status"]  ?? "").toString().toUpperCase();
    final isPaid  = pStatus == "PAID";
    final rAmt    = num.tryParse(_order["refund_amount"]?.toString() ?? "0") ?? 0;

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_hasCharge) ...[
        _row(Icons.receipt_outlined, "Service Amount", "₹$_subtotal"),
        _div(),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.miscellaneous_services_rounded,
                color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Service Charge",
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Row(children: [
                Text("₹$_serviceCharge",
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700,
                        color: AppColors.warning)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text("Non-refundable",
                      style: TextStyle(
                          fontSize: 10, color: AppColors.warning,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ]),
        _div(),
      ],

      if (_hasDiscount) ...[
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _totalGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.local_offer_rounded,
                color: _totalGreen, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  _couponCode.isNotEmpty
                      ? "Coupon ($_couponCode)"
                      : "Discount",
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text("−₹$_discount",
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700,
                      color: _totalGreen)),
            ]),
          ),
        ]),
        _div(),
      ],

      // ── Total amount row — prominent with deep green ──────────────────────────
      _totalRow(_hasCharge ? "Total (incl. charge)" : "Total Amount", "₹$_total"),

      _div(),
      _row(Icons.payment_outlined, "Payment Method", method),
      _div(),
      _row(
        isPaid ? Icons.verified_rounded : Icons.pending_outlined,
        "Payment Status",
        isPaid ? "PAID" : "PENDING",
        vc: isPaid ? AppColors.primary : AppColors.warning,
      ),
      if (rAmt > 0) ...[
        _div(),
        _row(Icons.account_balance_wallet_outlined, "Refund Amount", "₹$rAmt",
            vc: switch (rStatus) {
              "REFUNDED" => _totalGreen,
              "REJECTED" => AppColors.danger,
              _          => AppColors.warning,
            }),
        const SizedBox(height: 10),
        _refundBadge(rStatus.isEmpty ? "PENDING" : rStatus),
      ],
    ]));
  }

  // ── Dedicated total row with stronger green treatment ─────────────────────────
  Widget _totalRow(String label, String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _totalGreen.withOpacity(_dark ? 0.10 : 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _totalGreen.withOpacity(0.22)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _totalGreen.withOpacity(0.13),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.currency_rupee_rounded, color: _totalGreen, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: _totalGreen.withOpacity(0.75),
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(val,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: _totalGreen,
              )),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _totalGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _totalGreen.withOpacity(0.25)),
        ),
        child: Text("TOTAL",
            style: TextStyle(
                fontSize: 10, color: _totalGreen,
                fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      ),
    ]),
  );

  // ── Location Card ─────────────────────────────────────────────────────────────
  Widget _locationCard() => _card(child: Column(children: [
    _row(Icons.location_on_outlined, "Service Address",
        (_order["location"] ?? "-").toString()),
    _div(),
    _row(Icons.calendar_today_outlined, "Date", _fmtDate),
    _div(),
    _row(Icons.access_time_rounded, "Time Slot",
        (_order["slot"] ?? "-").toString()),
  ]));

  // ── Action Buttons ────────────────────────────────────────────────────────────
  Widget _cancelBtn() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _cancelling ? null : _showCancelSheet,
      icon: _cancelling
          ? SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.danger))
          : Icon(Icons.cancel_outlined, size: 15, color: AppColors.danger),
      label: Text("Cancel Booking",
          style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        side: BorderSide(color: AppColors.danger, width: 1.5),
      ),
    ),
  );

  Widget _blockedCancelNote() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    decoration: BoxDecoration(
      color: AppColors.warning.withOpacity(0.07),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.warning.withOpacity(0.25)),
    ),
    child: Row(children: [
      Icon(Icons.lock_rounded, color: AppColors.warning, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          "Cancellation is not allowed once the caretaker is on the way.",
          style: TextStyle(
              color: AppColors.warning, fontSize: 12.5,
              fontWeight: FontWeight.w600),
        ),
      ),
    ]),
  );

  Widget _feedbackBtn() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.glowShadow,
    ),
    child: ElevatedButton.icon(
      icon: const Icon(Icons.star_rounded, size: 18),
      label: const Text("Rate & Give Feedback",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CareSeekerFeedbackScreen(
            caregiverId:    _order["caretaker_id"]    ?? 0,
            orderId:        _order["id"]               ?? 0,
            caregiverName:  _order["caregiver_name"]  ?? "",
            caregiverPhone: _order["caregiver_phone"] ?? "",
          ),
        ),
      ),
    ),
  );

  // ── Cancel Sheet ──────────────────────────────────────────────────────────────
  void _showCancelSheet() {
    final ctrl   = TextEditingController();
    final refund = _refundPreview;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [

            Center(child: _handle()),

            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
              ),
              const SizedBox(width: 12),
              Text("Cancel Booking",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.danger)),
            ]),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (refund["percent"] == 0
                    ? AppColors.warning : AppColors.primary).withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (refund["percent"] == 0
                      ? AppColors.warning : AppColors.primary).withOpacity(0.18),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                    refund["percent"] == 100
                        ? Icons.check_circle_outline_rounded
                        : refund["percent"] == 50
                            ? Icons.warning_amber_rounded
                            : Icons.money_off_rounded,
                    color: refund["percent"] == 0 ? AppColors.warning : AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      refund["percent"] == 0
                          ? "No Refund Applicable"
                          : "Refund ${refund["percent"]}%  •  ₹${(refund["amount"] as double).toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: refund["percent"] == 0
                            ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(refund["note"] as String,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.4, color: _subText)),
                if (_hasCharge) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.warning.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text("Service charge ₹$_serviceCharge is non-refundable.",
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.warning.withOpacity(0.9),
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ]),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CancellationPolicyScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.policy_outlined, size: 17, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Cancellation & Refund Policy",
                          style: TextStyle(
                              fontSize: 13.5, color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text("Read before confirming your cancellation",
                          style: TextStyle(
                              fontSize: 11, color: AppColors.primary,
                              fontWeight: FontWeight.w400)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 22),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            Text("Reason for cancellation",
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: _subText)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              style: TextStyle(color: _text, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Please tell us why you're cancelling…",
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                filled: true,
                fillColor: _dark ? const Color(0xFF0F172A) : AppColors.lightBg,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.danger, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: _dark ? Colors.grey.shade700 : AppColors.border)),
              ),
            ),

            const SizedBox(height: 18),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text("Keep Booking",
                      style: TextStyle(
                          color: _subText, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (ctrl.text.trim().isEmpty) {
                      _snack("Please enter a reason.", AppColors.danger);
                      return;
                    }
                    Navigator.pop(context);
                    _cancelOrder(_order["id"] as int, ctrl.text.trim());
                  },
                  child: const Text("Confirm Cancel",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Refund Result Sheet ───────────────────────────────────────────────────────
  void _showRefundSheet(Map? refund) {
    final ok     = refund?["eligible"] == true;
    final amount = refund?["refundAmount"] ?? 0;
    final pct    = refund?["refundPercent"] ?? 0;
    final note   = refund?["note"] ?? "Booking cancelled.";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (ok ? AppColors.primary : AppColors.muted).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? Icons.account_balance_wallet_rounded : Icons.money_off_rounded,
              color: ok ? AppColors.primary : AppColors.muted,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(ok ? "Refund Initiated" : "No Refund",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: ok ? AppColors.primary : AppColors.muted)),
          if (ok) ...[
            const SizedBox(height: 10),
            Text("₹${(amount as num).toStringAsFixed(0)}",
                style: const TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w900,
                    color: _totalGreen)),
            const SizedBox(height: 4),
            Text("$pct% of service amount",
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (ok ? AppColors.primary : AppColors.warning).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (ok ? AppColors.primary : AppColors.warning).withOpacity(0.18),
              ),
            ),
            child: Text(note.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5, height: 1.5, color: _subText)),
          ),
          if (ok) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Refund will be credited within 5–7 business days.",
                      style: TextStyle(
                          fontSize: 12, color: AppColors.info, height: 1.4)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.glowShadow,
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Got it",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────────────────
  Widget _handle() => Container(
    width: 40, height: 4,
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: AppColors.border, borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border.withOpacity(_dark ? 0.3 : 1), width: 1),
      boxShadow: AppColors.cardShadow,
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10),
    child: Text(t,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800,
            letterSpacing: -0.2, color: _text)),
  );

  Widget _div() => Divider(height: 24, thickness: 0.7, color: _divider);

  // Small reusable "info strip" — used for the tracking tip.
  Widget _noteRow({required IconData icon, required String text, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 11.5, color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _tag(IconData icon, String label, {bool outline = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: outline ? Colors.transparent : AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(9),
      border: outline ? Border.all(color: AppColors.primary.withOpacity(0.2)) : null,
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.primary),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _row(IconData icon, String label, String val,
      {Color? vc, bool large = false}) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: AppColors.muted, fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(val,
                style: TextStyle(
                  fontSize: large ? 18 : 14.5,
                  fontWeight: large ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: large ? -0.3 : 0,
                  color: vc ?? _text,
                )),
          ]),
        ),
      ]);

  Widget _refundBadge(String status) {
    final (c, i, l) = switch (status.toUpperCase()) {
      "PENDING"  => (AppColors.warning, Icons.hourglass_top_rounded,        "Refund Under Review"),
      "REFUNDED" => (_totalGreen,       Icons.check_circle_outline_rounded,  "Refund Processed"),
      "REJECTED" => (AppColors.danger,  Icons.cancel_outlined,               "Refund Rejected"),
      _          => (AppColors.muted,   Icons.info_outline_rounded,          status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 14, color: c),
        const SizedBox(width: 6),
        Text(l, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Animated Pulse Dot ────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.75, end: 1.25)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
    ),
  );
}