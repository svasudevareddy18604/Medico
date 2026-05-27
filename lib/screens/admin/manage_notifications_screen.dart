import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class ManageNotificationsScreen extends StatefulWidget {
  const ManageNotificationsScreen({super.key});
  @override
  State<ManageNotificationsScreen> createState() => _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  List _notifications = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse(Api.adminNotifications));
      if (res.statusCode == 200)
        setState(() { _notifications = jsonDecode(res.body); _loading = false; });
      else setState(() => _loading = false);
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Notification?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will cancel the scheduled notification.'),
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
      await http.delete(Uri.parse(Api.deleteNotification(id)));
      _fetch();
      _toast('Notification deleted');
    }
  }

  Future<void> _sendNow(int id) async {
    final res = await http.post(Uri.parse('${Api.adminNotifications}/$id/send-now'));
    if (!mounted) return;
    _toast(res.statusCode == 200 ? 'Notification sent ✓' : 'Failed to send', isError: res.statusCode != 200);
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

  String _fmt(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return "${dt.day}/${dt.month}/${dt.year}  $h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) { return raw; }
  }

  Color _audienceColor(String a) =>
    a == 'ALL' ? Colors.indigo : a == 'CARESEEKERS' ? Colors.teal : Colors.orange;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      onPressed: _openSheet,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const Text('Notifications',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('${_notifications.length} scheduled',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ]),
      ),

      // Body
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty ? _emptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetch,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _notifications.length,
                itemBuilder: (_, i) => _notifCard(_notifications[i]),
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
      child: Icon(Icons.notifications_none_rounded, size: 54, color: AppColors.primary.withOpacity(0.6)),
    ),
    const SizedBox(height: 20),
    const Text('No Notifications Yet',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
    const SizedBox(height: 8),
    Text('Schedule push notifications to\nreach your users at the right time.',
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
          Text('Schedule First Notification',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    ),
  ]));

  Widget _notifCard(Map n) {
    final sent     = n['sent'] == 1;
    final audience = n['audience']?.toString() ?? 'ALL';
    final aColor   = _audienceColor(audience);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top strip
        Container(height: 5,
          decoration: BoxDecoration(
            gradient: sent ? const LinearGradient(colors: [Colors.green, Colors.lightGreen])
              : AppColors.gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)))),

        if (n['image_url'] != null)
          ClipRRect(
            child: Image.network(n['image_url'],
              height: 160, width: double.infinity, fit: BoxFit.cover)),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              // Audience badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: aColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: aColor.withOpacity(0.25))),
                child: Text(
                  audience == 'CARESEEKERS' ? 'Seekers'
                    : audience == 'CAREGIVERS' ? 'Givers' : 'All',
                  style: TextStyle(fontSize: 11, color: aColor, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(n['message'] ?? '',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(_fmt(n['scheduled_at'] ?? ''),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: sent ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sent ? Colors.green.shade200 : Colors.orange.shade200)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sent ? Colors.green : Colors.orange)),
                  const SizedBox(width: 5),
                  Text(sent ? 'Sent' : 'Pending',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: sent ? Colors.green.shade700 : Colors.orange.shade700)),
                ]),
              ),
            ]),
            Divider(height: 18, color: Colors.grey.shade100),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (!sent) ...[
                _actionBtn(Icons.send_rounded, 'Send Now', AppColors.primary, () => _sendNow(n['id'])),
                const SizedBox(width: 8),
              ],
              _actionBtn(Icons.edit_outlined, 'Edit', Colors.blueGrey, () => _openSheet(data: n)),
              const SizedBox(width: 8),
              _actionBtn(Icons.delete_outline_rounded, 'Delete', Colors.red, () => _delete(n['id'])),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

  void _openSheet({Map? data}) {
    final titleCtrl   = TextEditingController(text: data?['title']?.toString() ?? '');
    final messageCtrl = TextEditingController(text: data?['message']?.toString() ?? '');
    String audience   = data?['audience']?.toString() ?? 'ALL';
    File? pickedImage;
    DateTime? scheduledAt = data != null
      ? DateTime.tryParse(data['scheduled_at']?.toString() ?? '')?.toLocal() : null;

    final offset  = DateTime.now().timeZoneOffset;
    final tzLabel = "UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs().toString().padLeft(2, '0')}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => StatefulBuilder(builder: (_, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Center(child: Text(data == null ? 'New Notification' : 'Edit Notification',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),

            _sheetField(titleCtrl, 'Title', Icons.title_rounded),
            const SizedBox(height: 10),
            _sheetField(messageCtrl, 'Message', Icons.message_outlined, maxLines: 3),
            const SizedBox(height: 14),

            // Audience selector
            Text('Send To', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: ['ALL', 'CARESEEKERS', 'CAREGIVERS'].map((a) {
              final selected = audience == a;
              final color = _audienceColor(a);
              return Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => ss(() => audience = a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? color : Colors.grey.shade200)),
                    child: Center(child: Text(
                      a == 'ALL' ? 'All' : a == 'CARESEEKERS' ? 'Seekers' : 'Givers',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Colors.black54))),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // Image picker
            GestureDetector(
              onTap: () async {
                final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (p != null) ss(() => pickedImage = File(p.path));
              },
              child: Container(
                height: (pickedImage != null || data?['image_url'] != null) ? 150 : 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pickedImage != null
                    ? AppColors.primary : Colors.grey.shade300)),
                child: pickedImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.file(pickedImage!, fit: BoxFit.cover))
                  : data?['image_url'] != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14),
                        child: Image.network(data!['image_url'], fit: BoxFit.cover))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.grey.shade400, size: 28),
                        const SizedBox(height: 4),
                        Text('Tap to add image (optional)',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ]),
              ),
            ),
            const SizedBox(height: 12),

            // Date/Time picker
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: scheduledAt ?? DateTime.now().add(const Duration(minutes: 5)),
                  firstDate: DateTime.now(), lastDate: DateTime(2100));
                if (d == null) return;
                final t = await showTimePicker(context: context,
                  initialTime: scheduledAt != null
                    ? TimeOfDay.fromDateTime(scheduledAt!) : TimeOfDay.now());
                if (t == null) return;
                ss(() => scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: scheduledAt != null
                    ? AppColors.primary.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheduledAt != null
                    ? AppColors.primary.withOpacity(0.4) : Colors.grey.shade300)),
                child: Row(children: [
                  Icon(Icons.schedule_rounded,
                    color: scheduledAt != null ? AppColors.primary : Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: scheduledAt != null
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_fmt(scheduledAt!.toIso8601String()),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Timezone: $tzLabel',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      ])
                    : Text('Pick Schedule Date & Time',
                        style: TextStyle(color: Colors.grey.shade400))),
                  Icon(Icons.chevron_right_rounded,
                    color: scheduledAt != null ? AppColors.primary : Colors.grey),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            GestureDetector(
              onTap: scheduledAt == null ? null : () async {
                if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                  _toast('Title and message are required', isError: true);
                  return;
                }
                final req = http.MultipartRequest(
                  data == null ? 'POST' : 'PUT',
                  Uri.parse(data == null
                    ? Api.adminNotifications : Api.updateNotification(data['id'])));
                req.fields['title']        = titleCtrl.text.trim();
                req.fields['message']      = messageCtrl.text.trim();
                req.fields['audience']     = audience;
                req.fields['scheduled_at'] = scheduledAt!.toUtc().toIso8601String();
                req.fields['timezone']     = tzLabel;
                if (pickedImage != null)
                  req.files.add(await http.MultipartFile.fromPath('image', pickedImage!.path));
                await req.send();
                if (!mounted) return;
                Navigator.pop(context);
                _fetch();
                _toast(data == null ? 'Notification scheduled ✓' : 'Notification updated ✓');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: scheduledAt != null ? AppColors.gradient : null,
                  color: scheduledAt == null ? Colors.grey.shade200 : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: scheduledAt != null
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 12, offset: const Offset(0, 4))] : []),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(data != null ? Icons.save_rounded : Icons.schedule_send_rounded,
                    color: scheduledAt != null ? Colors.white : Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Text(data == null ? 'Schedule Notification' : 'Update & Reschedule',
                    style: TextStyle(
                      color: scheduledAt != null ? Colors.white : Colors.grey,
                      fontSize: 15, fontWeight: FontWeight.bold)),
                ])),
              ),
            ),
          ]),
        ),
      )),
    );
  }

  Widget _sheetField(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) =>
    TextField(
      controller: c, maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true, fillColor: Colors.grey.shade100,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
}