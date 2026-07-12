import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import '../../widgets/verified_badge.dart';

/// Full-screen live tracking view for a caretaker's location.
/// Self-contained — polls the order detail endpoint on its own,
/// so it can be pushed/popped independently of OrderDetailsScreen.
class CaretakerLiveTrackingScreen extends StatefulWidget {
  final int orderId;
  const CaretakerLiveTrackingScreen({super.key, required this.orderId});

  @override
  State<CaretakerLiveTrackingScreen> createState() =>
      _CaretakerLiveTrackingScreenState();
}

class _CaretakerLiveTrackingScreenState
    extends State<CaretakerLiveTrackingScreen> {
  Map _order = {};
  bool _loading = true;
  Timer? _timer;
  final _mapCtrl = MapController();
  bool _mapReady = false;
  List<LatLng> _routePoints = [];

  bool get _dark => themeNotifier.value == ThemeMode.dark;
  Color get _surface => _dark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1A2E);
  Color get _subText => _dark ? Colors.white60 : AppColors.muted;

  double? get _cLat =>
      double.tryParse(_order["caretaker_latitude"]?.toString() ?? "");
  double? get _cLng =>
      double.tryParse(_order["caretaker_longitude"]?.toString() ?? "");
  double? get _uLat => double.tryParse(_order["latitude"]?.toString() ?? "");
  double? get _uLng => double.tryParse(_order["longitude"]?.toString() ?? "");

  bool get _ready =>
      _cLat != null && _cLng != null && _uLat != null && _uLng != null;

  bool get _isVerifiedCarer {
    final v = _order["caregiver_verified"] ??
        _order["caregiver_is_professional"] ??
        _order["is_verified"] ??
        _order["caretaker_verified"];
    if (v == null) return false;
    if (v is bool) return v;
    return v.toString().trim().toLowerCase() == "true" || v.toString() == "1";
  }

  String get _carerName =>
      _order["caregiver_name"]?.toString().trim().isNotEmpty == true
          ? _order["caregiver_name"].toString()
          : "Your Caretaker";
  String get _carerPhone => (_order["caregiver_phone"] ?? "").toString();
  String get _status => (_order["status"] ?? "").toString().toUpperCase();

  double get _meters {
    if (!_ready) return 0;
    return const Distance()
        .as(LengthUnit.Meter, LatLng(_cLat!, _cLng!), LatLng(_uLat!, _uLng!));
  }

  String get _distLabel {
    final m = _meters;
    return m < 1000 ? "${m.round()} m away" : "${(m / 1000).toStringAsFixed(1)} km away";
  }

  String get _etaLabel {
    final mins = _meters <= 0 ? 0 : ((_meters / 1000 / 25) * 60).ceil();
    if (mins <= 0) return "Arriving soon";
    return "~$mins min${mins == 1 ? '' : 's'}";
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/orders/detail/${widget.orderId}"))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["order"] != null && mounted) {
          setState(() {
            _order = data["order"];
            _loading = false;
          });
          if (_ready) {
            await _loadRoute();
            if (!_mapReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapCtrl.move(LatLng(_cLat!, _cLng!), 15);
                _mapReady = true;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("TRACKING FETCH ERROR: $e");
    }
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _loadRoute() async {
    try {
      final url = "https://router.project-osrm.org/route/v1/driving/"
          "${_cLng!.toStringAsFixed(6)},${_cLat!.toStringAsFixed(6)};"
          "${_uLng!.toStringAsFixed(6)},${_uLat!.toStringAsFixed(6)}"
          "?overview=full&geometries=geojson";
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final coords = data["routes"][0]["geometry"]["coordinates"] as List;
      final pts = coords
          .map((e) => LatLng((e[1] as num).toDouble(), (e[0] as num).toDouble()))
          .toList();
      if (mounted) setState(() => _routePoints = pts);
    } catch (e) {
      debugPrint("ROUTE ERROR: $e");
    }
  }

  void _recenter() {
    if (!_ready) return;
    final bounds = LatLngBounds.fromPoints(
        [LatLng(_cLat!, _cLng!), LatLng(_uLat!, _uLng!)]);
    _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(90)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F8),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_ready
              ? _unavailableView()
              : Stack(children: [
                  _map(),
                  _topBar(),
                  _bottomCard(),
                ]),
    );
  }

  // ── Unavailable state ──────────────────────────────────────────────
  Widget _unavailableView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_rounded, size: 40, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text("Live location unavailable",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
            const SizedBox(height: 8),
            Text(
              "Your caretaker's location appears here automatically once they're on the way.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _subText, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
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
                  child: const Text("Go Back",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ]),
        ),
      );

  // ── Map ─────────────────────────────────────────────────────────────
  Widget _map() => FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: LatLng(_cLat!, _cLng!),
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
              points: _routePoints.isNotEmpty
                  ? _routePoints
                  : [LatLng(_cLat!, _cLng!), LatLng(_uLat!, _uLng!)],
              strokeWidth: 7,
              color: AppColors.primary,
              borderStrokeWidth: 2.5,
              borderColor: Colors.white.withOpacity(0.7),
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: LatLng(_cLat!, _cLng!),
              width: 84,
              height: 84,
              child: _carerMarker(),
            ),
            Marker(
              point: LatLng(_uLat!, _uLng!),
              width: 64,
              height: 64,
              child: _homeMarker(),
            ),
          ]),
        ],
      );

  Widget _carerMarker() => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: AppColors.glowShadow,
          ),
          child: const Icon(Icons.electric_bike_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_carerName.split(" ").first,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
            if (_isVerifiedCarer) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 10),
            ],
          ]),
        ),
      ]);

  Widget _homeMarker() => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(color: AppColors.danger.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.35), blurRadius: 6)],
          ),
          child: const Text("You",
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ]);

  // ── Top bar (floating over map) ───────────────────────────────────
  Widget _topBar() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            bottom: 30,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.45), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(children: [
            _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "$_etaLabel  ·  $_distLabel",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            _circleBtn(Icons.center_focus_strong_rounded, _recenter),
            const SizedBox(width: 10),
            _circleBtn(Icons.refresh_rounded, () => _refresh()),
          ]),
        ),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
          ),
          child: Icon(icon, color: const Color(0xFF1A1A2E), size: 20),
        ),
      );

  // ── Bottom floating caretaker card ────────────────────────────────
  Widget _bottomCard() => Positioned(
        left: 16,
        right: 16,
        bottom: 22,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 10))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.glowShadow,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(_carerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
                    ),
                    if (_isVerifiedCarer) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(size: 16),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _status == "ON_THE_WAY" ? "On the way to you" : "Assigned to your booking",
                    style: TextStyle(color: _subText, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
              if (_carerPhone.isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse("tel:$_carerPhone")),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.glowShadow,
                    ),
                    child: const Icon(Icons.call_rounded, size: 21, color: Colors.white),
                  ),
                ),
            ]),
          ]),
        ),
      );
}