import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import '../../config/api.dart';

class CareSeekerProfileReportScreen extends StatefulWidget {
  final int userId;
  const CareSeekerProfileReportScreen({super.key, required this.userId});

  @override
  State<CareSeekerProfileReportScreen> createState() =>
      _CareSeekerProfileReportScreenState();
}

class _CareSeekerProfileReportScreenState
    extends State<CareSeekerProfileReportScreen> {
  bool loading = true;
  bool saving = false;
  bool editMode = false;
  bool profileExists = false;

  bool get isDark => themeNotifier.value == ThemeMode.dark;

  // ── STATE ────────────────────────────────────────────────────────────
  DateTime? dob;
  String? gender;
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();

  String bloodGroup = "Unknown";
  final List<String> bloodGroups = [
    "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"
  ];

  final Set<String> medicalConditions = {};
  final medicalOtherCtrl = TextEditingController();
  final List<String> medicalConditionOptions = [
    "Diabetes", "High Blood Pressure", "Heart Disease", "Asthma",
    "Kidney Disease", "Thyroid Disorder", "Arthritis", "Cancer",
    "Stroke History", "Dementia", "Parkinson's Disease", "None", "Other",
  ];

  final Set<String> allergies = {};
  final allergyDescribeCtrl = TextEditingController();
  final List<String> allergyOptions = [
    "Medicines", "Food", "Dust", "Pollen", "Latex", "Insect Bites",
    "None", "Other",
  ];

  bool takingMedications = false;
  final List<Map<String, TextEditingController>> medications = [];

  String? mobility;
  final List<Map<String, dynamic>> mobilityOptions = [
    {"label": "Independent", "icon": Icons.directions_walk},
    {"label": "Walking Stick", "icon": Icons.accessible},
    {"label": "Walker", "icon": Icons.airline_seat_legroom_normal},
    {"label": "Wheelchair", "icon": Icons.accessible_forward},
    {"label": "Bedridden", "icon": Icons.bed},
  ];

  final Set<String> assistanceRequired = {};
  final assistanceOtherCtrl = TextEditingController();
  final List<String> assistanceOptions = [
    "Personal Care", "Bathing", "Dressing", "Feeding",
    "Medication Support", "Physiotherapy", "Elder Care",
    "Post Surgery Care", "Child Care", "Pregnancy Care",
    "Companion Care", "Other",
  ];

  final emergencyNameCtrl = TextEditingController();
  String? emergencyRelationship;
  final emergencyPhoneCtrl = TextEditingController();
  final List<String> relationshipOptions = [
    "Father", "Mother", "Spouse", "Son", "Daughter",
    "Brother", "Sister", "Friend", "Guardian", "Other",
  ];

  String? smoking;
  String? alcohol;

  final specialInstructionsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onTheme);
    _loadProfile();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onTheme);
    heightCtrl.dispose();
    weightCtrl.dispose();
    medicalOtherCtrl.dispose();
    allergyDescribeCtrl.dispose();
    assistanceOtherCtrl.dispose();
    emergencyNameCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    specialInstructionsCtrl.dispose();
    for (final m in medications) {
      m["name"]!.dispose();
      m["dosage"]!.dispose();
      m["frequency"]!.dispose();
    }
    super.dispose();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  void _toast(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFC0392B) : const Color(0xFF1B7A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  LOAD
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _loadProfile() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse("${Api.baseUrl}/health-profile/${widget.userId}"),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body["data"];
        _populate(data);
        profileExists = true;
      } else {
        profileExists = false;
      }
    } catch (_) {
      profileExists = false;
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  void _populate(Map data) {
    if (data["date_of_birth"] != null) {
      dob = DateTime.tryParse(data["date_of_birth"].toString());
    }
    gender = data["gender"];
    heightCtrl.text = data["height"] != null ? "${data["height"]}" : "";
    weightCtrl.text = data["weight"] != null ? "${data["weight"]}" : "";
    bloodGroup = data["blood_group"] ?? "Unknown";

    medicalConditions.clear();
    _splitInto(medicalConditions, data["medical_conditions"], medicalOtherCtrl,
        medicalConditionOptions);

    allergies.clear();
    _splitInto(allergies, data["allergies"], allergyDescribeCtrl, allergyOptions,
        isAllergy: true);

    medications.clear();
    final medText = data["current_medications"]?.toString() ?? "";
    if (medText.isNotEmpty && medText != "None") {
      takingMedications = true;
      for (final entry in medText.split(";")) {
        final parts = entry.split("—");
        if (parts.length < 2) continue;
        final name = parts[0].trim();
        final rest = parts[1].split(",");
        final dosage = rest.isNotEmpty ? rest[0].trim() : "";
        final freq = rest.length > 1 ? rest.sublist(1).join(",").trim() : "";
        medications.add({
          "name": TextEditingController(text: name),
          "dosage": TextEditingController(text: dosage),
          "frequency": TextEditingController(text: freq),
        });
      }
      if (medications.isEmpty) _addMedicationRow();
    } else {
      takingMedications = false;
    }

    mobility = data["mobility"];

    assistanceRequired.clear();
    _splitInto(assistanceRequired, data["assistance_required"],
        assistanceOtherCtrl, assistanceOptions);

    emergencyNameCtrl.text = data["emergency_contact_name"] ?? "";
    emergencyRelationship = data["emergency_contact_relationship"];
    emergencyPhoneCtrl.text = data["emergency_contact_phone"] ?? "";

    smoking = data["smoking"];
    alcohol = data["alcohol"];

    specialInstructionsCtrl.text = data["special_instructions"] ?? "";
  }

  // Parses "A, B (Other text)" back into a Set<String> + "other" controller
  void _splitInto(Set<String> target, dynamic raw, TextEditingController otherCtrl,
      List<String> validOptions,
      {bool isAllergy = false}) {
    otherCtrl.clear();
    final text = raw?.toString().trim() ?? "";
    if (text.isEmpty || text == "None") {
      if (isAllergy) return; // leave empty
      return;
    }
    String main = text;
    final match = RegExp(r'^(.*)\((.*)\)$').firstMatch(text);
    if (match != null) {
      main = match.group(1)!.trim();
      otherCtrl.text = match.group(2)!.trim();
    }
    for (final part in main.split(",")) {
      final p = part.trim();
      if (p.isEmpty) continue;
      if (isAllergy) {
        target.add(p); // allergies free-form too, keep as-is
      } else if (validOptions.contains(p)) {
        target.add(p);
      } else if (p.isNotEmpty) {
        target.add(p);
      }
    }
  }

  void _addMedicationRow() {
    medications.add({
      "name": TextEditingController(),
      "dosage": TextEditingController(),
      "frequency": TextEditingController(),
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SAVE
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _saveProfile() async {
    if (emergencyNameCtrl.text.trim().isEmpty ||
        emergencyPhoneCtrl.text.trim().isEmpty) {
      _toast("Please add an emergency contact before saving");
      return;
    }

    setState(() => saving = true);

    final medicationsText = takingMedications && medications.isNotEmpty
        ? medications
            .map((m) =>
                "${m["name"]!.text.trim()} — ${m["dosage"]!.text.trim()}, ${m["frequency"]!.text.trim()}")
            .join("; ")
        : "None";

    final medicalConditionsText = medicalConditions.isEmpty
        ? "None"
        : (medicalConditions.contains("Other") &&
                medicalOtherCtrl.text.trim().isNotEmpty
            ? "${medicalConditions.join(", ")} (${medicalOtherCtrl.text.trim()})"
            : medicalConditions.join(", "));

    final allergiesText = allergies.isEmpty
        ? "None"
        : (allergies.contains("Other") &&
                allergyDescribeCtrl.text.trim().isNotEmpty
            ? "${allergies.join(", ")} (${allergyDescribeCtrl.text.trim()})"
            : allergies.join(", "));

    final assistanceText = assistanceRequired.isEmpty
        ? null
        : (assistanceRequired.contains("Other") &&
                assistanceOtherCtrl.text.trim().isNotEmpty
            ? "${assistanceRequired.join(", ")} (${assistanceOtherCtrl.text.trim()})"
            : assistanceRequired.join(", "));

    final payload = {
      "user_id": widget.userId,
      "date_of_birth": dob != null
          ? "${dob!.year.toString().padLeft(4, '0')}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}"
          : null,
      "gender": gender,
      "height": double.tryParse(heightCtrl.text.trim()),
      "weight": double.tryParse(weightCtrl.text.trim()),
      "blood_group": bloodGroup,
      "medical_conditions": medicalConditionsText,
      "allergies": allergiesText,
      "current_medications": medicationsText,
      "mobility": mobility,
      "assistance_required": assistanceText,
      "emergency_contact_name": emergencyNameCtrl.text.trim(),
      "emergency_contact_relationship": emergencyRelationship,
      "emergency_contact_phone": emergencyPhoneCtrl.text.trim(),
      "smoking": smoking,
      "alcohol": alcohol,
      "special_instructions": specialInstructionsCtrl.text.trim().isEmpty
          ? null
          : specialInstructionsCtrl.text.trim(),
    };

    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/health-profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      setState(() => saving = false);

      if (res.statusCode != 200) {
        final data = jsonDecode(res.body);
        _toast(data["message"] ?? "Could not save your profile");
        return;
      }

      _toast("Profile updated successfully", isError: false);
      setState(() {
        editMode = false;
        profileExists = true;
      });
    } catch (e) {
      setState(() => saving = false);
      _toast("Server error. Please try again.");
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SHARED STYLES
  // ══════════════════════════════════════════════════════════════════════
  InputDecoration _field(String label, {IconData? icon, String? hint}) =>
      InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black54),
        hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.black38),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A2E2B),
            )),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _viewRow(String label, String value) {
    final labelColor = isDark ? const Color(0xFF64748B) : Colors.black45;
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: labelColor, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value.isEmpty ? "—" : value,
                style: TextStyle(fontSize: 14, color: valueColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _chipGroup({
    required List<String> options,
    required Set<String> selected,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => onTap(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.12) : (isDark ? const Color(0xFF0F172A) : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                  ),
                Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _selectCard({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.10) : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? const Color(0xFF2D3748) : Colors.grey.shade300),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: selected ? AppColors.primary : Colors.black45, size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(label, style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.black87),
            )),
          ),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey.shade400),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : (!profileExists && !editMode)
                  ? _emptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: editMode ? _editBody() : _viewBody(),
                    ),
        ),
        if (editMode) _bottomSaveBar(),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            if (editMode) {
              setState(() => editMode = false);
              _loadProfile();
            } else {
              Navigator.pop(context);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text("Health Profile Report",
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        if (!loading && profileExists && !editMode)
          GestureDetector(
            onTap: () => setState(() => editMode = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text("Edit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(gradient: AppColors.gradient, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 22),
          Text("No Health Profile Yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A2E2B))),
          const SizedBox(height: 8),
          Text("Complete your health profile so caregivers can serve you better.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.grey.shade400 : Colors.black54, height: 1.5)),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => editMode = true),
                child: const Text("Create Health Profile",
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── VIEW MODE ────────────────────────────────────────────────────────
  Widget _viewBody() {
    final medicalConditionsText = medicalConditions.isEmpty
        ? "None"
        : (medicalConditions.contains("Other") && medicalOtherCtrl.text.trim().isNotEmpty
            ? "${medicalConditions.join(", ")} (${medicalOtherCtrl.text.trim()})"
            : medicalConditions.join(", "));
    final allergiesText = allergies.isEmpty
        ? "None"
        : (allergies.contains("Other") && allergyDescribeCtrl.text.trim().isNotEmpty
            ? "${allergies.join(", ")} (${allergyDescribeCtrl.text.trim()})"
            : allergies.join(", "));
    final medicationsText = takingMedications && medications.isNotEmpty
        ? medications.map((m) => "${m["name"]!.text.trim()} — ${m["dosage"]!.text.trim()}, ${m["frequency"]!.text.trim()}").join("; ")
        : "None";
    final assistanceText = assistanceRequired.isEmpty
        ? "None"
        : (assistanceRequired.contains("Other") && assistanceOtherCtrl.text.trim().isNotEmpty
            ? "${assistanceRequired.join(", ")} (${assistanceOtherCtrl.text.trim()})"
            : assistanceRequired.join(", "));

    return Column(children: [
      _sectionCard(title: "Personal Information", icon: Icons.person_outline, children: [
        _viewRow("Date of Birth", dob == null ? "" : "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}"),
        _viewRow("Gender", gender ?? ""),
        _viewRow("Height", heightCtrl.text.trim().isEmpty ? "" : "${heightCtrl.text.trim()} cm"),
        _viewRow("Weight", weightCtrl.text.trim().isEmpty ? "" : "${weightCtrl.text.trim()} kg"),
      ]),
      _sectionCard(title: "Blood Group", icon: Icons.bloodtype_outlined, children: [
        _viewRow("Blood Group", bloodGroup),
      ]),
      _sectionCard(title: "Medical Conditions", icon: Icons.medical_information_outlined, children: [
        _viewRow("Conditions", medicalConditionsText),
      ]),
      _sectionCard(title: "Allergies", icon: Icons.warning_amber_outlined, children: [
        _viewRow("Allergies", allergiesText),
      ]),
      _sectionCard(title: "Medications", icon: Icons.medication_outlined, children: [
        _viewRow("Current Medications", medicationsText),
      ]),
      _sectionCard(title: "Mobility", icon: Icons.accessible_outlined, children: [
        _viewRow("Mobility", mobility ?? ""),
      ]),
      _sectionCard(title: "Assistance Required", icon: Icons.volunteer_activism_outlined, children: [
        _viewRow("Assistance", assistanceText),
      ]),
      _sectionCard(title: "Emergency Contact", icon: Icons.contact_phone_outlined, children: [
        _viewRow("Name", emergencyNameCtrl.text.trim()),
        _viewRow("Relationship", emergencyRelationship ?? ""),
        _viewRow("Phone", emergencyPhoneCtrl.text.trim()),
      ]),
      _sectionCard(title: "Lifestyle", icon: Icons.self_improvement_outlined, children: [
        _viewRow("Smoking", smoking ?? ""),
        _viewRow("Alcohol", alcohol ?? ""),
      ]),
      if (specialInstructionsCtrl.text.trim().isNotEmpty)
        _sectionCard(title: "Special Instructions", icon: Icons.notes_outlined, children: [
          _viewRow("Notes", specialInstructionsCtrl.text.trim()),
        ]),
    ]);
  }

  // ── EDIT MODE ────────────────────────────────────────────────────────
  Widget _editBody() {
    return Column(children: [
      _sectionCard(title: "Personal Information", icon: Icons.person_outline, children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dob ?? DateTime(1995, 1, 1),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
                child: child!,
              ),
            );
            if (picked != null) setState(() => dob = picked);
          },
          child: InputDecorator(
            decoration: _field("Date of Birth", icon: Icons.cake_outlined),
            child: Text(
              dob == null ? "Select date" : "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}",
              style: TextStyle(color: dob == null ? Colors.black38 : (isDark ? Colors.white : Colors.black87), fontSize: 14.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text("Gender", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.black54)),
        const SizedBox(height: 10),
        _chipGroup(
          options: const ["Male", "Female", "Other", "Prefer not to say"],
          selected: gender == null ? {} : {gender!},
          onTap: (opt) => setState(() => gender = opt),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: TextField(controller: heightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Height (cm)", icon: Icons.height))),
          const SizedBox(width: 14),
          Expanded(child: TextField(controller: weightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Weight (kg)", icon: Icons.monitor_weight_outlined))),
        ]),
      ]),

      _sectionCard(title: "Blood Group", icon: Icons.bloodtype_outlined, children: [
        _chipGroup(options: bloodGroups, selected: {bloodGroup}, onTap: (opt) => setState(() => bloodGroup = opt)),
      ]),

      _sectionCard(title: "Medical Conditions", icon: Icons.medical_information_outlined, children: [
        _chipGroup(
          options: medicalConditionOptions,
          selected: medicalConditions,
          onTap: (opt) {
            setState(() {
              if (opt == "None") {
                medicalConditions..clear()..add("None");
              } else {
                medicalConditions.remove("None");
                medicalConditions.contains(opt) ? medicalConditions.remove(opt) : medicalConditions.add(opt);
              }
            });
          },
        ),
        if (medicalConditions.contains("Other")) ...[
          const SizedBox(height: 14),
          TextField(controller: medicalOtherCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Please specify", icon: Icons.edit_note)),
        ],
      ]),

      _sectionCard(title: "Allergies", icon: Icons.warning_amber_outlined, children: [
        _chipGroup(
          options: allergyOptions,
          selected: allergies,
          onTap: (opt) {
            setState(() {
              if (opt == "None") {
                allergies..clear()..add("None");
              } else {
                allergies.remove("None");
                allergies.contains(opt) ? allergies.remove(opt) : allergies.add(opt);
              }
            });
          },
        ),
        if (allergies.isNotEmpty && !allergies.contains("None")) ...[
          const SizedBox(height: 14),
          TextField(controller: allergyDescribeCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Describe your allergy", icon: Icons.warning_amber_outlined, hint: "e.g. Penicillin, Peanuts")),
        ],
      ]),

      _sectionCard(title: "Current Medications", icon: Icons.medication_outlined, children: [
        Row(children: [
          Expanded(child: _selectCard(label: "Yes", selected: takingMedications, onTap: () => setState(() { takingMedications = true; if (medications.isEmpty) _addMedicationRow(); }))),
          const SizedBox(width: 12),
          Expanded(child: _selectCard(label: "No", selected: !takingMedications, onTap: () => setState(() => takingMedications = false))),
        ]),
        if (takingMedications) ...[
          const SizedBox(height: 6),
          ...medications.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200),
              ),
              child: Column(children: [
                Row(children: [
                  Text("Medicine ${i + 1}", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                  const Spacer(),
                  if (medications.length > 1)
                    GestureDetector(
                      onTap: () => setState(() {
                        m["name"]!.dispose();
                        m["dosage"]!.dispose();
                        m["frequency"]!.dispose();
                        medications.removeAt(i);
                      }),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    ),
                ]),
                const SizedBox(height: 10),
                TextField(controller: m["name"], style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Medicine Name", hint: "e.g. Metformin")),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: m["dosage"], style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Dosage", hint: "500 mg"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: m["frequency"], style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Frequency", hint: "Twice Daily"))),
                ]),
              ]),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => setState(_addMedicationRow),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
            label: const Text("Add Another Medicine", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),

      _sectionCard(title: "Mobility", icon: Icons.accessible_outlined, children: [
        ...mobilityOptions.map((opt) => _selectCard(label: opt["label"], icon: opt["icon"], selected: mobility == opt["label"], onTap: () => setState(() => mobility = opt["label"]))),
      ]),

      _sectionCard(title: "Assistance Required", icon: Icons.volunteer_activism_outlined, children: [
        _chipGroup(
          options: assistanceOptions,
          selected: assistanceRequired,
          onTap: (opt) => setState(() => assistanceRequired.contains(opt) ? assistanceRequired.remove(opt) : assistanceRequired.add(opt)),
        ),
        if (assistanceRequired.contains("Other")) ...[
          const SizedBox(height: 14),
          TextField(controller: assistanceOtherCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Please specify", icon: Icons.edit_note)),
        ],
      ]),

      _sectionCard(title: "Emergency Contact", icon: Icons.contact_phone_outlined, children: [
        TextField(controller: emergencyNameCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Full Name", icon: Icons.person_outline)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: relationshipOptions.contains(emergencyRelationship) ? emergencyRelationship : null,
          decoration: _field("Relationship", icon: Icons.diversity_3_outlined),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          items: relationshipOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => emergencyRelationship = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: emergencyPhoneCtrl, keyboardType: TextInputType.phone, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: _field("Phone Number", icon: Icons.phone_outlined, hint: "+91 XXXXXXXXXX")),
      ]),

      _sectionCard(title: "Lifestyle", icon: Icons.self_improvement_outlined, children: [
        Text("Smoking", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.black54)),
        const SizedBox(height: 10),
        _chipGroup(options: const ["Never", "Occasionally", "Regularly"], selected: smoking == null ? {} : {smoking!}, onTap: (opt) => setState(() => smoking = opt)),
        const SizedBox(height: 20),
        Text("Alcohol", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.black54)),
        const SizedBox(height: 10),
        _chipGroup(options: const ["Never", "Occasionally", "Regularly"], selected: alcohol == null ? {} : {alcohol!}, onTap: (opt) => setState(() => alcohol = opt)),
      ]),

      _sectionCard(title: "Special Instructions", icon: Icons.notes_outlined, children: [
        TextField(
          controller: specialInstructionsCtrl,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: _field("Notes", icon: Icons.notes_outlined, hint: "e.g. Prefers quiet environment..."),
        ),
      ]),
    ]);
  }

  Widget _bottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : () {
                setState(() => editMode = false);
                _loadProfile();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Cancel", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: saving ? null : _saveProfile,
                child: saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                    : const Text("Save Changes", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}