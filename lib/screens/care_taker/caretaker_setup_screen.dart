import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'document_upload_screen.dart';

class CaretakerSetupScreen extends StatefulWidget {
  final int userId;

  const CaretakerSetupScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CaretakerSetupScreen> createState() =>
      _CaretakerSetupScreenState();
}

class _CaretakerSetupScreenState extends State<CaretakerSetupScreen> {
  int step = 0;

  File? profileImage;

  String caregiverType = "";
  String experience = "";
  String availability = "";

  List<String> services = [];

  final ImagePicker picker = ImagePicker();

  bool loading = false;

 

  /* ---------------- IMAGE PICKER ---------------- */

  Future pickImage() async {
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        profileImage = File(picked.path);
      });
    }
  }

  /* ---------------- NAVIGATION ---------------- */

  void nextStep() => setState(() => step++);
  void previousStep() {
    if (step > 0) setState(() => step--);
  }

  /* ---------------- SAVE ---------------- */

  Future<void> saveCaretakerProfile() async {
    try {
      setState(() => loading = true);

      var request = http.MultipartRequest(
        "POST",
        Uri.parse(Api.caretakerOnboarding),
      );

      request.fields["user_id"] = widget.userId.toString();
      request.fields["caregiver_type"] = caregiverType;
      request.fields["services"] = services.join(",");
      request.fields["experience"] = experience;
      request.fields["availability"] = availability;

      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            "profile_image",
            profileImage!.path,
          ),
        );
      }

      var response = await request.send();
      var res = await http.Response.fromStream(response);

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentUploadScreen(
              userId: widget.userId,
              caregiverType: caregiverType,
            ),
          ),
        );
      } else {
        showSnack(data["message"] ?? "Profile save failed");
      }
    } catch (e) {
      showSnack("Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void finishSetup() => saveCaretakerProfile();

  /* ---------------- HEADER ---------------- */

  Widget appHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(25),
        ),
      ),
      child: Row(
        children: [
          if (step > 0)
            IconButton(
              onPressed: previousStep,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          const SizedBox(width: 6),
          const Text(
            "Caregiver Setup",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- PROGRESS ---------------- */

  Widget progressBar() {
    double value = (step + 1) / 6;

    return Column(
      children: [
        LinearProgressIndicator(
          value: value,
          color: AppColors.primary,
          backgroundColor: Colors.grey.shade300,
        ),
        const SizedBox(height: 8),
        Text("Step ${step + 1} of 6"),
      ],
    );
  }

  /* ---------------- BUTTON ---------------- */

  Widget primaryButton(String text, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  /* ---------------- STEPS ---------------- */

  Widget buildStep() {
    switch (step) {

      /// STEP 0
      case 0:
        return Column(
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.health_and_safety,
                  size: 70, color: Color(0xFF0F9D58)),
            ),
            const SizedBox(height: 20),
            const Text("Welcome Caregiver",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Let's set up your caregiver profile.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            primaryButton("Start Setup", nextStep),
          ],
        );

      /// STEP 1
      case 1:
        return Column(
          children: [
            const Text("Upload Profile Photo",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 65,
              backgroundImage:
                  profileImage != null ? FileImage(profileImage!) : null,
              backgroundColor: Colors.grey.shade300,
              child: profileImage == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 20),
            primaryButton("Choose Photo", pickImage),
            const SizedBox(height: 20),
            primaryButton("Next",
                profileImage == null ? null : nextStep),
          ],
        );

      /// STEP 2 (FIXED FULL)
      case 2:
        return Column(
          children: [
            const Text("Caregiver Category",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            RadioListTile(
              value: "Nurse",
              groupValue: caregiverType,
              onChanged: (v) => setState(() => caregiverType = v.toString()),
              title: const Text("Nurse"),
            ),

            RadioListTile(
              value: "Non-Medical Support",
              groupValue: caregiverType,
              onChanged: (v) => setState(() => caregiverType = v.toString()),
              title: const Text("Non-Medical Support"),
            ),

            RadioListTile(
              value: "Physiotherapy",
              groupValue: caregiverType,
              onChanged: (v) => setState(() => caregiverType = v.toString()),
              title: const Text("Physiotherapy"),
            ),

            primaryButton(
              "Next",
              caregiverType.isEmpty ? null : nextStep,
            ),
          ],
        );

      /// STEP 3 (FIXED FULL)
      case 3:
        return Column(
          children: [
            const Text("Experience",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            RadioListTile(
              value: "No Experience",
              groupValue: experience,
              onChanged: (v) => setState(() => experience = v.toString()),
              title: const Text("No Experience"),
            ),

            RadioListTile(
              value: "1-2 Years",
              groupValue: experience,
              onChanged: (v) => setState(() => experience = v.toString()),
              title: const Text("1-2 Years"),
            ),

            RadioListTile(
              value: "3-5 Years",
              groupValue: experience,
              onChanged: (v) => setState(() => experience = v.toString()),
              title: const Text("3-5 Years"),
            ),

            primaryButton(
              "Next",
              experience.isEmpty ? null : nextStep,
            ),
          ],
        );

      /// STEP 4 (FIXED FULL)
      case 4:
        return Column(
          children: [
            const Text("Availability",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            RadioListTile(
              value: "Full Time",
              groupValue: availability,
              onChanged: (v) => setState(() => availability = v.toString()),
              title: const Text("Full Time"),
            ),

            RadioListTile(
              value: "Part Time",
              groupValue: availability,
              onChanged: (v) => setState(() => availability = v.toString()),
              title: const Text("Part Time"),
            ),

            RadioListTile(
              value: "Night Care",
              groupValue: availability,
              onChanged: (v) => setState(() => availability = v.toString()),
              title: const Text("Night Care"),
            ),

            const SizedBox(height: 20),

            primaryButton(
              loading ? "Please wait..." : "Continue",
              availability.isEmpty || loading ? null : finishSetup,
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  /* ---------------- BUILD ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: Column(
        children: [
          appHeader(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  progressBar(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: buildStep(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}