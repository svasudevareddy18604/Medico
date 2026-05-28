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

  // ── DISTINCT COLORS (no two the same) ────────────────────────────────────
  // Nurse        → vivid rose/pink
  // Physiotherapy→ vivid cobalt blue
  // Non-Medical  → vivid orange (was teal — same as "You")
  // You          → AppColors.primary (teal/green — kept as-is)
  static const Color _nurseColor      = Color(0xFFE91E63); // rose-pink
  static const Color _physioColor     = Color(0xFF1565C0); // deep cobalt (darker than "You")
  static const Color _nonMedicalColor = Color(0xFFFF6F00); // vivid amber-orange
  // "You" marker uses AppColors.primary so it's always distinct

  Color _typeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains("nurse"))   return _nurseColor;
    if (t.contains("physio"))  return _physioColor;
    if (t.contains("support") || t.contains("non")) return _nonMedicalColor;
    return const Color(0xFF6D28D9); // purple fallback for any other type
  }

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains("nurse"))   return Icons.local_hospital_rounded;
    if (t.contains("physio"))  return Icons.fitness_center_rounded;
    if (t.contains("support") || t.contains("non")) return Icons.favorite_rounded;
    return Icons.medical_services_rounded;
  }

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
      final res =
          await http.get(Uri.parse(Api.nearbyCaretakers(widget.userId)));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);

        final available = data.where((c) {
          final isAvail = c["is_available"];
          return isAvail == 1 || isAvail == true;
        }).toList();

        if (available.isNotEmpty) {
          userLat = double.parse(available[0]["user_latitude"].toString());
          userLng = double.parse(available[0]["user_longitude"].toString());
        } else if (data.isNotEmpty) {
          userLat = double.parse(data[0]["user_latitude"].toString());
          userLng = double.parse(data[0]["user_longitude"].toString());
        }

        setState(() {
          caretakers = available;
          isLoading  = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  // ── MAP MARKERS ───────────────────────────────────────────────────────────
  List<Marker> _buildMarkers() => [
        // "You" marker
        Marker(
          point: LatLng(userLat, userLng),
          width: 72,
          height: 76,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.45),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(Icons.my_location_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Text(
                "You",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ]),
        ),

        // Caretaker markers
        ...caretakers.map((c) {
          final lat   = double.parse(c["latitude"].toString());
          final lng   = double.parse(c["longitude"].toString());
          final type  = c["caregiver_type"] ?? "";
          final color = _typeColor(type);
          final icon  = _typeIcon(type);
          final name  = "${c["first_name"] ?? ""}".trim();

          return Marker(
            point: LatLng(lat, lng),
            width: 68,
            height: 72,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(height: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  name.length > 8 ? "${name.substring(0, 7)}…" : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          );
        }),
      ];

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
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
              width: 38,
              height: 38,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Nearby Caretakers",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Available caregivers in your area",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 20),
          ),
        ]),
      );

  // ── LEGEND ────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    final bg        = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    // All four clearly different colors
    final items = [
      ("Nurse",        _nurseColor),
      ("Physio",       _physioColor),
      ("Non-Medical",  _nonMedicalColor),
      ("You",          AppColors.primary),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }

  // ── CARETAKER CARD ────────────────────────────────────────────────────────
  Widget _buildCaretakerCard(dynamic c) {
    final bg        = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final type  = c["caregiver_type"] ?? "Caretaker";
    final color = _typeColor(type);
    final icon  = _typeIcon(type);
    final dist  = (c["distance"] as num).toStringAsFixed(1);
    final name  = "${c["first_name"] ?? ""} ${c["last_name"] ?? ""}".trim();

    return Container(
      width: 170,
      // NO fixed height — let content size itself naturally (fixes overflow)
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // shrink-wrap — no overflow
        children: [
          // Avatar + name row
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name.isEmpty ? "Caretaker" : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.25,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 8),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Distance row
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
  }

  // ── CARETAKER LIST ────────────────────────────────────────────────────────
  Widget _buildCaretakerList() => SizedBox(
        // IntrinsicHeight lets each card size by its own content
        // We wrap in a horizontal scroll inside a constrained box
        height: 148, // tall enough for two-line names + badge + distance
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: caretakers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _buildCaretakerCard(caretakers[i]),
        ),
      );

  // ── COUNT BADGE ───────────────────────────────────────────────────────────
  Widget _buildCountBadge() {
    final bg        = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "${caretakers.length} caretaker${caretakers.length != 1 ? 's' : ''} available nearby",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const Spacer(),
        Text(
          "Swipe →",
          style: TextStyle(fontSize: 11, color: subColor),
        ),
      ]),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg       = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Loading
    if (isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                "Finding caretakers near you…",
                style: TextStyle(color: subColor, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (caretakers.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "No Caretakers Available",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "No available caregivers found in your area right now.\nPlease try again later.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: loadCaretakers,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        "Refresh",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      );
    }

    // Main screen
    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _buildHeader(),
        _buildLegend(),
        _buildCountBadge(),
        const SizedBox(height: 10),
        _buildCaretakerList(),
        const SizedBox(height: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(children: [
              FlutterMap(
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
              // Map attribution badge (bottom-right)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "© OpenStreetMap",
                    style: TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}