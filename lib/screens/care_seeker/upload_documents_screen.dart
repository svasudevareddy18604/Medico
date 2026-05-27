import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';
import 'payment_screen.dart';

class UploadDocumentsScreen extends StatefulWidget {
  final int userId;
  final List cartItems;
  final double subtotal, serviceCharge, discount;
  final String couponCode, slot, date, location;
  final double? latitude, longitude;

  const UploadDocumentsScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.subtotal,
    required this.serviceCharge,
    required this.discount,
    required this.couponCode,
    required this.slot,
    required this.date,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen>
    with SingleTickerProviderStateMixin {

  bool _loading = false;
  bool _alreadyUploaded = false;
  List<File> _selectedFiles = [];
  List _uploadedDocs = [];

  late final AnimationController _pulseCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final Animation<double> _pulseAnim =
      Tween<double>(begin: 1.0, end: 1.06)
          .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  double get _finalTotal =>
      (widget.subtotal + widget.serviceCharge - widget.discount)
          .clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _checkExistingDocuments();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────────────────────────

  Future<void> _checkExistingDocuments() async {
    try {
      for (final item in widget.cartItems) {
        final res = await http.get(Uri.parse(
            "${Api.baseUrl}/documents/pending/${widget.userId}/${item["service_id"]}"));
        final data = jsonDecode(res.body);
        if (res.statusCode == 200 && data["already_uploaded"] == true) {
          if (!mounted) return;
          setState(() {
            _alreadyUploaded = true;
            _uploadedDocs = data["documents"] ?? [];
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("CHECK DOC ERROR: $e");
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "webp", "pdf"],
    );
    if (result != null) {
      setState(() => _selectedFiles = result.paths.map((e) => File(e!)).toList());
    }
  }

  Future<void> _uploadDocuments() async {
    if (_selectedFiles.isEmpty) {
      _toast("Please select at least one document", _ToastType.error);
      return;
    }
    setState(() => _loading = true);
    try {
      for (final item in widget.cartItems) {
        final req = http.MultipartRequest("POST", Uri.parse(Api.uploadDocuments))
          ..fields["user_id"] = widget.userId.toString()
          ..fields["service_id"] = item["service_id"].toString()
          ..fields["document_key"] = "prescription";
        for (final file in _selectedFiles) {
          req.files.add(await http.MultipartFile.fromPath("documents", file.path));
        }
        final res = await req.send();
        final data = jsonDecode(await res.stream.bytesToString());
        if (res.statusCode != 200 || data["success"] != true) {
          throw Exception(data["message"] ?? "Upload failed");
        }
        _uploadedDocs.addAll(data["documents"]);
      }
      _toast("Documents uploaded successfully", _ToastType.success);
      if (mounted) _goToPayment();
    } catch (e) {
      _toast(e.toString().replaceAll("Exception: ", ""), _ToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPayment() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            userId: widget.userId,
            cartItems: widget.cartItems,
            subtotal: widget.subtotal,
            serviceCharge: widget.serviceCharge,
            discount: widget.discount,
            couponCode: widget.couponCode,
            slot: widget.slot,
            date: widget.date,
            location: widget.location,
            latitude: widget.latitude,
            longitude: widget.longitude,
          ),
        ),
      );

  void _toast(String msg, _ToastType type) {
    if (!mounted) return;
    final (color, icon, title) = switch (type) {
      _ToastType.success => (const Color(0xFF00875A), Icons.check_circle_rounded, "Success"),
      _ToastType.error   => (const Color(0xFFD32F2F), Icons.error_rounded,        "Error"),
      _ToastType.info    => (const Color(0xFF1565C0), Icons.info_rounded,          "Info"),
      _ToastType.warn    => (const Color(0xFFE65100), Icons.warning_rounded,       "Warning"),
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 100,
        ),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 1),
                Text(msg, style: const TextStyle(color: Color(0xFF374151), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            )),
          ]),
        ),
      ));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Column(children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _infoChips(),
                const SizedBox(height: 16),
                _warningBanner(),
                const SizedBox(height: 20),
                _dropZone(),
                const SizedBox(height: 20),
                if (_selectedFiles.isNotEmpty) ...[
                  _sectionLabel("Selected Files (${_selectedFiles.length})"),
                  const SizedBox(height: 10),
                  ..._selectedFiles.asMap().entries.map((e) => _fileCard(e.value, e.key)),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ]),
        bottomNavigationBar: _bottomCTA(),
      );

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                  ),
                ),
                const SizedBox(width: 12),
                // Icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                    child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Upload Medical Docs",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_alreadyUploaded || _selectedFiles.isNotEmpty) ? 0.55 : 0.12,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
            ]),
          ),
        ),
      );

  // ── Info chips ───────────────────────────────────────────────────────────

  Widget _infoChips() {
    String trunc(String s, int max) => s.length > max ? "${s.substring(0, max)}…" : s;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _chip(Icons.calendar_today_rounded, widget.date),
      _chip(Icons.access_time_rounded, widget.slot),
      _chip(Icons.location_on_rounded, trunc(widget.location, 18)),
    ]);
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      );

  // ── Warning banner ───────────────────────────────────────────────────────

  Widget _warningBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE53935).withOpacity(0.35), width: 1.2),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                "Important: Upload Valid Prescription",
                style: TextStyle(
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Please ensure you upload a clear, legible, and valid prescription issued by a licensed medical professional. Incorrect or illegible documents may delay or cancel your service. Patient safety is our top priority.",
                style: TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
        ]),
      );

  // ── Drop zone ────────────────────────────────────────────────────────────

  Widget _dropZone() {
    final ready = _alreadyUploaded || _selectedFiles.isNotEmpty;
    final color = _alreadyUploaded ? Colors.green : AppColors.primary;
    return GestureDetector(
      onTap: _alreadyUploaded ? null : _pickDocuments,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: ready ? color.withOpacity(0.7) : AppColors.primary.withOpacity(0.25),
            width: 1.8,
          ),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          Stack(alignment: Alignment.center, children: [
            Container(width: 74, height: 74, decoration: BoxDecoration(color: color.withOpacity(0.06), shape: BoxShape.circle)),
            Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withOpacity(0.11), shape: BoxShape.circle)),
            Icon(
              _alreadyUploaded
                  ? Icons.check_circle_rounded
                  : _selectedFiles.isEmpty
                      ? Icons.upload_file_rounded
                      : Icons.add_circle_rounded,
              size: 32, color: color,
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            _alreadyUploaded
                ? "Documents Already Uploaded"
                : _selectedFiles.isEmpty
                    ? "Tap to Select Files"
                    : "Tap to Add More Files",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            _alreadyUploaded ? "You can proceed to payment" : "JPG  ·  PNG  ·  WEBP  ·  PDF",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, letterSpacing: 0.4),
          ),
          if (!_alreadyUploaded && _selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(
                "${_selectedFiles.length} file${_selectedFiles.length > 1 ? 's' : ''} selected",
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── File card ────────────────────────────────────────────────────────────

  Widget _fileCard(File file, int index) {
    final name = file.path.split("/").last;
    final isPdf = name.toLowerCase().endsWith(".pdf");
    final clr = isPdf ? Colors.red : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: clr.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: clr, size: 20),
            Text(name.split(".").last.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: clr)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(isPdf ? "PDF Document" : "Image File",
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
        ])),
        GestureDetector(
          onTap: () => setState(() => _selectedFiles.removeAt(index)),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.red, size: 15),
          ),
        ),
      ]),
    );
  }

  // ── Section label ────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
      ]);

  // ── Bottom CTA ───────────────────────────────────────────────────────────

  Widget _bottomCTA() {
    final ctaBg = _alreadyUploaded ? Colors.green : AppColors.primary;
    final ctaIcon = _alreadyUploaded
        ? Icons.check_circle_rounded
        : _selectedFiles.isEmpty
            ? Icons.folder_open_rounded
            : Icons.lock_rounded;
    final ctaLabel = _alreadyUploaded
        ? "Documents Uploaded — Continue"
        : _selectedFiles.isEmpty
            ? "Select Documents to Continue"
            : "Upload & Continue to Payment";

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Total Amount",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          Text("₹${_finalTotal.toStringAsFixed(0)}",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _alreadyUploaded ? _goToPayment : _uploadDocuments,
            style: ElevatedButton.styleFrom(
              backgroundColor: ctaBg,
              disabledBackgroundColor: ctaBg.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(ctaIcon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(ctaLabel,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
          ),
        ),
        const SizedBox(height: 7),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.shield_rounded, size: 11, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text("Your documents are encrypted & secure",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      ]),
    );
  }
}

enum _ToastType { success, error, info, warn }