import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import '../../config/api.dart';

class NearbyCaretakersScreen extends StatefulWidget {
  final int userId;
  const NearbyCaretakersScreen({super.key, required this.userId});
  @override
  State<NearbyCaretakersScreen> createState() =>
    _NearbyCaretakersScreenState();
}

class _NearbyCaretakersScreenState extends State<NearbyCaretakersScreen> {
  List caretakers = [];
  bool isLoading = true;
  double userLat = 0.0, userLng = 0.0;

  bool get isDark => themeNotifier.value == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
    loadCaretakers();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<void> loadCaretakers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(Api.nearbyCaretakers(widget.userId)));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);

        // ✅ Extra safety filter: exclude unavailable caretakers on frontend too
        final available = data.where((c) {
          final isAvail = c["is_available"];
          return isAvail == 1 || isAvail == true;
        }).toList();

        if (available.isNotEmpty) {
          userLat = double.parse(available[0]["user_latitude"].toString());
          userLng = double.parse(available[0]["user_longitude"].toString());
        } else if (data.isNotEmpty) {
          // fallback: still grab user location even if no caretakers
          userLat = double.parse(data[0]["user_latitude"].toString());
          userLng = double.parse(data[0]["user_longitude"].toString());
        }

        setState(() {
          caretakers = available;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color _typeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains("nurse")) return const Color(0xFFE91E63);
    if (t.contains("physio")) return const Color(0xFF1E88E5);
    if (t.contains("support")) return const Color(0xFF00897B);
    return Colors.grey;
  }

  List<Marker> _buildMarkers() => [
        // ── User location marker ──
        Marker(
          point: LatLng(userLat, userLng),
          width: 72,
          height: 72,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 10,
                  )
                ],
              ),
              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "You",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        ),

        // ── Caretaker markers (only available ones) ──
        ...caretakers.map((c) {
          final lat = double.parse(c["latitude"].toString());
          final lng = double.parse(c["longitude"].toString());
          final color = _typeColor(c["caregiver_type"] ?? "");
          return Marker(
            point: LatLng(lat, lng),
            width: 56,
            height: 56,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              Icon(Icons.arrow_drop_down, color: color, size: 16),
            ]),
          );
        }),
      ];

  /* ─── HEADER ─────────────────────────────────────────────────────────────── */
  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "Nearby Caretakers",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 20),
          ),
        ]),
      );

  /* ─── LEGEND ─────────────────────────────────────────────────────────────── */
  Widget _buildLegend() {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final items = [
      ("Nurse", const Color(0xFFE91E63)),
      ("Physiotherapy", const Color(0xFF1E88E5)),
      ("Non-Medical", const Color(0xFF00897B)),
      ("You", AppColors.primary),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items
            .map((item) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ]))
            .toList(),
      ),
    );
  }

  /* ─── CARETAKER CARDS LIST ───────────────────────────────────────────────── */
  Widget _buildCaretakerList() {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 130,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: caretakers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = caretakers[i];
          final type = c["caregiver_type"] ?? "Caretaker";
          final color = _typeColor(type);
          final dist = (c["distance"] as num).toStringAsFixed(1);

          return Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.person, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${c["first_name"]} ${c["last_name"]}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 13, color: subColor),
                  const SizedBox(width: 3),
                  Text(
                    "$dist km away",
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ─── BUILD ──────────────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // ── Loading ──
    if (isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // ── Empty state (no available caretakers nearby) ──
    if (caretakers.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      size: 72,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No Caretakers Available",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No available caregivers found in your area.",
                    style: TextStyle(color: subColor, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: loadCaretakers,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      "Refresh",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    // ── Main screen ──
    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _buildHeader(),
        _buildLegend(),
        _buildCaretakerList(),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(userLat, userLng),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.medico",
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}