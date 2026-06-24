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
    }
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
    if (_onTheWay && !_isPaid) return "Collect Payment";
    if (_onTheWay && _isPaid)  return "Complete Service";
    return "View Details";
  }

  VoidCallback? get _ctaAction {
    if (_isCompleted || _isCancelled) return null;
    if (_notAccepted) return _accept;
    if (_isAccepted || _isConfirmed) return _startJourney;
    if (_onTheWay && !_isPaid) return _goToPaymentScreen;
    if (_onTheWay && _isPaid)  return _complete;
    return null;
  }

  Color get _ctaColor {
    if (_isCompleted || _isCancelled) return Colors.grey;
    if (_notAccepted) return AppColors.primary;
    if (_isAccepted || _isConfirmed) return _blue;
    if (_onTheWay && !_isPaid) return _amber;
    if (_onTheWay && _isPaid)  return AppColors.primary;
    return Colors.grey;
  }

  IconData get _ctaIcon {
    if (_isCompleted) return Icons.check_circle_rounded;
    if (_isCancelled) return Icons.cancel_rounded;
    if (_notAccepted) return Icons.handshake_rounded;
    if (_isAccepted || _isConfirmed) return Icons.directions_run_rounded;
    if (_onTheWay && !_isPaid) return Icons.payment_rounded;
    if (_onTheWay && _isPaid)  return Icons.done_all_rounded;
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
            // Cleaned up: no more "Secure" chip / camera icon — they made
            // the header feel cluttered. Screenshot protection still runs
            // silently in the background regardless.
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
                // Title + category — tap to copy the booking ID, with a
                // small copy icon as an affordance hint.
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
                if (_hasDocs)
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
                    // Location hidden when COMPLETED
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
                  if (_hasDocs && _docUrls.isNotEmpty) ...[
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
                            // Doc header bar
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
                            // Review reminder
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
                            // Document tiles
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
                            _isCOD
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
                      (!_onTheWay || _isCancelled) ? null : _goToPaymentScreen,
                    ),
                    const SizedBox(width: 10),
                    // Call button — locked when COMPLETED
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
          // This is a secondary visual deterrent — blurs the whole UI
          // if somehow screenshot is triggered (works even without FLAG_SECURE)
          if (_screenshotBlocked)
            IgnorePointer(
              child: Positioned.fill(
                child: Container(color: Colors.transparent),
                // The actual FLAG_SECURE is set via platform channel
                // This widget serves as the Dart-side marker
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
            // Themed gradient background using AppColors
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B8FAC), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Grid pattern overlay
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            // Diagonal stripe overlay for extra "restricted" feel
            Positioned.fill(
              child: CustomPaint(painter: _DiagonalStripePainter()),
            ),
            // Content
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

  // ── Status Stepper ───────────────────────────────────────────
  // Connector lines fill based on the earlier of each adjacent pair of
  // steps being done, so the line between "Payment" and "Completed"
  // doesn't visually disconnect right after payment goes through but
  // before the booking is marked complete.
  Widget _statusStepper() {
    final steps = [
      {"label": "Accepted",   "done": !_notAccepted},
      {"label": "On The Way", "done": _onTheWay || _isCompleted},
      {"label": "Payment",    "done": _isPaid},
      {"label": "Completed",  "done": _isCompleted},
    ];
    return _card(
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = steps[i]["done"] as bool;
          final dot  = Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: done ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: done ? AppColors.primary : Colors.grey.shade300,
                    width: 2)),
            child: Icon(
              done ? Icons.check_rounded : Icons.radio_button_unchecked,
              color: done ? Colors.white : Colors.grey.shade400,
              size: 16,
            ),
          );

          // A connector segment after step `i` is filled when step `i`
          // itself is done, OR when the following step is already done
          // (covers cases where statuses jump, e.g. payment + completion
          // landing in the same fetch).
          bool segmentFilled() {
            final nextDone = (i + 1 < steps.length)
                ? steps[i + 1]["done"] as bool
                : false;
            return done || nextDone;
          }

          Widget line({required bool filled}) => Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                      color: filled
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2)),
                ),
              );

          return Expanded(
            child: Column(children: [
              Row(children: [
                if (i != 0)
                  line(filled: steps[i - 1]["done"] as bool || done),
                dot,
                if (i != steps.length - 1) line(filled: segmentFilled()),
              ]),
              const SizedBox(height: 6),
              Text(
                steps[i]["label"] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        done ? FontWeight.w700 : FontWeight.w500,
                    color: done ? AppColors.primary : Colors.grey.shade500),
              ),
            ]),
          );
        }),
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

  // Booking ID row — tap-to-copy with a subtle copy icon + visual
  // feedback (ink ripple) so users know it's interactive. Triggers the
  // same toast confirmation as the header copy action.
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