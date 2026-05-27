import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../config/api.dart';
import 'package:medico/utils/app_colors.dart';

class CareTakerProfileScreen extends StatefulWidget {
  final int userId;
  const CareTakerProfileScreen({super.key, required this.userId});

  @override
  State<CareTakerProfileScreen> createState() => _CareTakerProfileScreenState();
}

class _CareTakerProfileScreenState extends State<CareTakerProfileScreen>
    with SingleTickerProviderStateMixin {

  bool loading    = true;
  bool uploading  = false;
  bool togglingAvailability = false;

  Map profile = {};
  File? selectedImage;

  late AnimationController _toggleAnim;

  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    loadProfile();
  }

  @override
  void dispose() {
    _toggleAnim.dispose();
    super.dispose();
  }

  // ─── LOAD PROFILE ────────────────────────────────────────

  Future<void> loadProfile() async {
    try {
      final res = await http.get(
        Uri.parse("${Api.caretakerProfile}/${widget.userId}"),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data["success"] == true) {
          setState(() {
            profile = data;
            loading = false;
          });
          // sync animation to current availability
          if ((profile["is_available"] ?? 0) == 1) {
            _toggleAnim.forward();
          } else {
            _toggleAnim.reverse();
          }
        }
      }
    } catch (e) {
      debugPrint("LOAD ERROR: $e");
      setState(() => loading = false);
    }
  }

  // ─── TOGGLE AVAILABILITY ─────────────────────────────────

  Future<void> _toggleAvailability() async {
    if (togglingAvailability) return;

    final current    = (profile["is_available"] ?? 0) == 1;
    final newValue   = current ? 0 : 1;

    setState(() {
      togglingAvailability = true;
      profile["is_available"] = newValue; // optimistic
    });

    if (newValue == 1) {
      _toggleAnim.forward();
    } else {
      _toggleAnim.reverse();
    }

    try {
      final res = await http.put(
        Uri.parse("${Api.caretakerProfile}/availability/${widget.userId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_available": newValue}),
      );

      debugPrint("🔄 Toggle status: ${res.statusCode} | ${res.body}");

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        _showToast(
          newValue == 1 ? "You are now Available ✓" : "You are now Unavailable",
          newValue == 1,
        );
      } else {
        // Revert on failure
        setState(() => profile["is_available"] = current ? 1 : 0);
        if (current) _toggleAnim.forward(); else _toggleAnim.reverse();
        _showToast("Failed to update availability", false);
      }
    } catch (e) {
      debugPrint("TOGGLE ERROR: $e");
      setState(() => profile["is_available"] = current ? 1 : 0);
      if (current) _toggleAnim.forward(); else _toggleAnim.reverse();
      _showToast("Network error", false);
    }

    setState(() => togglingAvailability = false);
  }

  // ─── PICK & UPLOAD IMAGE ─────────────────────────────────

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => selectedImage = File(picked.path));
    uploadImage();
  }

  Future<void> uploadImage() async {
    setState(() => uploading = true);
    try {
      final req = http.MultipartRequest(
        "POST",
        Uri.parse(Api.uploadCaretakerProfile(widget.userId)),
      );
      req.files.add(await http.MultipartFile.fromPath("image", selectedImage!.path));
      final res = await http.Response.fromStream(await req.send());

      if (res.statusCode == 200) {
        await loadProfile();
        setState(() { uploading = false; selectedImage = null; });
        _showToast("Profile photo updated", true);
      } else {
        setState(() => uploading = false);
        _showToast("Upload failed", false);
      }
    } catch (e) {
      setState(() => uploading = false);
      _showToast("Error uploading", false);
    }
  }

  // ─── TOAST ───────────────────────────────────────────────

  void _showToast(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: success ? const Color(0xFF22C55E) : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── BUILD ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildHeader(),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(children: [
                  _profileImage(),
                  const SizedBox(height: 14),
                  Text(
                    "${profile["first_name"] ?? ""} ${profile["last_name"] ?? ""}".trim(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(profile["mobile"] ?? "",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 24),

                  // ── AVAILABILITY TOGGLE CARD ──
                  _availabilityCard(),

                  const SizedBox(height: 20),

                  // ── INFO TILES ──
                  _infoTile(Icons.medical_services_outlined, "Caregiver Type", profile["caregiver_type"] ?? ""),
                  _infoTile(Icons.workspace_premium_outlined, "Experience",     profile["experience"]     ?? ""),
                  _infoTile(Icons.schedule_rounded,           "Availability",   profile["availability"]   ?? ""),
                  _infoTile(Icons.design_services_outlined,   "Services",       profile["services"]       ?? ""),
                ]),
              )),
            ]),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(16, 52, 16, 26),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Text("My Profile",
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
    ]),
  );

  // ─── PROFILE IMAGE ───────────────────────────────────────

  Widget _profileImage() {
    String? imagePath = profile["profile_image"];
    if (imagePath != null && imagePath.isNotEmpty && !imagePath.startsWith("http")) {
      imagePath = "${Api.imageBase}/${imagePath.replaceAll("\\", "/")}";
    }

    return GestureDetector(
      onTap: pickImage,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradient),
          child: CircleAvatar(
            radius: 72,
            backgroundColor: Colors.white,
            backgroundImage: selectedImage != null
                ? FileImage(selectedImage!) as ImageProvider
                : (imagePath != null && imagePath.isNotEmpty
                    ? NetworkImage(imagePath) : null),
            child: (selectedImage == null && (imagePath == null || imagePath.isEmpty))
                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
        ),
        if (uploading)
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          )),
        Positioned(
          bottom: 4, right: 4,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)],
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
          ),
        ),
      ]),
    );
  }

  // ─── AVAILABILITY CARD ───────────────────────────────────

  Widget _availabilityCard() {
    final isAvailable = (profile["is_available"] ?? 0) == 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAvailable
              ? const Color(0xFF22C55E).withOpacity(0.4)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isAvailable
                ? const Color(0xFF22C55E).withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        // Icon badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: isAvailable
                ? const Color(0xFF22C55E).withOpacity(0.12)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isAvailable ? const Color(0xFF22C55E) : Colors.grey.shade400,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),

        // Text
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Availability Status",
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(isAvailable),
              isAvailable ? "Visible to clients · Accepting jobs" : "Hidden from clients",
              style: TextStyle(
                fontSize: 12,
                color: isAvailable ? const Color(0xFF16A34A) : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ])),

        const SizedBox(width: 12),

        // Toggle switch
        togglingAvailability
            ? const SizedBox(
                width: 44, height: 26,
                child: Center(child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              )
            : GestureDetector(
                onTap: _toggleAvailability,
                child: AnimatedBuilder(
                  animation: _toggleAnim,
                  builder: (_, __) {
                    final t = _toggleAnim.value;
                    final trackColor = Color.lerp(
                      Colors.grey.shade300,
                      const Color(0xFF22C55E),
                      t,
                    )!;
                    return Container(
                      width: 54, height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: isAvailable ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ]),
    );
  }

  // ─── INFO TILE ───────────────────────────────────────────

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.black87))),
        Text(
          value.isEmpty ? "—" : value,
          style: TextStyle(fontSize: 13.5, color: value.isEmpty ? Colors.grey.shade400 : Colors.black54),
        ),
      ]),
    );
  }
}