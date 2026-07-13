import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'care_seeker_home.dart';

class CareSeekerHealthProfileScreen extends StatefulWidget {
  final int userId;
  const CareSeekerHealthProfileScreen({super.key, required this.userId});

  @override
  State<CareSeekerHealthProfileScreen> createState() =>
      _CareSeekerHealthProfileScreenState();
}

class _CareSeekerHealthProfileScreenState
    extends State<CareSeekerHealthProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  // Total content pages = 0 (welcome) .. 11 (review) = 12 pages
  static const int _lastStepIndex = 10; // last data-entry step before review
  static const int _reviewIndex = 11;

  // ── STATE: PERSONAL INFO ──────────────────────────────────────────────
  DateTime? dob;
  String? gender; // Male, Female, Other, Prefer not to say
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();

  // ── STATE: BLOOD GROUP ────────────────────────────────────────────────
  String bloodGroup = "Unknown";
  final List<String> bloodGroups = [
    "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"
  ];

  // ── STATE: MEDICAL CONDITIONS ─────────────────────────────────────────
  final Set<String> medicalConditions = {};
  final medicalOtherCtrl = TextEditingController();
  final List<String> medicalConditionOptions = [
    "Diabetes", "High Blood Pressure", "Heart Disease", "Asthma",
    "Kidney Disease", "Thyroid Disorder", "Arthritis", "Cancer",
    "Stroke History", "Dementia", "Parkinson's Disease", "None", "Other",
  ];

  // ── STATE: ALLERGIES ──────────────────────────────────────────────────
  final Set<String> allergies = {};
  final allergyDescribeCtrl = TextEditingController();
  final List<String> allergyOptions = [
    "Medicines", "Food", "Dust", "Pollen", "Latex", "Insect Bites",
    "None", "Other",
  ];

  // ── STATE: MEDICATIONS ────────────────────────────────────────────────
  bool takingMedications = false;
  final List<Map<String, TextEditingController>> medications = [];

  // ── STATE: MOBILITY ────────────────────────────────────────────────────
  String? mobility; // Independent, Walking Stick, Walker, Wheelchair, Bedridden
  final List<Map<String, dynamic>> mobilityOptions = [
    {"label": "Independent", "icon": Icons.directions_walk},
    {"label": "Walking Stick", "icon": Icons.accessible},
    {"label": "Walker", "icon": Icons.airline_seat_legroom_normal},
    {"label": "Wheelchair", "icon": Icons.accessible_forward},
    {"label": "Bedridden", "icon": Icons.bed},
  ];

  // ── STATE: ASSISTANCE REQUIRED ────────────────────────────────────────
  final Set<String> assistanceRequired = {};
  final assistanceOtherCtrl = TextEditingController();
  final List<String> assistanceOptions = [
    "Personal Care", "Bathing", "Dressing", "Feeding",
    "Medication Support", "Physiotherapy", "Elder Care",
    "Post Surgery Care", "Child Care", "Pregnancy Care",
    "Companion Care", "Other",
  ];

  // ── STATE: EMERGENCY CONTACT ──────────────────────────────────────────
  final emergencyNameCtrl = TextEditingController();
  String? emergencyRelationship;
  final emergencyPhoneCtrl = TextEditingController();
  final List<String> relationshipOptions = [
    "Father", "Mother", "Spouse", "Son", "Daughter",
    "Brother", "Sister", "Friend", "Guardian", "Other",
  ];

  // ── STATE: LIFESTYLE ───────────────────────────────────────────────────
  String? smoking; // Never, Occasionally, Regularly
  String? alcohol;

  // ── STATE: SPECIAL INSTRUCTIONS ───────────────────────────────────────
  final specialInstructionsCtrl = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
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

  // ══════════════════════════════════════════════════════════════════════
  //  TOAST (lightweight, matches login page palette)
  // ══════════════════════════════════════════════════════════════════════
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
  //  NAVIGATION
  // ══════════════════════════════════════════════════════════════════════
  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  API CALLS
  // ══════════════════════════════════════════════════════════════════════
  Future<void> _skipProfile() async {
    setState(() => _saving = true);

    // Fire-and-forget-ish: don't block the user's flow on network
    try {
      await http.post(
        Uri.parse("${Api.baseUrl}/health-profile/skip"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId}),
      );
    } catch (_) {
      // Non-fatal — user can complete profile anytime from Settings
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("health_profile_completed", false);
    await prefs.setBool("health_profile_skipped", true);

    if (!mounted) return;
    setState(() => _saving = false);
    _goHome();
  }

  Future<void> _submitProfile() async {
    if (emergencyNameCtrl.text.trim().isEmpty ||
        emergencyPhoneCtrl.text.trim().isEmpty) {
      _toast("Please add an emergency contact before submitting");
      _goTo(8); // emergency contact step
      return;
    }

    setState(() => _saving = true);

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
      final response = await http.post(
        Uri.parse("${Api.baseUrl}/health-profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      setState(() => _saving = false);

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        _toast(data["message"] ?? "Could not save your profile");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("health_profile_completed", true);
      await prefs.setBool("health_profile_skipped", false);

      if (!mounted) return;
      _toast("Health profile saved", isError: false);
      _goHome();
    } catch (e) {
      setState(() => _saving = false);
      _toast("Server error. Please try again.");
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CareSeekerHome(userId: widget.userId)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SHARED FIELD STYLES
  // ══════════════════════════════════════════════════════════════════════
  InputDecoration _field(String label, {IconData? icon, String? hint}) =>
      InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  Widget _stepHeading(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2E2B))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13.5, color: Colors.black45)),
          ],
        ),
      );

  Widget _chipGroup({
    required List<String> options,
    required Set<String> selected,
    required void Function(String) onTap,
    bool exclusiveNone = true,
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
              color: isSelected
                  ? AppColors.primary.withOpacity(0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle,
                        size: 16, color: AppColors.primary),
                  ),
                Text(
                  opt,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
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
          color: selected ? AppColors.primary.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: selected ? AppColors.primary : Colors.black45,
                  size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F4),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _welcomePage(),
                _personalInfoPage(),
                _bloodGroupPage(),
                _medicalConditionsPage(),
                _allergiesPage(),
                _medicationsPage(),
                _mobilityPage(),
                _assistancePage(),
                _emergencyContactPage(),
                _lifestylePage(),
                _specialInstructionsPage(),
                _reviewPage(),
              ],
            ),
          ),
          if (_currentPage != 0) _buildBottomBar(),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isWelcome = _currentPage == 0;
    final isReview = _currentPage == _reviewIndex;
    final stepNumber = _currentPage; // step N of 10 (pages 1..10)
    final progress = isWelcome
        ? 0.0
        : isReview
            ? 1.0
            : stepNumber / _lastStepIndex;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 22,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (!isWelcome)
                    GestureDetector(
                      onTap: _saving
                          ? null
                          : () {
                              if (_currentPage == 1) {
                                _goTo(0);
                              } else {
                                _back();
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  if (!isWelcome) const SizedBox(width: 10),
                  Text(
                    isWelcome
                        ? "Health Profile"
                        : isReview
                            ? "Review Your Profile"
                            : "Health Profile Setup",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (!isReview)
                GestureDetector(
                  onTap: _saving ? null : _skipProfile,
                  child: Text(
                    "Skip",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          if (!isWelcome) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFB2FFEE)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isReview ? "Almost done" : "Step $stepNumber of $_lastStepIndex",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── BOTTOM BAR ───────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isReview = _currentPage == _reviewIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isReview)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _goTo(1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Edit",
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            if (isReview) const SizedBox(width: 14),
            Expanded(
              flex: isReview ? 2 : 1,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saving
                      ? null
                      : isReview
                          ? _submitProfile
                          : _next,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4),
                        )
                      : Text(
                          isReview
                              ? "Submit Profile"
                              : (_currentPage == _lastStepIndex
                                  ? "Review"
                                  : "Continue"),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 0 — WELCOME
  // ══════════════════════════════════════════════════════════════════════
  Widget _welcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          const Text(
            "Welcome to Medico 👋",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2E2B),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Let's set up your Health Profile.\n\nThis helps caregivers provide safer\nand more personalized care.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                "Takes less than 2 minutes",
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _goTo(1),
              child: const Text(
                "COMPLETE NOW",
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _saving ? null : _skipProfile,
            child: Text(
              "Skip for Now",
              style: TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 1 — PERSONAL INFO
  // ══════════════════════════════════════════════════════════════════════
  Widget _personalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Personal Information",
              "Basic details help us personalize your care"),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dob ?? DateTime(1995, 1, 1),
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => dob = picked);
            },
            child: InputDecorator(
              decoration: _field("Date of Birth", icon: Icons.cake_outlined),
              child: Text(
                dob == null
                    ? "Select date"
                    : "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}",
                style: TextStyle(
                  color: dob == null ? Colors.black38 : Colors.black87,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text("Gender",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 10),
          _chipGroup(
            options: const ["Male", "Female", "Other", "Prefer not to say"],
            selected: gender == null ? {} : {gender!},
            onTap: (opt) => setState(() => gender = opt),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: heightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _field("Height (cm)", icon: Icons.height),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      _field("Weight (kg)", icon: Icons.monitor_weight_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 2 — BLOOD GROUP
  // ══════════════════════════════════════════════════════════════════════
  Widget _bloodGroupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Blood Information",
              "In case of emergencies, this could save time"),
          _chipGroup(
            options: bloodGroups,
            selected: {bloodGroup},
            onTap: (opt) => setState(() => bloodGroup = opt),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 3 — MEDICAL CONDITIONS
  // ══════════════════════════════════════════════════════════════════════
  Widget _medicalConditionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Medical Conditions",
              "Do you have any of the following conditions?"),
          _chipGroup(
            options: medicalConditionOptions,
            selected: medicalConditions,
            onTap: (opt) {
              setState(() {
                if (opt == "None") {
                  medicalConditions
                    ..clear()
                    ..add("None");
                } else {
                  medicalConditions.remove("None");
                  medicalConditions.contains(opt)
                      ? medicalConditions.remove(opt)
                      : medicalConditions.add(opt);
                }
              });
            },
          ),
          if (medicalConditions.contains("Other")) ...[
            const SizedBox(height: 16),
            TextField(
              controller: medicalOtherCtrl,
              decoration: _field("Please specify", icon: Icons.edit_note),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 4 — ALLERGIES
  // ══════════════════════════════════════════════════════════════════════
  Widget _allergiesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Allergies", "Do you have any known allergies?"),
          _chipGroup(
            options: allergyOptions,
            selected: allergies,
            onTap: (opt) {
              setState(() {
                if (opt == "None") {
                  allergies
                    ..clear()
                    ..add("None");
                } else {
                  allergies.remove("None");
                  allergies.contains(opt)
                      ? allergies.remove(opt)
                      : allergies.add(opt);
                }
              });
            },
          ),
          if (allergies.isNotEmpty && !allergies.contains("None")) ...[
            const SizedBox(height: 16),
            TextField(
              controller: allergyDescribeCtrl,
              decoration: _field("Describe your allergy",
                  icon: Icons.warning_amber_outlined,
                  hint: "e.g. Penicillin, Peanuts, Seafood"),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 5 — MEDICATIONS
  // ══════════════════════════════════════════════════════════════════════
  Widget _medicationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Current Medications",
              "Are you currently taking any medicines?"),
          Row(
            children: [
              Expanded(
                child: _selectCard(
                  label: "Yes",
                  selected: takingMedications,
                  onTap: () => setState(() {
                    takingMedications = true;
                    if (medications.isEmpty) _addMedicationRow();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _selectCard(
                  label: "No",
                  selected: !takingMedications,
                  onTap: () => setState(() => takingMedications = false),
                ),
              ),
            ],
          ),
          if (takingMedications) ...[
            const SizedBox(height: 8),
            ...medications.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text("Medicine ${i + 1}",
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const Spacer(),
                        if (medications.length > 1)
                          GestureDetector(
                            onTap: () => setState(() {
                              m["name"]!.dispose();
                              m["dosage"]!.dispose();
                              m["frequency"]!.dispose();
                              medications.removeAt(i);
                            }),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: m["name"],
                      decoration: _field("Medicine Name",
                          hint: "e.g. Metformin"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: m["dosage"],
                            decoration: _field("Dosage", hint: "500 mg"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: m["frequency"],
                            decoration:
                                _field("Frequency", hint: "Twice Daily"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => setState(_addMedicationRow),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
              label: const Text("Add Another Medicine",
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  void _addMedicationRow() {
    medications.add({
      "name": TextEditingController(),
      "dosage": TextEditingController(),
      "frequency": TextEditingController(),
    });
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 6 — MOBILITY
  // ══════════════════════════════════════════════════════════════════════
  Widget _mobilityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Mobility", "How mobile are you day-to-day?"),
          ...mobilityOptions.map((opt) => _selectCard(
                label: opt["label"],
                icon: opt["icon"],
                selected: mobility == opt["label"],
                onTap: () => setState(() => mobility = opt["label"]),
              )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 7 — ASSISTANCE REQUIRED
  // ══════════════════════════════════════════════════════════════════════
  Widget _assistancePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Assistance Required",
              "What kind of assistance do you usually need?"),
          _chipGroup(
            options: assistanceOptions,
            selected: assistanceRequired,
            onTap: (opt) {
              setState(() {
                assistanceRequired.contains(opt)
                    ? assistanceRequired.remove(opt)
                    : assistanceRequired.add(opt);
              });
            },
          ),
          if (assistanceRequired.contains("Other")) ...[
            const SizedBox(height: 16),
            TextField(
              controller: assistanceOtherCtrl,
              decoration: _field("Please specify", icon: Icons.edit_note),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 8 — EMERGENCY CONTACT
  // ══════════════════════════════════════════════════════════════════════
  Widget _emergencyContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Emergency Contact",
              "Who should caregivers reach in an emergency?"),
          TextField(
            controller: emergencyNameCtrl,
            decoration: _field("Full Name", icon: Icons.person_outline),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: emergencyRelationship,
            decoration: _field("Relationship", icon: Icons.diversity_3_outlined),
            items: relationshipOptions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => emergencyRelationship = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emergencyPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: _field("Phone Number",
                icon: Icons.phone_outlined, hint: "+91 XXXXXXXXXX"),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 9 — LIFESTYLE
  // ══════════════════════════════════════════════════════════════════════
  Widget _lifestylePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Lifestyle (Optional)",
              "Helps caregivers understand your daily habits"),
          Text("Smoking",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 10),
          _chipGroup(
            options: const ["Never", "Occasionally", "Regularly"],
            selected: smoking == null ? {} : {smoking!},
            onTap: (opt) => setState(() => smoking = opt),
          ),
          const SizedBox(height: 22),
          Text("Alcohol",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 10),
          _chipGroup(
            options: const ["Never", "Occasionally", "Regularly"],
            selected: alcohol == null ? {} : {alcohol!},
            onTap: (opt) => setState(() => alcohol = opt),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 10 — SPECIAL INSTRUCTIONS
  // ══════════════════════════════════════════════════════════════════════
  Widget _specialInstructionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Special Instructions (Optional)",
              "Anything else caregivers should know?"),
          TextField(
            controller: specialInstructionsCtrl,
            maxLines: 5,
            decoration: _field(
              "Special Instructions",
              icon: Icons.notes_outlined,
              hint: "e.g. Prefers quiet environment, hard of hearing in left ear...",
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PAGE 11 — REVIEW
  // ══════════════════════════════════════════════════════════════════════
  Widget _reviewPage() {
    String medicalConditionsText = medicalConditions.isEmpty
        ? "None"
        : (medicalConditions.contains("Other") &&
                medicalOtherCtrl.text.trim().isNotEmpty
            ? "${medicalConditions.join(", ")} (${medicalOtherCtrl.text.trim()})"
            : medicalConditions.join(", "));

    String allergiesText = allergies.isEmpty
        ? "None"
        : (allergies.contains("Other") &&
                allergyDescribeCtrl.text.trim().isNotEmpty
            ? "${allergies.join(", ")} (${allergyDescribeCtrl.text.trim()})"
            : allergies.join(", "));

    String medicationsText = takingMedications && medications.isNotEmpty
        ? medications
            .map((m) =>
                "${m["name"]!.text.trim()} — ${m["dosage"]!.text.trim()}, ${m["frequency"]!.text.trim()}")
            .join("; ")
        : "None";

    String assistanceText = assistanceRequired.isEmpty
        ? "None"
        : (assistanceRequired.contains("Other") &&
                assistanceOtherCtrl.text.trim().isNotEmpty
            ? "${assistanceRequired.join(", ")} (${assistanceOtherCtrl.text.trim()})"
            : assistanceRequired.join(", "));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading("Review Your Profile",
              "Please confirm your details before submitting"),
          _reviewSection("Personal Information", [
            _reviewRow("Date of Birth", dob == null
                ? "Not set"
                : "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}"),
            _reviewRow("Gender", gender ?? "Not set"),
            _reviewRow("Height", heightCtrl.text.trim().isEmpty
                ? "Not set"
                : "${heightCtrl.text.trim()} cm"),
            _reviewRow("Weight", weightCtrl.text.trim().isEmpty
                ? "Not set"
                : "${weightCtrl.text.trim()} kg"),
          ]),
          _reviewSection("Blood Group", [
            _reviewRow("Blood Group", bloodGroup),
          ]),
          _reviewSection("Medical Conditions", [
            _reviewRow("Conditions", medicalConditionsText),
          ]),
          _reviewSection("Allergies", [
            _reviewRow("Allergies", allergiesText),
          ]),
          _reviewSection("Medications", [
            _reviewRow("Current Medications", medicationsText),
          ]),
          _reviewSection("Mobility", [
            _reviewRow("Mobility", mobility ?? "Not set"),
          ]),
          _reviewSection("Assistance Required", [
            _reviewRow("Assistance", assistanceText),
          ]),
          _reviewSection("Emergency Contact", [
            _reviewRow("Name", emergencyNameCtrl.text.trim().isEmpty
                ? "Not set"
                : emergencyNameCtrl.text.trim()),
            _reviewRow("Relationship", emergencyRelationship ?? "Not set"),
            _reviewRow("Phone", emergencyPhoneCtrl.text.trim().isEmpty
                ? "Not set"
                : emergencyPhoneCtrl.text.trim()),
          ]),
          _reviewSection("Lifestyle", [
            _reviewRow("Smoking", smoking ?? "Not set"),
            _reviewRow("Alcohol", alcohol ?? "Not set"),
          ]),
          if (specialInstructionsCtrl.text.trim().isNotEmpty)
            _reviewSection("Special Instructions", [
              _reviewRow("Notes", specialInstructionsCtrl.text.trim()),
            ]),
        ],
      ),
    );
  }

  Widget _reviewSection(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}