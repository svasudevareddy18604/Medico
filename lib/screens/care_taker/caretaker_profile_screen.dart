import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
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
  bool loading = true;
  bool uploading = false;
  bool togglingAvailability = false;

  Map profile = {};
  File? selectedImage;

  late AnimationController _toggleAnim;

  bool get isAvailable => (profile["is_available"] ?? 0) == 1;
  bool get isLocked => (profile["availability_locked"] ?? 0) == 1;
  bool get isVerified => (profile["approval_status"]?.toString() ?? "pending") == "approved";

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
          if (isAvailable) {
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
    if (isLocked) {
      _showLockedSnackbar();
      _showLockedDialog();
      return;
    }

    if (togglingAvailability) return;

    final current = isAvailable;
    final newValue = current ? 0 : 1;

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

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true) {
          _showToast(
            newValue == 1 ? "You are now Available ✓" : "You are now Unavailable",
            newValue == 1,
          );
        } else {
          _revertToggle(current);
          _showToast("Failed to update availability", false);
        }
      } else if (res.statusCode == 403) {
        await loadProfile();
        if (mounted) {
          _showLockedSnackbar();
          _showLockedDialog();
        }
      } else {
        _revertToggle(current);
        _showToast("Failed to update availability", false);
      }
    } catch (e) {
      debugPrint("TOGGLE ERROR: $e");
      _revertToggle(current);
      _showToast("Network error", false);
    }

    if (mounted) setState(() => togglingAvailability = false);
  }

  void _revertToggle(bool current) {
    setState(() => profile["is_available"] = current ? 1 : 0);
    if (current) {
      _toggleAnim.forward();
    } else {
      _toggleAnim.reverse();
    }
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
        setState(() {
          uploading = false;
          selectedImage = null;
        });
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
      duration: const Duration(seconds: 2),
    ));
  }

  void _showVerifiedToast() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1DA1F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: Row(children: [
          const _BlueTick(size: 18),
          const SizedBox(width: 10),
          const Text(
            "Verified by Medico",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  void _showLockedSnackbar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Account Locked by Medico Support Team",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                SizedBox(height: 2),
                Text(
                  "Contact Medico Support team to reactivate.",
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Icon(Icons.lock_rounded, color: Colors.orange.shade700, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                "Account Locked",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 12),
              Text(
                "Your availability has been locked by the medico support team due to inactivity of your account.\n\nYou cannot go online on your own. Please contact the Medico support team through chat to reactivate your account.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.6),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent_rounded, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "Contact Us to reactivate",
                      style: TextStyle(fontSize: 12.5, color: Colors.orange.shade800, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Understood",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(children: [
                    _profileImage(),
                    const SizedBox(height: 14),

                    // ── NAME + BLUE TICK ──
                    GestureDetector(
                      onTap: isVerified ? _showVerifiedToast : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              "${profile["first_name"] ?? ""} ${profile["last_name"] ?? ""}".trim(),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const _BlueTick(size: 20),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),
                    Text(profile["mobile"] ?? "",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 24),

                    // ── AVAILABILITY TOGGLE CARD ──
                    _availabilityCard(),

                    const SizedBox(height: 20),

                    // ── INFO TILES (Services removed) ──
                    _infoTile(Icons.medical_services_outlined, "Caregiver Type", profile["caregiver_type"] ?? ""),
                    _infoTile(Icons.workspace_premium_outlined, "Experience", profile["experience"] ?? ""),
                    _infoTile(Icons.schedule_rounded, "Availability", profile["availability"] ?? ""),
                  ]),
                ),
              ),
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("My Profile",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
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
                : (imagePath != null && imagePath.isNotEmpty ? NetworkImage(imagePath) : null),
            child: (selectedImage == null && (imagePath == null || imagePath.isEmpty))
                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
        ),
        if (uploading)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
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
    final Color activeColor = const Color(0xFF22C55E);
    final Color lockedColor = Colors.orange.shade700;
    final Color inactiveColor = Colors.grey.shade400;

    final Color iconColor = isLocked ? lockedColor : (isAvailable ? activeColor : inactiveColor);
    final Color iconBg = isLocked
        ? Colors.orange.shade50
        : (isAvailable ? activeColor.withOpacity(0.12) : Colors.grey.shade100);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLocked
              ? lockedColor.withOpacity(0.35)
              : (isAvailable ? activeColor.withOpacity(0.4) : Colors.grey.shade200),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isLocked
                ? lockedColor.withOpacity(0.12)
                : (isAvailable ? activeColor.withOpacity(0.12) : Colors.black.withOpacity(0.04)),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(
                isLocked
                    ? Icons.lock_rounded
                    : (isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded),
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLocked ? "Account Locked" : "Availability Status",
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      key: ValueKey("$isLocked-$isAvailable"),
                      isLocked
                          ? "Medico Support team has restricted your access"
                          : (isAvailable ? "Visible to clients · Accepting jobs" : "Hidden from clients"),
                      style: TextStyle(
                        fontSize: 12,
                        color: isLocked
                            ? lockedColor
                            : (isAvailable ? const Color(0xFF16A34A) : Colors.grey.shade500),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            togglingAvailability
                ? const SizedBox(
                    width: 44,
                    height: 26,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : isLocked
                    ? GestureDetector(
                        onTap: () {
                          _showLockedSnackbar();
                          _showLockedDialog();
                        },
                        child: Container(
                          width: 54,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.orange.shade200,
                          ),
                          child: Center(
                            child: Icon(Icons.lock_rounded, size: 16, color: Colors.orange.shade800),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _toggleAvailability,
                        child: AnimatedBuilder(
                          animation: _toggleAnim,
                          builder: (_, __) {
                            final t = _toggleAnim.value;
                            final trackColor = Color.lerp(Colors.grey.shade300, activeColor, t)!;
                            return Container(
                              width: 54,
                              height: 30,
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
                                  width: 24,
                                  height: 24,
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
          if (isLocked) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                _showLockedSnackbar();
                _showLockedDialog();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.support_agent_rounded, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Contact Us to reactivate your account.",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: Colors.orange.shade700),
                ]),
              ),
            ),
          ],
        ],
      ),
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.black87)),
        ),
        Text(
          value.isEmpty ? "—" : value,
          style: TextStyle(fontSize: 13.5, color: value.isEmpty ? Colors.grey.shade400 : Colors.black54),
        ),
      ]),
    );
  }
}

/* =========================================================
   INSTAGRAM-STYLE BLUE VERIFIED TICK BADGE
========================================================= */

class _BlueTick extends StatelessWidget {
  final double size;
  const _BlueTick({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BlueTickPainter(),
      ),
    );
  }
}

class _BlueTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final path = Path();
    const points = 8;
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi * 2) / (points * 2) - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.82;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final badgePaint = Paint()..color = const Color(0xFF1DA1F2);
    canvas.drawPath(path, badgePaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.32);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}