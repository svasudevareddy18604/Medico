import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
/// Zomato/Swiggy-style presentation — self-contained, polls the order
/// detail endpoint on its own so it can be pushed/popped independently
/// of OrderDetailsScreen.
class CaretakerLiveTrackingScreen extends StatefulWidget {
  final int orderId;
  const CaretakerLiveTrackingScreen({super.key, required this.orderId});

  @override
  State<CaretakerLiveTrackingScreen> createState() =>
      _CaretakerLiveTrackingScreenState();
}

class _CaretakerLiveTrackingScreenState
    extends State<CaretakerLiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  Map _order = {};
  bool _loading = true;
  bool _refreshing = false;
  Timer? _timer;
  final _mapCtrl = MapController();
  bool _mapReady = false;
  List<LatLng> _routePoints = [];
  double _heading = 0; // bike rotation, derived from route bearing

  // ✅ NEW — throttles the OSRM route/polyline fetch so it doesn't hit the
  // public router server every 3s (risk of silent rate-limiting). The
  // caretaker marker itself still moves on EVERY poll — this only slows
  // down how often the route line + heading are recomputed.
  int _pollCount = 0;
  static const int _routeEveryNPolls = 5; // ~15s at a 3s poll interval

  late AnimationController _pulseCtrl;

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
    final approval = (_order["caregiver_approval_status"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    final docs = _order["caregiver_documents_uploaded"];
    final docsUploaded = docs is bool ? docs : docs?.toString() == "1";
    return approval == "approved" && docsUploaded == true;
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
    return m < 1000
        ? "${m.round()} m away"
        : "${(m / 1000).toStringAsFixed(1)} km away";
  }

  int get _etaMins {
    final mins = _meters <= 0 ? 0 : ((_meters / 1000 / 25) * 60).ceil();
    return mins;
  }

  String get _etaLabel {
    final mins = _etaMins;
    if (mins <= 0) return "Arriving soon";
    return "Arriving in $mins min${mins == 1 ? '' : 's'}";
  }

  String get _statusHeadline => switch (_status) {
        "ON_THE_WAY" => "Caretaker is on the way",
        "ACCEPTED"   => "Caretaker is preparing to leave",
        _            => "Tracking your booking",
      };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _refresh();
    _timer = Timer.periodic(
        const Duration(seconds: 3), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    if (silent && mounted) setState(() => _refreshing = true);
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
          debugPrint(
              "TRACKING POLL → caretaker=(${_cLat ?? '-'}, ${_cLng ?? '-'})  status=$_status");

          if (_ready) {
            _pollCount++;
            // Only refetch the route line every ~15s, not every 3s — the
            // marker position above already updated regardless of this.
            if (_pollCount % _routeEveryNPolls == 0 || _routePoints.isEmpty) {
              await _loadRoute();
            }
            if (!_mapReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapCtrl.move(LatLng(_cLat!, _cLng!), 15);
                _mapReady = true;
              });
            }
          }
        }
      } else {
        debugPrint("TRACKING FETCH BAD STATUS: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("TRACKING FETCH ERROR: $e");
    }
    if (!silent && mounted) setState(() => _loading = false);
    if (silent && mounted) setState(() => _refreshing = false);
  }

  Future<void> _loadRoute() async {
    try {
      final url = "https://router.project-osrm.org/route/v1/driving/"
          "${_cLng!.toStringAsFixed(6)},${_cLat!.toStringAsFixed(6)};"
          "${_uLng!.toStringAsFixed(6)},${_uLat!.toStringAsFixed(6)}"
          "?overview=full&geometries=geojson";
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint("OSRM ROUTE BAD STATUS: ${res.statusCode}");
        return;
      }
      final data = jsonDecode(res.body);
      final coords = data["routes"][0]["geometry"]["coordinates"] as List;
      final pts = coords
          .map((e) =>
              LatLng((e[1] as num).toDouble(), (e[0] as num).toDouble()))
          .toList();
      if (pts.length >= 2) {
        _heading = _bearing(pts[0], pts[1]);
      }
      if (mounted) setState(() => _routePoints = pts);
    } catch (e) {
      debugPrint("ROUTE ERROR: $e");
    }
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad;
    final lat2 = b.latitudeInRad;
    final dLon = (b.longitude - a.longitude) * (pi / 180);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360;
  }

  void _recenter() {
    if (!_ready) return;
    final bounds =
        LatLngBounds.fromPoints([LatLng(_cLat!, _cLng!), LatLng(_uLat!, _uLng!)]);
    _mapCtrl.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(90)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F8),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_ready
              ? _unavailableView()
              : Column(children: [
                  _statusHeader(),
                  Expanded(
                    child: Stack(children: [
                      _map(),
                      _mapControls(),
                    ]),
                  ),
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
              child: Icon(Icons.location_off_rounded,
                  size: 40, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text("Live location unavailable",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
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
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Go Back",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ]),
        ),
      );

  // ── Top status header — Zomato/Swiggy style ─────────────────────────
  Widget _statusHeader() => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 14,
          left: 18,
          right: 18,
          bottom: 22,
        ),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(children: [
          Row(children: [
            _headerIconBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
            Expanded(
              child: Column(children: [
                Text(_carerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1)),
              ]),
            ),
            if (_carerPhone.isNotEmpty)
              _headerIconBtn(
                  Icons.call_rounded, () => launchUrl(Uri.parse("tel:$_carerPhone")))
            else
              const SizedBox(width: 40),
          ]),
          const SizedBox(height: 14),
          Text(
            _statusHeadline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_etaLabel,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
                ),
              ),
              Text(_distLabel,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _refresh(silent: true),
                child: RotationTransition(
                  turns: _refreshing
                      ? const AlwaysStoppedAnimation(0)
                      : const AlwaysStoppedAnimation(0),
                  child: Icon(Icons.refresh_rounded,
                      color: Colors.white.withOpacity(0.9), size: 16),
                ),
              ),
            ]),
          ),
        ]),
      );

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
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
          // Soft coverage circle around the destination — Zomato-style radius.
          CircleLayer(circles: [
            CircleMarker(
              point: LatLng(_uLat!, _uLng!),
              radius: 90,
              useRadiusInMeter: true,
              color: AppColors.primary.withOpacity(0.10),
              borderColor: AppColors.primary.withOpacity(0.25),
              borderStrokeWidth: 1.4,
            ),
          ]),
          PolylineLayer(polylines: [
            Polyline(
              points: _routePoints.isNotEmpty
                  ? _routePoints
                  : [LatLng(_cLat!, _cLng!), LatLng(_uLat!, _uLng!)],
              strokeWidth: 6,
              color: AppColors.primary,
              borderStrokeWidth: 2.5,
              borderColor: Colors.white.withOpacity(0.85),
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: LatLng(_uLat!, _uLng!),
              width: 46,
              height: 46,
              child: _homeMarker(),
            ),
            Marker(
              point: LatLng(_cLat!, _cLng!),
              width: 56,
              height: 56,
              child: _bikeMarker(),
            ),
          ]),
        ],
      );

  // ── Bike marker — realistic scooter icon w/ heading + pulse ─────────
  Widget _bikeMarker() => AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          final t = _pulseCtrl.value;
          return SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Expanding pulse ring
                Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
                  child: Container(
                    width: 20 + (36 * t),
                    height: 20 + (36 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE23744), // Zomato-red pulse
                    ),
                  ),
                ),
                // Shadow ellipse on the ground
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 22,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Rotated scooter body
                Transform.rotate(
                  angle: _heading * (pi / 180),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE23744),
                      border: Border.all(color: Colors.white, width: 2.6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE23744).withOpacity(0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.two_wheeler_rounded,
                        color: Colors.white, size: 21),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _homeMarker() => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1A2E),
          border: Border.all(color: Colors.white, width: 2.6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
      );

  // ── Floating map controls (recenter) ─────────────────────────────
  Widget _mapControls() => Positioned(
        right: 14,
        bottom: 14,
        child: Column(children: [
          _circleBtn(Icons.center_focus_strong_rounded, _recenter),
        ]),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _surface,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)],
          ),
          child: Icon(icon, color: _text, size: 20),
        ),
      );

  // ── Bottom floating caretaker card — clean delivery-app style ─────
  Widget _bottomCard() => Container(
        padding: EdgeInsets.fromLTRB(
            18, 16, 18, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, -6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.glowShadow,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(_carerName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
                ),
                if (_isVerifiedCarer) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(size: 16),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80)),
                ),
                const SizedBox(width: 6),
                Text(
                  _status == "ON_THE_WAY"
                      ? "On the way to you"
                      : "Assigned to your booking",
                  style: TextStyle(color: _subText, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ]),
            ]),
          ),
          if (_carerPhone.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse("tel:$_carerPhone")),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.glowShadow,
                ),
                child: const Icon(Icons.call_rounded, size: 22, color: Colors.white),
              ),
            ),
        ]),
      );
}