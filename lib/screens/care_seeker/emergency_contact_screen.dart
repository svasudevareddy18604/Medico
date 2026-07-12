import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';

class EmergencyContactScreen extends StatefulWidget {
  final int userId;
  const EmergencyContactScreen({super.key, required this.userId});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final relationController = TextEditingController();
  final phoneController = TextEditingController();
  final altPhoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _hasExisting = false;

  bool get isDark => themeNotifier.value == ThemeMode.dark;
  void _onThemeChange() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _loadContact();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    nameController.dispose();
    relationController.dispose();
    phoneController.dispose();
    altPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    try {
      final res = await http.get(
        Uri.parse("${Api.baseUrl}/emergency-contact/${widget.userId}"),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data["name"] != null) {
          nameController.text = (data["name"] ?? "").toString();
          relationController.text = (data["relationship"] ?? "").toString();
          phoneController.text = (data["phone"] ?? "").toString();
          altPhoneController.text = (data["alt_phone"] ?? "").toString();
          _hasExisting = true;
        }
      }
      // 404 = no contact saved yet, that's fine — leave form empty
    } catch (e) {
      debugPrint("EMERGENCY CONTACT LOAD ERROR: $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/emergency-contact/save"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "name": nameController.text.trim(),
          "relationship": relationController.text.trim(),
          "phone": phoneController.text.trim(),
          "alt_phone": altPhoneController.text.trim(),
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        _showToast("Emergency contact saved", success: true);
        setState(() => _hasExisting = true);
      } else {
        _showToast("Failed to save contact", success: false);
      }
    } catch (e) {
      debugPrint("EMERGENCY CONTACT SAVE ERROR: $e");
      if (mounted) _showToast("Something went wrong. Check your connection.", success: false);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showToast(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF1B7A4A) : const Color(0xFFC0392B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    String? Function(String?)? validator,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      keyboardType: type,
      maxLength: maxLength,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey[600]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey.shade400 : Colors.grey[600]),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        counterText: "",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.grey[50]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20, right: 20, bottom: 24,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child: Icon(Icons.arrow_back, color: Colors.black87, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text("Emergency Contact",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(isDark ? 0.14 : 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "This contact will be used in case of an emergency during a booking.",
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(children: [
                        _field(nameController, "Contact Name", Icons.person,
                            validator: (v) => v!.trim().isEmpty ? "Name is required" : null),
                        _field(relationController, "Relationship (e.g. Son, Spouse)", Icons.family_restroom,
                            validator: (v) => v!.trim().isEmpty ? "Relationship is required" : null),
                        _field(phoneController, "Phone Number", Icons.phone,
                            type: TextInputType.phone, maxLength: 10,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return "Phone number is required";
                              if (v.trim().length != 10) return "Must be 10 digits";
                              return null;
                            }),
                        _field(altPhoneController, "Alternate Phone (optional)", Icons.phone_outlined,
                            type: TextInputType.phone, maxLength: 10),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveContact,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22, width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text(_hasExisting ? "Update Contact" : "Save Contact",
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
        ),
      ]),
    );
  }
}