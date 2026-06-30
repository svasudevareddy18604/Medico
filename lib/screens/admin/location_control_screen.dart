import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';

class LocationControlScreen extends StatefulWidget {
  const LocationControlScreen({super.key});

  @override
  State<LocationControlScreen> createState() =>
      _LocationControlScreenState();
}

class _LocationControlScreenState extends State<LocationControlScreen> {

  String mode = "ALL_INDIA";

  List<String> statesList = [];
  List<String> selectedStates = [];

  List<String> selectedAreas = [];
  List<String> pincodes = [];

  final TextEditingController areaController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    areaController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  /* ================= FETCH ================= */

  Future<void> fetchData() async {
    try {
      final res =
          await http.get(Uri.parse("${Api.baseUrl}/admin/location"));

      final data = jsonDecode(res.body);

      setState(() {
        mode = data['mode'] ?? "ALL_INDIA";

        statesList = List<String>.from(data['statesList'] ?? []);

        selectedStates =
            List<String>.from(data['states'] ?? []);

        selectedAreas =
            List<String>.from(data['areas'] ?? []);

        pincodes =
            List<String>.from(data['pincodes'] ?? []);

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  /* ================= SAVE ================= */

  Future<void> saveSettings() async {
    setState(() => isSaving = true);

    final body = {
      "mode": mode,
      "states": selectedStates,
      "areas": selectedAreas,
      "pincodes": pincodes,
    };

    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/location"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Saved Successfully"),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to save settings"),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Something went wrong. Check connection."),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (mounted) setState(() => isSaving = false);
  }

  /* ================= ADD AREA ================= */

  void addArea() {
    final text = areaController.text.trim();

    if (text.isNotEmpty && !selectedAreas.contains(text)) {
      setState(() {
        selectedAreas.add(text);
        areaController.clear();
      });
    }
  }

  /* ================= ADD PINCODE ================= */

  void addPincode() {
    final text = pincodeController.text.trim();

    if (text.length == 6 && !pincodes.contains(text)) {
      setState(() {
        pincodes.add(text);
        pincodeController.clear();
      });
    }
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionCard(
                          title: "Service Mode",
                          subtitle: "Choose how widely your service operates",
                          icon: Icons.public_rounded,
                          child: _modeDropdown(),
                        ),

                        if (mode != "ALL_INDIA") ...[
                          const SizedBox(height: 18),
                          _sectionCard(
                            title: "Select States",
                            subtitle: "Tap to toggle states you serve",
                            icon: Icons.map_rounded,
                            child: _statesChips(),
                          ),
                        ],

                        if (mode == "CUSTOM") ...[
                          const SizedBox(height: 18),
                          _sectionCard(
                            title: "Custom Areas",
                            subtitle: "Add specific cities or localities",
                            icon: Icons.location_city_rounded,
                            child: _areaInput(),
                          ),
                          const SizedBox(height: 18),
                          _sectionCard(
                            title: "Pincodes",
                            subtitle: "Add exact 6-digit pincodes",
                            icon: Icons.pin_drop_rounded,
                            child: _pincodeInput(),
                          ),
                        ],

                        const SizedBox(height: 28),
                        _saveButton(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() => Container(
    width: double.infinity,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 18,
      left: 20, right: 20, bottom: 30,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      const SizedBox(width: 14),
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Location Control",
                style: TextStyle(color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 3),
            Text("Manage where your service is available",
                style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          ],
        ),
      ),
    ]),
  );

  // ── Section card ──────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(11),
              boxShadow: AppColors.glowShadow,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15.5,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  // ── Mode dropdown ─────────────────────────────────────────────────────────

  Widget _modeDropdown() => Container(
    decoration: BoxDecoration(
      color: AppColors.lightBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        initialValue: mode,
        decoration: const InputDecoration(border: InputBorder.none),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
        items: const [
          DropdownMenuItem(value: "ALL_INDIA", child: Text("All India")),
          DropdownMenuItem(value: "STATE", child: Text("Selected States")),
          DropdownMenuItem(value: "CUSTOM", child: Text("Custom Areas")),
        ],
        onChanged: (val) {
          setState(() {
            mode = val!;
            selectedStates.clear();
            selectedAreas.clear();
            pincodes.clear();
          });
        },
      ),
    ),
  );

  // ── States chips ──────────────────────────────────────────────────────────

  Widget _statesChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: statesList.map((state) {
      final isSelected = selectedStates.contains(state);

      return GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedStates.remove(state);
            } else {
              selectedStates.add(state);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.gradient : null,
            color: isSelected ? null : AppColors.lightBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Text(state,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.dark,
              )),
        ),
      );
    }).toList(),
  );

  // ── Area input ────────────────────────────────────────────────────────────

  Widget _areaInput() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _styledTextField(
        controller: areaController,
        hint: "Enter Area (Ongole, Anekal...)",
        onAdd: addArea,
      ),
      if (selectedAreas.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectedAreas.map((area) => _removableChip(
            label: area,
            onDeleted: () => setState(() => selectedAreas.remove(area)),
          )).toList(),
        ),
      ],
    ],
  );

  // ── Pincode input ─────────────────────────────────────────────────────────

  Widget _pincodeInput() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _styledTextField(
        controller: pincodeController,
        hint: "Enter Pincode",
        keyboardType: TextInputType.number,
        onAdd: addPincode,
      ),
      if (pincodes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: pincodes.map((p) => _removableChip(
            label: p,
            onDeleted: () => setState(() => pincodes.remove(p)),
          )).toList(),
        ),
      ],
    ],
  );

  // ── Reusable styled text field ───────────────────────────────────────────

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    TextInputType? keyboardType,
  }) => Container(
    decoration: BoxDecoration(
      color: AppColors.lightBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.muted, fontSize: 13.5),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: GestureDetector(
          onTap: onAdd,
          child: Container(
            margin: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    ),
  );

  // ── Removable chip ────────────────────────────────────────────────────────

  Widget _removableChip({required String label, required VoidCallback onDeleted}) =>
      Container(
    padding: const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onDeleted,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, size: 13, color: AppColors.danger),
        ),
      ),
    ]),
  );

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _saveButton() => GestureDetector(
    onTap: isSaving ? null : saveSettings,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.glowShadow,
      ),
      child: Center(
        child: isSaving
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
              )
            : const Text("Save Settings",
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ),
  );
}