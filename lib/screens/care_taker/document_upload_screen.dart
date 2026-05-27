// 🔥 FINAL VERSION WITH OCR VALIDATION (AADHAAR + PAN)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'pending_approval_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  final int userId;
  final String caregiverType;

  const DocumentUploadScreen({
    super.key,
    required this.userId,
    required this.caregiverType,
  });

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {

  
  final ImagePicker picker = ImagePicker();

  File? aadhaarFront;
  File? aadhaarBack;
  File? panCard;
  File? certificate;

  bool loading = false;

  bool get certificateRequired {
    return widget.caregiverType == "Nurse" ||
        widget.caregiverType == "Physiotherapy";
  }

  /* ================= OCR VALIDATION ================= */

  Future<String> extractText(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer();

    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    await textRecognizer.close();

    return recognizedText.text.toLowerCase();
  }

  bool isValidAadhaar(String text) {
    bool hasNumber =
        RegExp(r'\d{4}\s?\d{4}\s?\d{4}').hasMatch(text);

    bool hasKeyword =
        text.contains("government of india") ||
        text.contains("uidai") ||
        text.contains("aadhaar");

    return hasNumber && hasKeyword;
  }

  bool isValidPAN(String text) {
    bool hasPanPattern =
        RegExp(r'[A-Z]{5}[0-9]{4}[A-Z]').hasMatch(text.toUpperCase());

    bool hasKeyword =
        text.contains("income tax") ||
        text.contains("permanent account number") ||
        text.contains("pan");

    return hasPanPattern && hasKeyword;
  }

  /* ================= PICK IMAGE ================= */

  Future<void> pickImage({
    required Function(File) setFile,
    required String type, // aadhaar / pan / certificate
  }) async {

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    File file = File(image.path);

    String text = await extractText(file);

    // 🔥 VALIDATION
    if (type == "aadhaar") {
      if (!isValidAadhaar(text)) {
        showMsg("Upload valid Aadhaar card");
        return;
      }
    }

    if (type == "pan") {
      if (!isValidPAN(text)) {
        showMsg("Upload valid PAN card");
        return;
      }
    }

    setState(() => setFile(file));
  }

  /* ================= UI CARD ================= */

  Widget uploadCard({
    required String title,
    required File? file,
    required bool requiredDoc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file == null ? Colors.grey.shade300 : AppColors.primary,
          ),
        ),
        child: Row(
          children: [

            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: file == null
                  ? Icon(Icons.upload_file, color: AppColors.primary)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),

                  const SizedBox(height: 4),

                  Text(
                    file == null ? "Tap to upload" : "Uploaded ✓",
                    style: TextStyle(
                      color: file == null ? Colors.grey : AppColors.primary,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  /* ================= SUBMIT ================= */

  Future<void> submitDocuments() async {

    if (aadhaarFront == null ||
        aadhaarBack == null ||
        panCard == null) {
      showMsg("Upload all required documents");
      return;
    }

    if (certificateRequired && certificate == null) {
      showMsg("Certificate required");
      return;
    }

    try {

      setState(() => loading = true);

      FormData formData = FormData.fromMap({

        "user_id": widget.userId,

        "aadhaar_front": await MultipartFile.fromFile(aadhaarFront!.path),
        "aadhaar_back": await MultipartFile.fromFile(aadhaarBack!.path),
        "pan_card": await MultipartFile.fromFile(panCard!.path),

        if (certificate != null)
          "certificate": await MultipartFile.fromFile(certificate!.path),
      });

      final res = await Dio().post(
        Api.caretakerUploadDocuments,
        data: formData,
      );

      if (res.data["success"] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PendingApprovalScreen(),
          ),
        );
      } else {
        showMsg("Upload failed");
      }

    } catch (e) {
      showMsg("Error uploading");
    }

    setState(() => loading = false);
  }

  void showMsg(String msg){
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ================= UI ================= */
@override
Widget build(BuildContext context) {

  return Scaffold(
    backgroundColor: const Color(0xFFF4F6F8),

    body: Column(
      children: [

        // 🔥 UPDATED HEADER
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Row(
            children: [

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  "Upload Documents",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            ],
          ),
        ),

        // 🔥 BODY
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [

                uploadCard(
                  title: "Aadhaar Front",
                  file: aadhaarFront,
                  requiredDoc: true,
                  onTap: () => pickImage(
                    setFile: (f) => aadhaarFront = f,
                    type: "aadhaar",
                  ),
                ),

                uploadCard(
                  title: "Aadhaar Back",
                  file: aadhaarBack,
                  requiredDoc: true,
                  onTap: () => pickImage(
                    setFile: (f) => aadhaarBack = f,
                    type: "aadhaar",
                  ),
                ),

                uploadCard(
                  title: "PAN Card",
                  file: panCard,
                  requiredDoc: true,
                  onTap: () => pickImage(
                    setFile: (f) => panCard = f,
                    type: "pan",
                  ),
                ),

                uploadCard(
                  title: "Certificate",
                  file: certificate,
                  requiredDoc: certificateRequired,
                  onTap: () => pickImage(
                    setFile: (f) => certificate = f,
                    type: "certificate",
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // 🔥 BUTTON
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: loading ? null : submitDocuments,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit"),
            ),
          ),
        )

      ],
    ),
  );
}}