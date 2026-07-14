import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this for calling functionality

class CareseekerHealthDetailsViewScreen extends StatefulWidget {
  final int userId;
  final int orderId;
  final int caretakerId;

  const CareseekerHealthDetailsViewScreen({
    super.key,
    required this.userId,
    required this.orderId,
    required this.caretakerId,
  });

  @override
  State<CareseekerHealthDetailsViewScreen> createState() =>
      _CareseekerHealthDetailsViewScreenState();
}

class _CareseekerHealthDetailsViewScreenState
    extends State<CareseekerHealthDetailsViewScreen> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchHealthProfile();
  }

  Future<void> _fetchHealthProfile() async {
    try {
      final url = "${Api.baseUrl}/health-profile/${widget.userId}";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _profile = Map<String, dynamic>.from(data['data']);
            _loading = false;
          });
        } else {
          _setError();
        }
      } else {
        _setError();
      }
    } catch (e) {
      debugPrint("Health Profile Fetch Error: $e");
      _setError();
    }
  }

  void _setError() {
    if (mounted) {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String _formatDate(String? date) {
    if (date == null) return "Not provided";
    try {
      final d = DateTime.parse(date);
      return "${d.day}/${d.month}/${d.year}";
    } catch (_) {
      return date;
    }
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _error
                      ? _buildErrorView()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBasicInfoCard(),
                              const SizedBox(height: 16),
                              _buildMedicalInfoCard(),
                              const SizedBox(height: 16),
                              _buildEmergencyContactCard(),
                              const SizedBox(height: 16),
                              _buildLifestyleCard(),
                              const SizedBox(height: 16),
                              if (_profile['special_instructions']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true) ...[
                                _buildSpecialInstructionsCard(),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // ── Clean, minimal header ─────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Health Profile",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  "Confidential medical information",
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _buildCard(
      title: "Basic Information",
      icon: Icons.person_outline,
      children: [
        _infoRow("Date of Birth", _formatDate(_profile['date_of_birth'])),
        _infoRow("Gender", _profile['gender'] ?? "Not provided"),
        _infoRow("Height", _profile['height'] != null ? "${_profile['height']} cm" : "Not provided"),
        _infoRow("Weight", _profile['weight'] != null ? "${_profile['weight']} kg" : "Not provided"),
        _infoRow("Blood Group", _profile['blood_group'] ?? "Unknown", isLast: true),
      ],
    );
  }

  Widget _buildMedicalInfoCard() {
    return _buildCard(
      title: "Medical Information",
      icon: Icons.medical_services_outlined,
      children: [
        _infoRow("Medical Conditions", _profile['medical_conditions'] ?? "None"),
        _infoRow("Allergies", _profile['allergies'] ?? "None"),
        _infoRow("Current Medications", _profile['current_medications'] ?? "None"),
        _infoRow("Mobility", _profile['mobility'] ?? "Not specified"),
        _infoRow("Assistance Required", _profile['assistance_required'] ?? "None", isLast: true),
      ],
    );
  }

  Widget _buildEmergencyContactCard() {
    final phone = _profile['emergency_contact_phone']?.toString() ?? '';
    return _buildCard(
      title: "Emergency Contact",
      icon: Icons.emergency_outlined,
      color: Colors.red.shade700,
      children: [
        _infoRow("Name", _profile['emergency_contact_name'] ?? "Not provided"),
        _infoRow("Relationship", _profile['emergency_contact_relationship'] ?? "Not provided"),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  "Phone",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  phone.isEmpty ? "Not provided" : phone,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              if (phone.isNotEmpty)
                GestureDetector(
                  onTap: () => _makeCall(phone),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.phone_rounded,
                        color: Colors.green, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyleCard() {
    return _buildCard(
      title: "Lifestyle",
      icon: Icons.favorite_outline,
      children: [
        _infoRow("Smoking", _profile['smoking'] ?? "Not specified"),
        _infoRow("Alcohol", _profile['alcohol'] ?? "Not specified", isLast: true),
      ],
    );
  }

  Widget _buildSpecialInstructionsCard() {
    return _buildCard(
      title: "Special Instructions",
      icon: Icons.note_alt_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _profile['special_instructions'] ?? "",
            style: const TextStyle(fontSize: 14.5, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF1F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Icon(icon, color: color ?? AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(top: 10, bottom: isLast ? 0 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "Failed to load health profile",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchHealthProfile,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}