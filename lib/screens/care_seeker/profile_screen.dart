import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import '../../config/api.dart';
import 'careseeker_profile_report_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map user = {};
  bool loading = true, uploading = false;
  File? image;

  bool get isDark => themeNotifier.value == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
    loadProfile();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  Future<void> loadProfile() async {
    final res = await http.get(Uri.parse("${Api.baseUrl}/users/profile/${widget.userId}"));
    if (res.statusCode == 200) setState(() { user = jsonDecode(res.body); loading = false; });
  }

  Future<void> pickImage() async {
    if (!(await Permission.photos.request()).isGranted) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => uploading = true);
    try {
      var req = http.MultipartRequest("POST",
          Uri.parse("${Api.baseUrl}/users/upload-profile/${widget.userId}"));
      req.files.add(await http.MultipartFile.fromPath("image", picked.path));
      final res = await req.send();
      if (res.statusCode == 200) { setState(() => image = null); await loadProfile(); }
    } catch (_) {}
    setState(() => uploading = false);
  }

  Widget _buildAvatar() {
    final url = user["profile_image"]?.toString();
    return GestureDetector(
      onTap: pickImage,
      child: Stack(alignment: Alignment.bottomRight, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradient,
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
          child: CircleAvatar(
            radius: 58,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            backgroundImage: image != null ? FileImage(image!) : (url != null ? NetworkImage(url) : null) as ImageProvider?,
            child: (image == null && (url == null || url.isEmpty))
                ? Icon(Icons.person_rounded, size: 52, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400)
                : null,
          ),
        ),
        if (uploading)
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
            child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
          )),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle,
              border: Border.all(color: isDark ? const Color(0xFF0F172A) : Colors.white, width: 2)),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
        ),
      ]),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9);
    final labelColor = isDark ? const Color(0xFF64748B) : Colors.black45;
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: labelColor, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(value.isEmpty ? "—" : value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor), softWrap: true),
        ])),
      ]),
    );
  }

  // ── NEW: Navigation tile to the full health profile report ────────────
  Widget _healthProfileTile() {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CareSeekerProfileReportScreen(userId: widget.userId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("My Health Profile",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 3),
                Text("View & edit your full health report",
                    style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 15),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final nameColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (loading) {
      return Scaffold(backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 50, 20, 24),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16)),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Text("My Profile",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(children: [
            _buildAvatar(),
            const SizedBox(height: 16),
            Text("${user["first_name"] ?? ""} ${user["last_name"] ?? ""}".trim(),
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: nameColor)),
            const SizedBox(height: 4),
            Text(user["mobile"] ?? "", style: TextStyle(fontSize: 14, color: subColor)),
            const SizedBox(height: 28),

            _infoTile("Email Address", user["email"] ?? "", Icons.email_outlined),
            _infoTile("Role", user["role"] ?? "", Icons.badge_outlined),
            _infoTile("Mobile", user["mobile"] ?? "", Icons.phone_outlined),

            const SizedBox(height: 8),
            _healthProfileTile(),
          ]),
        )),
      ]),
    );
  }
}