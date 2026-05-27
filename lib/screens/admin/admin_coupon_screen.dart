import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminCouponScreen extends StatefulWidget {
  const AdminCouponScreen({super.key});
  @override
  State<AdminCouponScreen> createState() => _AdminCouponScreenState();
}

class _AdminCouponScreenState extends State<AdminCouponScreen> {
  List _coupons = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse(Api.adminCoupons));
      final data = jsonDecode(res.body);
      if (mounted) setState(() { _coupons = data['data'] ?? []; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save(Map<String, String> fields, File? newImage, {int? id}) async {
    try {
      if (id != null && newImage == null) {
        final res = await http.put(Uri.parse('${Api.adminCoupons}/$id'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode(fields));
        if (res.statusCode == 200) { _fetch(); _toast("Coupon updated ✓"); }
      } else {
        final url = id != null ? '${Api.adminCoupons}/$id' : Api.adminCoupons;
        final req = http.MultipartRequest(id != null ? 'PUT' : 'POST', Uri.parse(url));
        req.fields.addAll(fields);
        if (newImage != null) req.files.add(await http.MultipartFile.fromPath('image', newImage.path));
        final s = await req.send();
        if (s.statusCode == 200) { _fetch(); _toast(id != null ? "Coupon updated ✓" : "Coupon created ✓"); }
      }
    } catch (_) { _toast("Something went wrong", isError: true); }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Coupon?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This coupon will be permanently removed.'),
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
      await http.delete(Uri.parse('${Api.adminCoupons}/$id'));
      _fetch();
      _toast("Coupon deleted");
    }
  }

  Future<void> _toggleStatus(int id) async {
    await http.patch(Uri.parse('${Api.adminCoupons}/$id/status'));
    _fetch();
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

  void _openSheet({Map? coupon}) {
    final id       = coupon?['id'] as int?;
    final title    = TextEditingController(text: coupon?['title']?.toString() ?? '');
    final code     = TextEditingController(text: coupon?['code']?.toString() ?? '');
    final discount = TextEditingController(text: coupon?['discount']?.toString() ?? '');
    final minOrder = TextEditingController(text: coupon?['min_order']?.toString() ?? '');
    String discType = coupon?['discount_type'] == 'flat' ? 'flat' : 'percentage';
    bool firstOrder = (coupon?['is_first_order'] ?? 0) == 1;
    File? newImage;

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
            Center(child: Text(id != null ? 'Edit Coupon' : 'New Coupon',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            _field(title,    'Coupon Title'),
            _field(code,     'Code  (e.g. SUMMER50)'),
            _field(discount, 'Discount Amount', type: TextInputType.number),
            _field(minOrder, 'Minimum Order  (₹)', type: TextInputType.number),
            DropdownButtonFormField<String>(
              value: discType,
              decoration: _deco('Discount Type'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('% Percentage')),
                DropdownMenuItem(value: 'flat',       child: Text('₹ Flat Amount')),
              ],
              onChanged: (v) => ss(() => discType = v!),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: const Text('First Order Only', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text('Apply only to user\'s first booking',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                value: firstOrder,
                activeColor: AppColors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                onChanged: (v) => ss(() => firstOrder = v),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) ss(() => newImage = File(picked.path));
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: newImage != null ? AppColors.primary : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: newImage != null ? AppColors.primary.withOpacity(0.05) : Colors.grey.shade50,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(newImage != null ? Icons.check_circle_rounded : Icons.image_outlined,
                    color: newImage != null ? AppColors.primary : Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(newImage != null ? 'Image selected' : 'Upload Image (optional)',
                    style: TextStyle(color: newImage != null ? AppColors.primary : Colors.grey,
                      fontWeight: FontWeight.w500, fontSize: 13)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                if (code.text.trim().isEmpty || discount.text.trim().isEmpty) {
                  _toast("Code and Discount are required", isError: true);
                  return;
                }
                Navigator.pop(context);
                _save({
                  'title':         title.text.trim(),
                  'code':          code.text.trim().toUpperCase(),
                  'discount':      discount.text.trim(),
                  'discount_type': discType,
                  'min_order':     minOrder.text.trim().isEmpty ? '0' : minOrder.text.trim(),
                  'is_first_order': firstOrder ? '1' : '0',
                }, newImage, id: id);
              },
              child: Container(
                height: 52, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(id != null ? Icons.save_rounded : Icons.add_circle_outline_rounded,
                    color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(id != null ? 'Update Coupon' : 'Create Coupon',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ])),
              ),
            ),
          ]),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _openSheet,
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('New Coupon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [

      // Header
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 28),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
        ),
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
            const Text('Coupons',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('${_coupons.length} coupon${_coupons.length == 1 ? '' : 's'} total',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ]),
      ),

      // Body
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _coupons.isEmpty
            ? _emptyState()
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _fetch,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _coupons.length,
                  itemBuilder: (_, i) => _CouponCard(
                    coupon: _coupons[i],
                    onEdit:   () => _openSheet(coupon: _coupons[i]),
                    onDelete: () => _delete(_coupons[i]['id']),
                    onToggle: () => _toggleStatus(_coupons[i]['id']),
                  ),
                ),
              ),
      ),
    ]),
  );

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        shape: BoxShape.circle),
      child: Icon(Icons.local_offer_outlined, size: 54, color: AppColors.primary.withOpacity(0.6)),
    ),
    const SizedBox(height: 20),
    const Text('No Coupons Yet',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
    const SizedBox(height: 8),
    Text('Create your first coupon to offer\ndiscounts to your users.',
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
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Create First Coupon',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    ),
  ]));

  Widget _field(TextEditingController c, String hint, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, keyboardType: type, decoration: _deco(hint)),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

/* ══════════════════════════════════════════
   Coupon Card
══════════════════════════════════════════ */
class _CouponCard extends StatelessWidget {
  final Map coupon;
  final VoidCallback onEdit, onDelete, onToggle;
  const _CouponCard({required this.coupon, required this.onEdit,
    required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active    = coupon['is_active'] == 1;
    final isPercent = coupon['discount_type'] == 'percentage';
    final title     = coupon['title']?.toString().isNotEmpty == true
        ? coupon['title'] : coupon['code'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [

        // Top colour strip
        Container(
          height: 5,
          decoration: BoxDecoration(
            gradient: active ? AppColors.gradient
              : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade300]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(children: [
              // Discount badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.gradient : null,
                  color: active ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(
                  isPercent ? "${coupon['discount']}% OFF" : "₹${coupon['discount']} OFF",
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey.shade500,
                    fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? Colors.green.shade200 : Colors.red.shade200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.green : Colors.red)),
                    const SizedBox(width: 5),
                    Text(active ? 'Active' : 'Disabled',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: active ? Colors.green.shade700 : Colors.red.shade700)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.local_offer_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(coupon['code'] ?? '',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 0.5)),
            ]),

            const SizedBox(height: 10),

            Wrap(spacing: 6, runSpacing: 6, children: [
              if (coupon['is_first_order'] == 1) _tag('🎉 First Order', Colors.purple),
              if ((coupon['min_order'] ?? 0) > 0) _tag('Min ₹${coupon['min_order']}', Colors.orange),
              if ((coupon['min_services'] ?? 0) > 0) _tag('${coupon['min_services']} Services', Colors.blue),
              if (coupon['category'] != null && coupon['category'].toString().isNotEmpty)
                _tag(coupon['category'], Colors.teal),
            ]),

            if (coupon['end_time'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Expires ${coupon['end_time'].toString().substring(0, 10)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ]),
            ],

            Divider(height: 20, color: Colors.grey.shade100),

            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _actionBtn(Icons.edit_outlined, 'Edit', Colors.blueGrey, onEdit),
              const SizedBox(width: 6),
              _actionBtn(Icons.delete_outline_rounded, 'Delete', Colors.red, onDelete),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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