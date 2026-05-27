import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class RadiusSettingsScreen extends StatefulWidget {
  const RadiusSettingsScreen({super.key});
  @override
  State<RadiusSettingsScreen> createState() => _RadiusSettingsScreenState();
}

class _RadiusSettingsScreenState extends State<RadiusSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false, _fetching = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse(Api.getRadius));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _ctrl.text = data["radius_km"].toString();
      }
    } catch (_) {}
    setState(() => _fetching = false);
  }

  Future<void> _save() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) return _toast("Enter a radius value", isError: true);
    final radius = int.tryParse(value);
    if (radius == null || radius <= 0) return _toast("Radius must be greater than 0", isError: true);

    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse(Api.setRadius),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"radius_km": radius}));
      if (res.statusCode == 200) {
        _toast("Radius updated successfully ✓");
        Navigator.pop(context);
      } else {
        _toast("Failed to update radius", isError: true);
      }
    } catch (_) { _toast("Network error. Try again.", isError: true); }
    setState(() => _loading = false);
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      duration: const Duration(seconds: 3),
    ));
  }

  Widget _infoRow(String km, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(8)),
        child: Text(km, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    body: _fetching
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : Column(children: [

          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 58, 20, 28),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text("Caretaker Radius",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 3),
                Text("Control caretaker visibility range",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Input Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                      blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Search Radius", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Distance in kilometres", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ]),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "e.g. 10",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                        suffixText: "KM",
                        suffixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        filled: true,
                        fillColor: const Color(0xFFF3F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _loading ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 54,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: _loading ? null : AppColors.gradient,
                          color: _loading ? Colors.grey.shade200 : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _loading ? [] : [
                            BoxShadow(color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 12, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Center(child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.save_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text("Save Radius",
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ]),
                        ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                      blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text("Coverage Guide",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          color: Colors.grey.shade800)),
                    ]),
                    const SizedBox(height: 14),
                    _infoRow("3 KM",  "Very close caretakers only"),
                    _infoRow("10 KM", "Balanced neighbourhood coverage"),
                    _infoRow("30 KM", "Wide city-level coverage"),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
  );
}