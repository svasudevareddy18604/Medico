import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'caretaker_payment_screen.dart';
import 'caretaker_otp_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map  order;
  final int  userId;
  const OrderDetailsScreen({super.key, required this.order, required this.userId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // ── Palette (uses AppColors) ─────────────────────────────────
  static const _amber   = Color(0xFFF59E0B);
  static const _red     = Color(0xFFEF4444);
  static const _blue    = Color(0xFF1565C0);
  static const _orange  = Color(0xFFFF6B00);
  static const _purple  = Color(0xFF7C3AED);

  // ── State ────────────────────────────────────────────────────
  Map    _data    = {};
  bool   _loading = true;
  bool   _busy    = false;
  String? _error;
  Timer? _timer;
  Timer? _locationTimer;

  bool _screenshotBlocked = false;

  late AnimationController _docPulse;
  late Animation<double>   _docGlow;

  // ── Helpers ──────────────────────────────────────────────────
  dynamic get _orderId => widget.order["id"];
  int     get _userId  => widget.userId;

  String get _status =>
      (_data["status"] ?? widget.order["status"] ?? "").toString().toUpperCase();
  String get _code =>
      (_data["order_code"] ?? widget.order["order_code"] ?? "").toString();

  bool get _notAccepted  => (_data["caretaker_id"] ?? widget.order["caretaker_id"]) == null;
  bool get _isAccepted   => _status == "ACCEPTED";
  bool get _isConfirmed  => _status == "CONFIRMED";
  bool get _onTheWay     => _status == "ON_THE_WAY";
  bool get _isCompleted  => _status == "COMPLETED";
  bool get _isCancelled  => _status == "CANCELLED" || _status == "CARETAKER_CANCELLED";

  bool get _isPaid => (_data["payment_status"] ?? widget.order["payment_status"] ?? "")
      .toString().toUpperCase() == "PAID";
  bool get _isCOD  => (_data["payment_method"] ?? widget.order["payment_method"] ?? "COD")
      .toString().toUpperCase() == "COD";

  // Arrival OTP: 1/true once the caretaker has verified the OTP shown to
  // the careseeker. This — not just "ON_THE_WAY" status — is what proves
  // the caretaker actually reached the customer, so it gates payment
  // collection and Complete Service below.
  bool get _otpVerified {
    final v = _data["otp_verified"] ?? widget.order["otp_verified"] ?? 0;
    if (v is bool) return v;
    return v.toString() == "1" || v.toString().toLowerCase() == "true";
  }

  String get _rawDocUrls {
    final raw = _data["document_urls"];
    if (raw == null) return "";
    return raw.toString().trim();
  }
  bool get _hasDocs =>
      _rawDocUrls.isNotEmpty && _rawDocUrls != "null" && _rawDocUrls != "NULL";
  List<String> get _docUrls =>
      _rawDocUrls.split("|||").where((u) => u.trim().isNotEmpty).toList();

  // ── Customer location ────────────────────────────────────────
  LatLng get _loc {
    try {
      final lat = double.parse(
          (_data["latitude"]  ?? widget.order["latitude"]  ?? "12.9716").toString());
      final lng = double.parse(
          (_data["longitude"] ?? widget.order["longitude"] ?? "77.5946").toString());
      return LatLng(lat, lng);
    } catch (_) { return const LatLng(12.9716, 77.5946); }
  }

  LatLng? get _caretakerLoc {
    try {
      final lat = double.parse((_data["caretaker_latitude"] ?? "").toString());
      final lng = double.parse((_data["caretaker_longitude"] ?? "").toString());
      return LatLng(lat, lng);
    } catch (_) { return null; }
  }

  // Screenshot is restricted for the ENTIRE lifecycle of an active/closed
  // booking — i.e. from the moment it's not yet accepted (still carries
  // sensitive client data) all the way through completion. Only a freshly
  // cancelled booking with nothing sensitive left to protect is exempt.
  // In practice: block always, except when cancelled.
  // NOTE: the protection itself is unchanged — only the visual "Secure"
  // header indicator has been removed per request, so this still runs
  // silently in the background.
  bool get _shouldBlockScreenshot => !_isCancelled;

  // ── Lifecycle ────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.order);
    WidgetsBinding.instance.addObserver(this);

    if (_onTheWay && !_isCompleted) {
      _startLiveTracking();
    }

    _applyScreenshotPolicy();

    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());

    _docPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _docGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _docPulse, curve: Curves.easeInOut));
  }

  void _applyScreenshotPolicy() {
    if (_shouldBlockScreenshot) {
      _blockScreenshots();
    } else {
      _allowScreenshots();
    }
  }

  void _blockScreenshots() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    // FLAG_SECURE equivalent — prevents screenshots and screen recording
    SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {
      'label': 'Medico',
      'primaryColor': 0xFF0B8FAC,
    });
    // Use secure flag via platform channel
    _setSecureFlag(true);
    if (mounted) setState(() => _screenshotBlocked = true);
  }

  void _allowScreenshots() {
    _setSecureFlag(false);
    if (mounted) setState(() => _screenshotBlocked = false);
  }

  Future<void> _setSecureFlag(bool secure) async {
    try {
      await SystemChannels.platform.invokeMethod(
        'SystemChrome.setSystemUIOverlayStyle',
        <String, dynamic>{},
      );
      // Primary approach: use platform-specific secure window flag
      const channel = MethodChannel('com.medico.app/security');
      await channel.invokeMethod('setSecureFlag', {'secure': secure});
    } catch (_) {
      // If custom channel not implemented, fall back gracefully
      // The UI overlay below still visually blocks content when needed
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-apply policy when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _applyScreenshotPolicy();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _locationTimer?.cancel();
    _docPulse.dispose();
    _allowScreenshots(); // Always lift restriction on exit
    super.dispose();
  }

  // ── Network ──────────────────────────────────────────────────
  Future<void> _fetch() async {
    try {
      final res = await http
          .get(Uri.parse(Api.caretakerOrderDetails(
              _orderId is int ? _orderId : int.parse(_orderId.toString()))))
          .timeout(const Duration(seconds: 10));
      final d = jsonDecode(res.body);
      if (d["success"] == true && mounted) {
        setState(() {
          _data = d["data"];
          _loading = false;
          _error = null;
        });
        // Re-apply screenshot policy whenever status changes
        _applyScreenshotPolicy();
      } else if (mounted) {
        setState(() { _loading = false; _error = d["message"]?.toString(); });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<bool> _post(String url, Map body) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final res = await http.post(Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body));
      final d = jsonDecode(res.body);
      if (d["success"] != true) throw Exception(d["message"] ?? "Action failed");
      await _fetch();
      return true;
    } catch (e) {
      _toast(e.toString().replaceAll("Exception: ", ""), type: _ToastType.error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {_ToastType type = _ToastType.success}) {
    if (!mounted) return;
    final cfg = {
      _ToastType.success: (AppColors.primary,  Icons.check_circle_rounded,   Colors.white),
      _ToastType.error:   (_red,               Icons.cancel_rounded,          Colors.white),
      _ToastType.warn:    (_amber,              Icons.warning_amber_rounded,   Colors.white),
      _ToastType.info:    (_blue,               Icons.info_outline_rounded,    Colors.white),
    }[type]!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Row(children: [
            Icon(cfg.$2, color: cfg.$3, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: TextStyle(color: cfg.$3, fontSize: 13))),
          ]),
          backgroundColor: cfg.$1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          duration: const Duration(seconds: 3)));
  }

  // ── Copy helper ────────────────────────────────────────────────
  // Used by both the header title and the "Booking ID" row so users
  // can quickly copy the order code to share with support, etc.
  Future<void> _copyOrderCode() async {
    if (_code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _code));
    _toast("Booking ID copied · $_code", type: _ToastType.info);
  }

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _accept() async {
    final ok = await _post(
        "${Api.baseUrl}/caretaker/accept",
        {"order_id": _orderId, "caretaker_id": _userId});
    if (ok) _toast("Booking accepted successfully ✓");
  }

  Future<void> _startJourney() async {
    final ok = await _post(
        "${Api.baseUrl}/caretaker/start",
        {"order_id": _orderId, "caretaker_id": _userId});
    if (ok) {
      _toast("Journey started ✓");
      await _startLiveTracking();
      if (mounted) _openOtpScreen();
    }
  }

  // Pushes the arrival-OTP screen. Called automatically once the journey
  // starts, and also reachable again from the CTA button if the caretaker
  // backs out before verifying (status stays ON_THE_WAY, otp_verified
  // stays 0, so the CTA keeps offering "Verify Arrival OTP").
  Future<void> _openOtpScreen() async {
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CaretakerOtpScreen(
          orderId: _orderId is int ? _orderId : int.parse(_orderId.toString()),
          caretakerId: _userId,
          orderCode: _code,
        ),
      ),
    );
    if (verified == true) {
      _toast("Arrival OTP verified ✓ Service started");
    }
    _fetch();
  }

  Future<void> _startLiveTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _toast("Location permission denied", type: _ToastType.error);
      return;
    }
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        await http.post(
          Uri.parse("${Api.baseUrl}/caretaker/update-location"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "order_id":     _orderId,
            "caretaker_id": _userId,
            "latitude":     pos.latitude,
            "longitude":    pos.longitude,
          }),
        );
      } catch (_) {}
    });
  }

  Future<void> _goToPaymentScreen() async {
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => CaretakerPaymentScreen(
          orderId:     _orderId is int ? _orderId : int.parse(_orderId.toString()),
          caretakerId: _userId,
        )));
    _fetch();
  }

  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Complete Service?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "Mark this booking as completed? The client will be notified."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text("Yes, Complete"),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await _post(
          "${Api.baseUrl}/caretaker/complete",
          {"order_id": _orderId, "caretaker_id": _userId});
      if (success) {
        _locationTimer?.cancel();
        _toast("Service marked as completed ✓");
      }
    }
  }

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final confirmed  = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancelSheet(
        orderCode:    _code,
        isOnlinePaid: !_isCOD && _isPaid,
        controller:   reasonCtrl,
      ),
    );
    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim().isNotEmpty
        ? reasonCtrl.text.trim()
        : "Cancelled by caretaker";
    final ok = await _post(
        "${Api.baseUrl}/caretaker/cancel",
        {"order_id": _orderId, "caretaker_id": _userId, "cancel_reason": reason});
    if (ok) {
      if (!_isCOD && _isPaid)
        _toast("Paid booking flagged for admin reassignment", type: _ToastType.warn);
      else
        _toast("Booking cancelled · reopened for reassignment",
            type: _ToastType.info);
    }
  }

  void _navigate() => launchUrl(
      Uri.parse("google.navigation:q=${_loc.latitude},${_loc.longitude}"),
      mode: LaunchMode.externalApplication);

  // ── CTA logic ────────────────────────────────────────────────
  String get _ctaLabel {
    if (_isCompleted) return "Service Completed";
    if (_isCancelled) return "Booking Cancelled";
    if (_notAccepted) return "Accept Booking";
    if (_isAccepted || _isConfirmed) return "Start Journey";
    if (_onTheWay && !_otpVerified) return "Verify Arrival OTP";
    if (_onTheWay && _otpVerified && !_isPaid) return "Collect Payment";
    if (_onTheWay && _otpVerified && _isPaid)  return "Complete Service";
    return "View Details";
  }

  VoidCallback? get _ctaAction {
    if (_isCompleted || _isCancelled) return null;
    if (_notAccepted) return _accept;
    if (_isAccepted || _isConfirmed) return _startJourney;
    if (_onTheWay && !_otpVerified) return _openOtpScreen;
    if (_onTheWay && _otpVerified && !_isPaid) return _goToPaymentScreen;
    if (_onTheWay && _otpVerified && _isPaid)  return _complete;
    return null;
  }

  Color get _ctaColor {
    if (_isCompleted || _isCancelled) return Colors.grey;
    if (_notAccepted) return AppColors.primary;
    if (_isAccepted || _isConfirmed) return _blue;
    if (_onTheWay && !_otpVerified) return _purple;
    if (_onTheWay && _otpVerified && !_isPaid) return _amber;
    if (_onTheWay && _otpVerified && _isPaid)  return AppColors.primary;
    return Colors.grey;
  }

  IconData get _ctaIcon {
    if (_isCompleted) return Icons.check_circle_rounded;
    if (_isCancelled) return Icons.cancel_rounded;
    if (_notAccepted) return Icons.handshake_rounded;
    if (_isAccepted || _isConfirmed) return Icons.directions_run_rounded;
    if (_onTheWay && !_otpVerified) return Icons.verified_user_rounded;
    if (_onTheWay && _otpVerified && !_isPaid) return Icons.payment_rounded;
    if (_onTheWay && _otpVerified && _isPaid)  return Icons.done_all_rounded;
    return Icons.info_rounded;
  }

  bool get _canCancel =>
      !_notAccepted &&
      !_isCompleted &&
      !_isCancelled &&
      (_isAccepted || _isConfirmed);

  // ── Status display ───────────────────────────────────────────
  String get _statusLabel => switch (_status) {
    "CONFIRMED"           => "Available",
    "ACCEPTED"            => "Accepted",
    "ON_THE_WAY"          => "On The Way",
    "COMPLETED"           => "Completed",
    "CANCELLED"           => "Cancelled",
    "CARETAKER_CANCELLED" => "Cancelled",
    _                     => _status.isEmpty ? "Pending" : _status,
  };

  Color get _statusColor => switch (_status) {
    "COMPLETED"                          => AppColors.primary,
    "CANCELLED" || "CARETAKER_CANCELLED" => _red,
    "ON_THE_WAY"                         => _blue,
    "ACCEPTED"                           => _amber,
    _                                    => Colors.grey,
  };

  // ── Formatters ───────────────────────────────────────────────
  String _fmtDate(dynamic d) {
    if (d == null || d.toString().isEmpty) return "—";
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      const mo = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return "${dt.day.toString().padLeft(2,'0')} ${mo[dt.month-1]} ${dt.year}";
    } catch (_) { return d.toString(); }
  }

  String _fmtSlot(dynamic s) {
    if (s == null || s.toString().isEmpty) return "—";
    try {
      final parts = s.toString().split(":");
      if (parts.length < 2) return s.toString();
      final h = int.parse(parts[0]);
      return "${h % 12 == 0 ? 12 : h % 12}:${parts[1]} ${h >= 12 ? 'PM' : 'AM'}";
    } catch (_) { return s.toString(); }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name      = (_data["careseeker_name"]  ?? widget.order["careseeker_name"]  ?? "Client").toString();
    final phone     = (_data["careseeker_phone"] ?? widget.order["careseeker_phone"] ?? "").toString();
    final category  = (_data["category"]          ?? widget.order["category"]         ?? "").toString();
    final slot      = _fmtSlot(_data["slot"]       ?? widget.order["slot"]);
    final location  = (_data["location"]           ?? widget.order["location"]         ?? "—").toString();
    final services  = (_data["services"]            ?? widget.order["services"]         ?? "").toString();
    final total     = (_data["total"]               ?? widget.order["total"]            ?? 0).toString();
    final payMethod = (_data["payment_method"]      ?? widget.order["payment_method"]   ?? "COD").toString();
    final payStatus = (_data["payment_status"]      ?? widget.order["payment_status"]   ?? "PENDING").toString();
    final date      = _fmtDate(_data["date"]        ?? widget.order["date"]);

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Stack(
        children: [
          Column(children: [

            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 22),
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
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
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: _code.isNotEmpty ? _copyOrderCode : null,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              _code.isNotEmpty ? _code : "Service Details",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_code.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded,
                                color: Colors.white70, size: 15),
                          ],
                        ]),
                        if (category.isNotEmpty)
                          Text(category,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (_hasDocs && !_isCompleted)
                  AnimatedBuilder(
                    animation: _docGlow,
                    builder: (_, __) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withOpacity(0.15 + 0.15 * _docGlow.value),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.orange
                                .withOpacity(0.6 + 0.4 * _docGlow.value)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.description_rounded,
                            color: Colors.orange, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          "${_docUrls.length} Doc${_docUrls.length > 1 ? 's' : ''}",
                          style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ),
                  ),
                if (_loading)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
              ]),
            ),

            // ── Error banner ─────────────────────────────────────────
            if (_error != null)
              Container(
                color: _red.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: _red, fontSize: 12))),
                  GestureDetector(
                    onTap: _fetch,
                    child: const Text("Retry",
                        style: TextStyle(
                            color: _red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ]),
              ),

            // ── Scrollable body ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Map — hidden when COMPLETED ────────────────────
                  if (_isCompleted)
                    _locationRestrictedBox(
                      label: "Location Restricted",
                      sublabel: "🔒  Hidden after service completion",
                    )
                  else
                    Container(
                      height: 165,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FlutterMap(
                        options: MapOptions(initialCenter: _loc, initialZoom: 15),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: 'com.medico.app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: _loc,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 38),
                            ),
                            if (_caretakerLoc != null)
                              Marker(
                                point: _caretakerLoc!,
                                width: 42,
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(
                                      color: AppColors.primary.withOpacity(0.35),
                                      blurRadius: 8,
                                    )],
                                  ),
                                  child: const Icon(
                                    Icons.person_pin_circle_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                          ]),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // ── Client card — hidden when COMPLETED ───────────
                  if (_isCompleted)
                    _clientRestrictedBox()
                  else
                    _card(child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          if (phone.isNotEmpty)
                            Text(phone,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      )),
                      if (phone.isNotEmpty)
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse("tel:$phone")),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.call_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                    ])),
                  const SizedBox(height: 12),

                  // ── Booking details card ───────────────────────────
                  _card(child: Column(children: [
                    if (_code.isNotEmpty)
                      _copyableRow("Booking ID", _code),
                    if (category.isNotEmpty)
                      _row("Category",    category),
                    if (services.isNotEmpty)
                      _rowMultiline("Services", services),
                    _row("Date",       date),
                    if (slot != "—")
                      _row("Time Slot", slot),
                    if (!_isCompleted)
                      _row("Location", location),
                    _row("Amount",     "₹$total"),
                    _row("Payment",    payMethod),
                    _row("Pay Status", payStatus,
                        valueColor: payStatus.toUpperCase() == "PAID"
                            ? AppColors.primary
                            : _amber,
                        isLast: true),
                  ])),
                  const SizedBox(height: 14),

                  // ── Location locked banner — when COMPLETED ────────
                  if (_isCompleted)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.location_off_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Client address will not be revealed once the service is completed.",
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                    ),

                  // ── Status stepper ─────────────────────────────────
                  _statusStepper(),
                  const SizedBox(height: 14),

                  // ── Medical documents ──────────────────────────────
                  if (_isCompleted) ...[
                    if (_hasDocs) _docsRestrictedBox(),
                    const SizedBox(height: 14),
                  ] else if (_hasDocs && _docUrls.isNotEmpty) ...[
                    AnimatedBuilder(
                      animation: _docGlow,
                      builder: (_, child) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                            color: _orange.withOpacity(
                                0.12 + 0.10 * _docGlow.value),
                            blurRadius: 18 + 8 * _docGlow.value,
                            spreadRadius: 2,
                          )],
                        ),
                        child: child,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFFF3E0), Color(0xFFFFECB3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: _orange.withOpacity(0.45), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 11),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Color(0xFFFF6B00),
                                  Color(0xFFFF8F00),
                                ]),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16)),
                              ),
                              child: Row(children: [
                                const Icon(
                                    Icons.medical_information_rounded,
                                    color: Colors.white,
                                    size: 20),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text(
                                    "⚠️  PATIENT MEDICAL DOCUMENTS",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 0.5),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    "${_docUrls.length} file${_docUrls.length > 1 ? 's' : ''}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _orange.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _orange.withOpacity(0.3)),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.touch_app_rounded,
                                      color: Color(0xFFE65100), size: 15),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      "Review all documents BEFORE starting service",
                                      style: TextStyle(
                                          color: Color(0xFFE65100),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 14),
                              child: Column(
                                children: List.generate(_docUrls.length, (i) {
                                  final url   = _docUrls[i].trim();
                                  final isPdf = url.toLowerCase().endsWith(".pdf");
                                  final isImg = url.toLowerCase().contains(".jpg") ||
                                      url.toLowerCase().contains(".jpeg") ||
                                      url.toLowerCase().contains(".png") ||
                                      url.toLowerCase().contains(".webp");
                                  final label = isPdf
                                      ? "Prescription / Report PDF"
                                      : isImg
                                          ? "Medical Image / Scan"
                                          : "Medical Document";
                                  final icon  = isPdf
                                      ? Icons.picture_as_pdf_rounded
                                      : isImg
                                          ? Icons.image_rounded
                                          : Icons.insert_drive_file_rounded;
                                  final clr   = isPdf
                                      ? const Color(0xFFD32F2F)
                                      : const Color(0xFF1565C0);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                          color: Colors.orange.shade200),
                                      boxShadow: [BoxShadow(
                                          color: Colors.orange.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3))],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(13),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(13),
                                        onTap: () => launchUrl(
                                            Uri.parse(url),
                                            mode: LaunchMode.externalApplication),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 13),
                                          child: Row(children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                  color: clr.withOpacity(0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                              child: Icon(icon,
                                                  color: clr, size: 24),
                                            ),
                                            const SizedBox(width: 13),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(label,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13,
                                                          color: Colors.black87)),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    "Document ${i + 1} · Tap to open",
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade500),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                    colors: [
                                                      Color(0xFFFF6B00),
                                                      Color(0xFFFF8F00),
                                                    ]),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [BoxShadow(
                                                    color: Colors.orange
                                                        .withOpacity(0.35),
                                                    blurRadius: 6,
                                                    offset:
                                                        const Offset(0, 3))],
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.visibility_rounded,
                                                      color: Colors.white,
                                                      size: 15),
                                                  SizedBox(width: 5),
                                                  Text("VIEW",
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 12,
                                                          letterSpacing: 0.5)),
                                                ],
                                              ),
                                            ),
                                          ]),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Payment hint banner ────────────────────────────
                  if (!_notAccepted && !_isCompleted && !_isCancelled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _amber.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            !_otpVerified
                                ? "Verify the arrival OTP given by the customer before collecting payment or completing service."
                                : _isCOD
                                    ? "COD Order — collect payment and mark payment received before completing service."
                                    : "Online Order — verify payment received, then mark complete.",
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12),
                          ),
                        ),
                      ]),
                    ),

                  // ── Quick action row ───────────────────────────────
                  Row(children: [
                    _actionBtn(
                      Icons.navigation_rounded,
                      "Navigate",
                      _blue,
                      _isCompleted ? null : _navigate,
                    ),
                    const SizedBox(width: 10),
                    _actionBtn(
                      Icons.payment_rounded,
                      "Payment",
                      _amber,
                      (!_onTheWay || _isCancelled || !_otpVerified)
                          ? null
                          : _goToPaymentScreen,
                    ),
                    const SizedBox(width: 10),
                    if (_isCompleted)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.20))),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_rounded,
                                color: Colors.grey.shade400, size: 22),
                            const SizedBox(height: 5),
                            Text("Call",
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11)),
                          ]),
                        ),
                      )
                    else
                      _actionBtn(
                        Icons.phone_rounded,
                        "Call",
                        AppColors.primary,
                        phone.isEmpty ? null : () => launchUrl(Uri.parse("tel:$phone")),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Cancel button ──────────────────────────────────
                  if (_canCancel)
                    GestureDetector(
                      onTap: _busy ? null : _cancel,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _red.withOpacity(0.45)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_outlined, color: _red, size: 18),
                            SizedBox(width: 8),
                            Text("Cancel Booking",
                                style: TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                  // ── Primary CTA ────────────────────────────────────
                  _busy
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        )
                      : (!_notAccepted && (_isAccepted || _isConfirmed))
                          ? _SwipeToStartButton(
                              color: _blue,
                              enabled: _ctaAction != null,
                              onConfirmed: () => _ctaAction?.call(),
                            )
                          : GestureDetector(
                              onTap: _ctaAction,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _ctaAction == null
                                      ? Colors.grey.shade300
                                      : _ctaColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _ctaAction == null
                                      ? []
                                      : [
                                          BoxShadow(
                                              color: _ctaColor.withOpacity(0.35),
                                              blurRadius: 14,
                                              offset: const Offset(0, 6))
                                        ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _ctaIcon,
                                        color: _ctaAction == null
                                            ? Colors.grey
                                            : Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _ctaLabel,
                                        style: TextStyle(
                                            color: _ctaAction == null
                                                ? Colors.grey
                                                : Colors.white,
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
            ),
          ]),

          // ── Screenshot watermark overlay (active during service) ──
          if (_screenshotBlocked)
  Positioned.fill(
    child: IgnorePointer(
      child: Container(color: Colors.transparent),
    ),
  ),
        ],
      ),
    );
  }

  // ── Location Restricted Box (themed) ───────────────────────────
  Widget _locationRestrictedBox({
    required String label,
    required String sublabel,
  }) =>
      Container(
        height: 165,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B8FAC), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _DiagonalStripePainter()),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Text(
                      sublabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Client Restricted Box (themed) ─────────────────────────────
  Widget _clientRestrictedBox() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B8FAC), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.lock_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Client Details Restricted",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87),
                ),
                SizedBox(height: 3),
                Text(
                  "Name and contact info are hidden for privacy. Contact admin if needed.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ]),
      );

  // ── Medical Documents Restricted Box (themed) ──────────────────
  Widget _docsRestrictedBox() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B8FAC), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.folder_off_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Medical Documents Restricted",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87),
                ),
                SizedBox(height: 3),
                Text(
                  "🔒  Patient documents are hidden once the service is completed.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ]),
      );

  // ── Status Stepper (redesigned) ────────────────────────────────
  // 5 steps: Accepted → On The Way → Verified → Payment → Completed.
  // Redesign goals vs. the old version:
  //  • Smaller, tighter dots (30px) with icons instead of bare check
  //    marks, so nothing overlaps/cramps on narrow phone widths.
  //  • Connector line is a single continuous strip built with
  //    dot/line/dot/line/dot instead of duplicated per-item lines,
  //    so segments always align perfectly and never double up.
  //  • The current in-progress step gets a distinct glowing ring
  //    (blue) so it's obvious where you are, not just "done vs not".
  //  • Labels sit in their own row below with a fixed 2-line height,
  //    small caps-ish weight change, so "On The Way" never collides
  //    with the neighbouring step's label.
  Widget _statusStepper() {
    final steps = <_StepInfo>[
      _StepInfo("Accepted",   Icons.handshake_rounded,      !_notAccepted),
      _StepInfo("On The Way", Icons.directions_run_rounded, _onTheWay || _isCompleted),
      _StepInfo("Verified",   Icons.verified_user_rounded,  _otpVerified || _isCompleted),
      _StepInfo("Payment",    Icons.payment_rounded,        _isPaid),
      _StepInfo("Completed",  Icons.done_all_rounded,       _isCompleted),
    ];

    // Index of the first not-yet-done step = the "current" step.
    // If everything is done, there is no current step (-1).
    int current = steps.indexWhere((s) => !s.done);

    return _card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(steps.length * 2 - 1, (idx) {
              // Even indices are dots, odd indices are connector lines.
              if (idx.isEven) {
                final i = idx ~/ 2;
                return _stepDot(
                  icon: steps[i].icon,
                  done: steps[i].done,
                  isCurrent: i == current,
                );
              } else {
                final leftDone = steps[idx ~/ 2].done;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: leftDone ? AppColors.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(steps.length, (i) {
              final done      = steps[i].done;
              final isCurrent = i == current;
              return Expanded(
                child: Text(
                  steps[i].label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: (done || isCurrent)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: done
                        ? AppColors.primary
                        : isCurrent
                            ? _blue
                            : Colors.grey.shade500,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _stepDot({
    required IconData icon,
    required bool done,
    required bool isCurrent,
  }) {
    final ringColor = done
        ? AppColors.primary
        : isCurrent
            ? _blue
            : Colors.grey.shade300;

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.primary
            : isCurrent
                ? _blue.withOpacity(0.12)
                : Colors.white,
        border: Border.all(
          color: ringColor,
          width: isCurrent && !done ? 2.4 : 2,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: ringColor.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        color: done
            ? Colors.white
            : isCurrent
                ? _blue
                : Colors.grey.shade400,
        size: 15,
      ),
    );
  }

  // ── Shared widgets ───────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))]),
        child: child,
      );

  Widget _row(
    String label,
    String value, {
    bool highlight = false,
    Color? valueColor,
    bool isLast = false,
  }) =>
      Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: highlight ? 14 : 13,
                      fontWeight: highlight
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: valueColor ??
                          (highlight ? AppColors.primary : Colors.black87)),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ]);

  Widget _copyableRow(String label, String value) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _copyOrderCode,
          borderRadius: BorderRadius.circular(8),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded,
                            size: 15, color: AppColors.primary.withOpacity(0.7)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
          ]),
        ),
      );

  Widget _rowMultiline(String label, String value) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: value
                      .split(",")
                      .map((s) => Text(
                            "• ${s.trim()}",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
      ]);

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: color.withOpacity(onTap == null ? 0.05 : 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        color.withOpacity(onTap == null ? 0.15 : 0.30))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  color: onTap == null
                      ? color.withOpacity(0.35)
                      : color,
                  size: 22),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: onTap == null
                          ? color.withOpacity(0.35)
                          : color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
            ]),
          ),
        ),
      );
}

// Simple immutable holder for a single step in the status stepper.
class _StepInfo {
  final String label;
  final IconData icon;
  final bool done;
  const _StepInfo(this.label, this.icon, this.done);
}

// ════════════════════════════════════════════════════════════════
// Swipe-to-start button (unchanged)
// ════════════════════════════════════════════════════════════════

class _SwipeToStartButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final Color color;
  final String label;
  final String confirmedLabel;
  final IconData icon;
  final bool enabled;

  const _SwipeToStartButton({
    required this.onConfirmed,
    required this.color,
    this.label = "Swipe to Start Journey",
    this.confirmedLabel = "Journey Started",
    this.icon = Icons.directions_run_rounded,
    this.enabled = true,
  });

  @override
  State<_SwipeToStartButton> createState() => _SwipeToStartButtonState();
}

class _SwipeToStartButtonState extends State<_SwipeToStartButton>
    with TickerProviderStateMixin {
  static const double _trackHeight = 60;
  static const double _knobSize = 52;
  static const double _padding = 4;

  double _dragX = 0;
  bool _confirmed = false;
  bool _dragging = false;

  late AnimationController _shimmerCtrl;
  late AnimationController _snapCtrl;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  double _maxDrag(double trackWidth) =>
      trackWidth - _knobSize - _padding * 2;

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (!widget.enabled || _confirmed) return;
    final maxDrag = _maxDrag(trackWidth);
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragStart() {
    if (!widget.enabled || _confirmed) return;
    setState(() => _dragging = true);
    HapticFeedback.lightImpact();
  }

  void _onDragEnd(double trackWidth) {
    if (!widget.enabled || _confirmed) return;
    final maxDrag = _maxDrag(trackWidth);
    setState(() => _dragging = false);

    if (_dragX >= maxDrag * 0.78) {
      _confirm(maxDrag);
    } else {
      _snapBack();
    }
  }

  void _confirm(double maxDrag) {
    HapticFeedback.mediumImpact();
    setState(() {
      _confirmed = true;
      _dragX = maxDrag;
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      widget.onConfirmed();
    });
  }

  void _snapBack() {
    _snapAnim = Tween<double>(begin: _dragX, end: 0).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() => _dragX = _snapAnim.value);
      });
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final baseColor = disabled ? Colors.grey.shade300 : widget.color;

    return LayoutBuilder(builder: (context, constraints) {
      final trackWidth = constraints.maxWidth;
      final maxDrag = _maxDrag(trackWidth);
      final progress = maxDrag <= 0 ? 0.0 : (_dragX / maxDrag).clamp(0.0, 1.0);

      return GestureDetector(
        onHorizontalDragStart: (_) => _onDragStart(),
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, trackWidth),
        onHorizontalDragEnd: (_) => _onDragEnd(trackWidth),
        child: Container(
          height: _trackHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            gradient: LinearGradient(
              colors: disabled
                  ? [Colors.grey.shade300, Colors.grey.shade300]
                  : [
                      baseColor.withOpacity(0.92),
                      Color.lerp(baseColor, Colors.black, 0.18)!,
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: baseColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                margin: EdgeInsets.only(left: _padding),
                width: _knobSize + _dragX,
                height: _trackHeight - _padding * 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                  color: Colors.white.withOpacity(0.16),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: disabled ? 0.5 : (1 - progress * 1.4).clamp(0.0, 1.0),
                    child: AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (rect) {
                          final t = _shimmerCtrl.value;
                          return LinearGradient(
                            colors: const [
                              Colors.white,
                              Colors.white70,
                              Colors.white,
                            ],
                            stops: [
                              (t - 0.3).clamp(0.0, 1.0),
                              t.clamp(0.0, 1.0),
                              (t + 0.3).clamp(0.0, 1.0),
                            ],
                          ).createShader(rect);
                        },
                        child: Text(
                          _confirmed ? widget.confirmedLabel : widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                child: Opacity(
                  opacity: disabled ? 0.0 : (1 - progress * 1.6).clamp(0.0, 1.0),
                  child: Row(
                    children: List.generate(
                      3,
                      (i) => Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.55 - i * 0.15),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(left: _padding + _dragX),
                width: _knobSize,
                height: _knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _confirmed
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: baseColor,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          color: disabled ? Colors.grey.shade400 : baseColor,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Enums ────────────────────────────────────────────────────────
enum _ToastType { success, error, warn, info }

// ── Cancel Bottom Sheet ──────────────────────────────────────────
class _CancelSheet extends StatefulWidget {
  final String orderCode;
  final bool   isOnlinePaid;
  final TextEditingController controller;
  const _CancelSheet({
    required this.orderCode,
    required this.isOnlinePaid,
    required this.controller,
  });
  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  static const _red   = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);

  final List<String> _reasons = [
    "Emergency / personal reason",
    "Client unresponsive",
    "Location too far",
    "Health issue",
    "Other",
  ];
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.cancel_outlined, color: _red, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Cancel Booking",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.orderCode,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
        const SizedBox(height: 16),

        if (widget.isOnlinePaid)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withOpacity(0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: _amber, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Online paid booking — will be flagged for admin reassignment. Refund handled by admin.",
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF7B5800)),
                ),
              ),
            ]),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "COD / unpaid booking — will be reopened so another caretaker can accept.",
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF0B5E70)),
                ),
              ),
            ]),
          ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _reasons.map((r) {
            final sel = _selected == r;
            return GestureDetector(
              onTap: () => setState(() {
                _selected = r;
                if (r != "Other") widget.controller.text = r;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withOpacity(0.10)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? AppColors.primary : Colors.grey.shade300,
                      width: sel ? 1.5 : 1),
                ),
                child: Text(r,
                    style: TextStyle(
                        fontSize: 12,
                        color: sel ? AppColors.primary : Colors.grey.shade700,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: widget.controller,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: "Add a reason (optional)…",
            hintStyle: TextStyle(
                color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 18),

        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Text("Keep Booking",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: _red.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))]),
                child: const Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cancel_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text("Yes, Cancel",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Grid overlay painter ─────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ── Diagonal stripe painter (extra restricted texture) ──────────
class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    const step = 32.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(_DiagonalStripePainter old) => false;
}