import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
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

      List<Placemark> p =
          await placemarkFromCoordinates(latitude!, longitude!);

      final place = p.first;

      addressController.text =
          "${place.street ?? ""}, ${place.subLocality ?? ""}";
      areaController.text = place.locality ?? "";
      landmarkController.text = place.name ?? "";
      pincodeController.text = place.postalCode ?? "";

    } catch (e) {
      showMsg("Location error");
    }

    setState(() => loading = false);
  }

  /* ================= SAVE ================= */

  Future<void> saveLocation() async {

    // 🔥 STRICT RULE
    if (latitude == null || longitude == null) {
      showMsg("⚠️ Auto-detect location is required");
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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CareTakerHome(
              userId: widget.userId,
              category: widget.category,
            ),
          ),
        );
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
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text("Auto Detect Location"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
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