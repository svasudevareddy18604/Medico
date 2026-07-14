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
    } else {
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
          : _error
              ? _buildErrorView()
              : Column(
                  children: [
                    // Curved Header - Matching the image style (teal/gradient)
                    _buildCurvedHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBasicInfoCard(),
                            const SizedBox(height: 20),
                            _buildMedicalInfoCard(),
                            const SizedBox(height: 20),
                            _buildEmergencyContactCard(),
                            const SizedBox(height: 20),
                            _buildLifestyleCard(),
                            const SizedBox(height: 20),
                            if (_profile['special_instructions']?.toString().isNotEmpty == true)
                              _buildSpecialInstructionsCard(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCurvedHeader() {
    return ClipPath(
      clipper: CurvedHeaderClipper(),
      child: Container(
        height: 160,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF00BFA5), // Teal like in image
              Color(0xFF26A69A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Careseeker Health Profile",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 40), // Balance
                  ],
                ),
                const Spacer(),
                // Optional profile info in header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 28, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile['full_name'] ?? "Careseeker",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Order #${widget.orderId}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        _infoRow("Blood Group", _profile['blood_group'] ?? "Unknown"),
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
        _infoRow("Assistance Required", _profile['assistance_required'] ?? "None"),
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
        Row(
          children: [
            Expanded(
              child: _infoRow("Phone", phone.isEmpty ? "Not provided" : phone),
            ),
            if (phone.isNotEmpty)
              IconButton(
                onPressed: () => _makeCall(phone),
                icon: const Icon(Icons.phone, color: Colors.green, size: 28),
                tooltip: "Call Now",
              ),
          ],
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
        _infoRow("Alcohol", _profile['alcohol'] ?? "Not specified"),
      ],
    );
  }

  Widget _buildSpecialInstructionsCard() {
    return _buildCard(
      title: "Special Instructions",
      icon: Icons.note_alt_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _profile['special_instructions'] ?? "",
            style: const TextStyle(fontSize: 15, height: 1.5),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(icon, color: color ?? AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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

// Custom Clipper for Curved Header (matches modern app style like the image)
class CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}