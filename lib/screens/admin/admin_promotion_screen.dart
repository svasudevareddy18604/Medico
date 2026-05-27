import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminPromotionScreen extends StatefulWidget {
  const AdminPromotionScreen({super.key});
  @override
  State<AdminPromotionScreen> createState() => _AdminPromotionScreenState();
}

class _AdminPromotionScreenState extends State<AdminPromotionScreen> {
  List _promos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(Api.adminPromotions));
      if (res.statusCode == 200) setState(() => _promos = jsonDecode(res.body));
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Promotion?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This promotion will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await http.delete(Uri.parse(Api.deletePromotion(id)));
      _fetch();
      _toast('Promotion deleted');
    }
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

  void _openSheet({Map? edit}) {
    final titleCtrl = TextEditingController(text: edit?['title']?.toString() ?? '');
    File? image;
    File? video;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (_, ss) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Center(child: Text(edit != null ? 'Edit Promotion' : 'New Promotion',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),

            // Title field
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: 'Title (optional)',
                filled: true, fillColor: Colors.grey.shade100,
                prefixIcon: const Icon(Icons.campaign_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),

            // Media preview
            if (image != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(12),
                child: Image.file(image!, height: 140, width: double.infinity, fit: BoxFit.cover)),
              const SizedBox(height: 10),
            ] else if (edit?['media'] != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(12),
                child: Image.network(Api.imageBase + edit!['media'],
                  height: 140, width: double.infinity, fit: BoxFit.cover)),
              const SizedBox(height: 10),
            ],

            if (video != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: const Row(children: [
                  Icon(Icons.videocam_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Video selected', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                ]),
              ),

            const SizedBox(height: 10),

            // Media buttons
            Row(children: [
              Expanded(child: _mediaBtn(Icons.image_outlined, 'Image', () async {
                final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (p != null) ss(() { image = File(p.path); video = null; });
              })),
              const SizedBox(width: 10),
              Expanded(child: _mediaBtn(Icons.videocam_outlined, 'Video', () async {
                final p = await ImagePicker().pickVideo(source: ImageSource.gallery);
                if (p != null) ss(() { video = File(p.path); image = null; });
              })),
            ]),
            const SizedBox(height: 20),

            // Save button
            GestureDetector(
              onTap: () async {
                final req = http.MultipartRequest(
                  edit == null ? 'POST' : 'PUT',
                  Uri.parse(edit == null ? Api.adminPromotions : Api.updatePromotion(edit['id'])));
                req.fields['title'] = titleCtrl.text.trim();
                if (image != null) req.files.add(await http.MultipartFile.fromPath('media', image!.path));
                if (video != null) req.files.add(await http.MultipartFile.fromPath('media', video!.path));
                final s = await req.send();
                if (!mounted) return;
                Navigator.pop(context);
                if (s.statusCode == 200) {
                  _fetch();
                  _toast(edit == null ? 'Promotion created ✓' : 'Promotion updated ✓');
                } else {
                  _toast('Something went wrong', isError: true);
                }
              },
              child: Container(
                height: 52, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(edit != null ? Icons.save_rounded : Icons.add_circle_outline_rounded,
                    color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(edit != null ? 'Update Promotion' : 'Add Promotion',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ])),
              ),
            ),
          ]),
        )),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primary.withOpacity(0.04)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      onPressed: _openSheet,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('New Promo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [

      // Header
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 28),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28))),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Promotions',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('${_promos.length} active promotion${_promos.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ]),
      ),

      // Body
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _promos.isEmpty ? _emptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetch,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _promos.length,
                itemBuilder: (_, i) => _promoCard(_promos[i]),
              ),
            ),
      ),
    ]),
  );

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
      child: Icon(Icons.campaign_outlined, size: 54, color: AppColors.primary.withOpacity(0.6)),
    ),
    const SizedBox(height: 20),
    const Text('No Promotions Yet',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
    const SizedBox(height: 8),
    Text('Add banners or videos to promote\nyour services to users.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
    const SizedBox(height: 28),
    GestureDetector(
      onTap: _openSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Create First Promotion',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    ),
  ]));

  Widget _promoCard(Map p) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p['media'] != null)
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Image.network(Api.imageBase + p['media'],
            height: 170, width: double.infinity, fit: BoxFit.cover),
        )
      else
        Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: const Center(child: Icon(Icons.image_not_supported_outlined,
            color: Colors.white54, size: 32)),
        ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p['title'] != null && p['title'].toString().isNotEmpty) ...[
            Text(p['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
          ],
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _actionBtn(Icons.edit_outlined, 'Edit', Colors.blueGrey, () => _openSheet(edit: p)),
            const SizedBox(width: 8),
            _actionBtn(Icons.delete_outline_rounded, 'Delete', Colors.red, () => _delete(p['id'])),
          ]),
        ]),
      ),
    ]),
  );

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
}