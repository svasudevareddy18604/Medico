import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminProfile extends StatefulWidget {
  final int userId;
  const AdminProfile({super.key, required this.userId});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() => loading = true);
    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/admin/profile/${widget.userId}"))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) setState(() => user = jsonDecode(res.body));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> pickAndUpload() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final req = http.MultipartRequest(
      "POST", Uri.parse("${Api.baseUrl}/admin/upload-profile/${widget.userId}"),
    );
    req.files.add(await http.MultipartFile.fromPath("image", picked.path));
    await req.send();
    loadProfile();
  }

  Future<void> changePassword(String password) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/change-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId, "password": password}),
      );
      _snack(jsonDecode(res.body)["message"] ?? "Password updated");
    } catch (_) {
      _snack("Failed to update password");
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
  );

  void showPasswordDialog() {
    final ctrl = TextEditingController();
    bool obscure = true;
    bool busy = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: "Enter new password",
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => set(() => obscure = !obscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: busy ? null : () async {
                if (ctrl.text.length < 4) { _snack("Password too short"); return; }
                set(() => busy = true);
                await changePassword(ctrl.text);
                Navigator.pop(ctx);
              },
              child: busy
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  // ── WIDGETS ──────────────────────────────────────────────

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: const Row(children: [
      Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 26),
      SizedBox(width: 10),
      Text("Admin Profile", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _avatar() {
    final image = user?["profile_image"];
    final imageUrl = (image != null && image.toString().isNotEmpty)
    ? image.toString()
    : null;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 16, spreadRadius: 2)],
          ),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: Colors.grey.shade100,
            child: imageUrl != null
                ? ClipOval(child: Image.network(
                    imageUrl,
                    width: 112, height: 112, fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48, color: Colors.grey),
                  ))
                : const Icon(Icons.person, size: 48, color: Colors.grey),
          ),
        ),
        Positioned(
          bottom: 2, right: 2,
          child: GestureDetector(
            onTap: pickAndUpload,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value ?? "—", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
      ])),
    ]),
  );

  Widget _card() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      _avatar(),
      const SizedBox(height: 16),
      Text(
        "${user!["first_name"] ?? ""} ${user!["last_name"] ?? ""}".trim(),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(user!["role"] ?? "Admin",
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
      const SizedBox(height: 20),
      const Divider(height: 1),
      const SizedBox(height: 16),
      _infoRow(Icons.email_rounded, "Email", user!["email"]),
      _infoRow(Icons.phone_rounded, "Mobile", user!["mobile"]),
      _infoRow(Icons.badge_rounded, "Role", user!["role"]),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: showPasswordDialog,
        icon: const Icon(Icons.lock_reset_rounded, size: 18),
        label: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F6F9),
    body: Column(children: [
      _header(),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : user == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_off_rounded, size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text("Profile not found", style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: loadProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text("Retry")),
                  ]))
                : ListView(children: [_card()]),
      ),
    ]),
  );
}