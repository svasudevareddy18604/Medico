import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:medico/utils/app_colors.dart';

import '../../config/api.dart';
import '../care_taker/care_taker_home.dart';

class AddLocationScreen extends StatefulWidget {
  final int userId;
  final String category;
  final VoidCallback onLocationAdded;

  const AddLocationScreen({
    super.key,
    required this.userId,
    required this.category,
    required this.onLocationAdded,
  });

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {

  bool loading = false;

  final addressController = TextEditingController();
  final areaController = TextEditingController();
  final landmarkController = TextEditingController();
  final pincodeController = TextEditingController();

  final mapController = MapController();

  // ✅ Default center (same fallback point used on care seeker screen)
  LatLng selectedLocation = const LatLng(13.0827, 80.2707);

  double? latitude;
  double? longitude;

  /* ================= HEADER ================= */

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Set Your Location",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ================= PERMISSION ================= */

  Future<bool> handleLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      showMsg("Enable location services");
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showMsg("Permission denied");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      showMsg("Open settings to allow permission");
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  /* ================= DETECT ================= */

  Future<void> detectLocation() async {
    setState(() => loading = true);

    bool ok = await handleLocationPermission();
    if (!ok) {
      setState(() => loading = false);
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition();
      latitude = pos.latitude;
      longitude = pos.longitude;

      // ✅ Move map + marker to the detected point
      selectedLocation = LatLng(latitude!, longitude!);
      mapController.move(selectedLocation, 17);

      await _fillAddressFromLatLng(selectedLocation);
    } catch (e) {
      showMsg("Location error");
    }

    setState(() => loading = false);
  }

  /* ================= REVERSE GEOCODE (shared by tap + detect) ================= */

  Future<void> _fillAddressFromLatLng(LatLng point) async {
    try {
      List<Placemark> p =
          await placemarkFromCoordinates(point.latitude, point.longitude);

      final place = p.first;

      setState(() {
        addressController.text =
            "${place.street ?? ""}, ${place.subLocality ?? ""}";
        areaController.text = place.locality ?? "";
        landmarkController.text = place.name ?? "";
        pincodeController.text = place.postalCode ?? "";
        latitude = point.latitude;
        longitude = point.longitude;
      });
    } catch (_) {
      showMsg("Could not fetch address for this point");
    }
  }

  /* ================= MAP TAP ================= */

  Future<void> _onMapTap(LatLng point) async {
    setState(() => selectedLocation = point);
    await _fillAddressFromLatLng(point);
  }

  /* ================= SAVE ================= */

  Future<void> saveLocation() async {

    // 🔥 STRICT RULE
    if (latitude == null || longitude == null) {
      showMsg("⚠️ Auto-detect or tap the map to set your location");
      return;
    }

    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse(Api.caretakerLocation),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "address_line": addressController.text,
          "area": areaController.text,
          "landmark": landmarkController.text,
          "pincode": pincodeController.text,
          "latitude": latitude,
          "longitude": longitude
        }),
      );

      setState(() => loading = false);

      if (res.statusCode == 200) {
        widget.onLocationAdded();

        if (!mounted) return;

        // If Home already exists in the stack (opened from Home to UPDATE
        // address), just pop back so it refreshes in place.
        // If there's nothing to pop to (first-time onboarding flow, no
        // Home pushed yet), fall back to pushReplacement.
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CareTakerHome(
                userId: widget.userId,
                category: widget.category,
              ),
            ),
          );
        }
      } else {
        showMsg("Save failed");
      }

    } catch (e) {
      setState(() => loading = false);
      showMsg("Server error");
    }
  }

  /* ================= UI ================= */

  Widget inputField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /* ================= BUILD ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      body: Column(
        children: [

          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [

                  // 🔥 OPEN STREET MAP
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 240,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedLocation,
                              initialZoom: 15,
                              onTap: (_, latlng) => _onMapTap(latlng),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                userAgentPackageName: 'com.yourapp.care',
                              ),
                              MarkerLayer(markers: [
                                Marker(
                                  point: selectedLocation,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                ),
                              ]),
                            ],
                          ),

                          // Small helper chip so it's clear the map is tappable
                          Positioned(
                            left: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Tap map to set location",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔥 AUTO DETECT CARD
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [

                        const Text(
                          "Auto Detect Required",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        ElevatedButton.icon(
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Icon(Icons.gps_fixed),
                          label: Text(
                              loading ? "Detecting..." : "Auto Detect Location"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 50),
                          ),
                          onPressed: loading ? null : detectLocation,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔥 FORM
                  inputField("Address", addressController),
                  inputField("Area", areaController),
                  inputField("Landmark", landmarkController),
                  inputField("Pincode", pincodeController),

                  const SizedBox(height: 30),

                  // 🔥 SAVE BUTTON
                  loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: saveLocation,
                            child: const Text("Save Location"),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}