import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class ServiceChargesScreen extends StatefulWidget {
  const ServiceChargesScreen({super.key});
  @override
  State<ServiceChargesScreen> createState() => _ServiceChargesScreenState();
}

class _ServiceChargesScreenState extends State<ServiceChargesScreen> {
  bool loading = true, saving = false;
  bool isEnabled = true, perKm = false;
  final amountCtrl = TextEditingController();

  @override
  void initState() { super.initState(); fetchData(); }

  @override
  void dispose() { amountCtrl.dispose(); super.dispose(); }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(Api.getServiceCharges));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          isEnabled = d['is_enabled'] == true || d['is_enabled'] == 1;
          perKm = d['charge_type'] == "per_km";
          amountCtrl.text = (d['amount'] ?? 0).toString();
        });
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> saveData() async {
    setState(() => saving = true);
    try {
      final res = await http.put(
        Uri.parse(Api.updateServiceCharges),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "is_enabled": isEnabled,
          "charge_type": perKm ? "per_km" : "flat",
          "amount": int.tryParse(amountCtrl.text) ?? 0,
        }),
      );
      _snack(res.statusCode == 200 ? "✅ Saved successfully" : "❌ Failed to save",
        error: res.statusCode != 200);
      if (res.statusCode == 200) fetchData();
    } catch (_) {
      _snack("❌ Error occurred", error: true);
    }
    setState(() => saving = false);
  }

  void _snack(String msg, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade600 : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));

  Widget _switchCard({required String title, required String subtitle, required IconData icon,
      required Color color, required bool value, required ValueChanged<bool> onChanged}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ]),
    );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F6F9),
    body: Column(children: [

      // ── HEADER ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Service Charges",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Configure charge settings",
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ]),
      ),

      if (loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
      else
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [

            _switchCard(
              title: "Enable Charges",
              subtitle: "Toggle service charge on/off",
              icon: Icons.toggle_on_rounded,
              color: AppColors.primary,
              value: isEnabled,
              onChanged: (v) => setState(() => isEnabled = v),
            ),

            _switchCard(
              title: "Charge per KM",
              subtitle: isEnabled ? (perKm ? "Currently: per kilometre" : "Currently: flat rate") : "Enable charges first",
              icon: Icons.route_rounded,
              color: Colors.indigo,
              value: perKm,
              onChanged: (v) { if (isEnabled) setState(() => perKm = v); },
            ),

            const SizedBox(height: 4),

            // ── AMOUNT INPUT ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.currency_rupee_rounded, color: Colors.orange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(perKm ? "Rate per KM (₹)" : "Flat Charge (₹)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("Enter the charge amount",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "e.g. 50",
                    prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
                    filled: true,
                    fillColor: const Color(0xFFF3F6F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: saving ? null : saveData,
                icon: saving
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(saving ? "Saving..." : "Save Changes",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ]),
        )),
    ]),
  );
}