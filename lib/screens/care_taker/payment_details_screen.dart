import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final int userId;
  const PaymentDetailsScreen({super.key, required this.userId});
  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upi = TextEditingController();
  final _acc = TextEditingController();
  final _ifsc = TextEditingController();
  final _name = TextEditingController();

  String _type = "UPI";
  bool _loading = false;
  List _list = [];
  int? _editId;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/caretaker/payment-details/${widget.userId}"));
      final d = jsonDecode(res.body);
      if (res.statusCode == 200 && d["success"] == true) {
        setState(() => _list = d["data"]);
      } else {
        _toast("Failed to load", isError: true);
      }
    } catch (_) { _toast("Fetch failed", isError: true); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final body = jsonEncode({"user_id": widget.userId, "type": _type, "upi_id": _upi.text, "account_number": _acc.text, "ifsc_code": _ifsc.text, "account_name": _name.text});
    try {
      final res = _editId == null
          ? await http.post(Uri.parse("${Api.baseUrl}/caretaker/payment-details"), headers: {"Content-Type": "application/json"}, body: body)
          : await http.put(Uri.parse("${Api.baseUrl}/caretaker/payment-details/$_editId"), headers: {"Content-Type": "application/json"}, body: body);
      if (res.statusCode == 200) { _clear(); _fetch(); _toast(_editId == null ? "Payment method added!" : "Updated successfully!"); }
      else {
        _toast("Save failed", isError: true);
      }
    } catch (_) { _toast("Error saving", isError: true); }
    setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    await http.delete(Uri.parse("${Api.baseUrl}/caretaker/payment-details/$id"));
    _fetch(); _toast("Removed successfully");
  }

  Future<void> _setPrimary(int id) async {
    await http.patch(Uri.parse("${Api.baseUrl}/caretaker/payment-details/$id/primary"));
    _fetch(); _toast("Set as primary ⭐");
  }

  void _edit(dynamic item) => setState(() {
    _editId = item["id"]; _type = item["type"];
    _upi.text = item["upi_id"] ?? ""; _acc.text = item["account_number"] ?? "";
    _ifsc.text = item["ifsc_code"] ?? ""; _name.text = item["account_name"] ?? "";
  });

  void _clear() => setState(() { _editId = null; _upi.clear(); _acc.clear(); _ifsc.clear(); _name.clear(); });

  void _toast(String msg, {bool isError = false}) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => _ToastWidget(msg: msg, isError: isError));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
    filled: true, fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary, width: 1.8)),
  );

  Widget _typeChip(String label, IconData icon) {
    final sel = _type == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: sel ? AppColors.gradient : null,
            color: sel ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? Colors.transparent : Colors.grey.shade300),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: sel ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey.shade700)),
          ]),
        ),
      ),
    );
  }

  Widget _card(dynamic item) {
    final isUpi = item["type"] == "UPI";
    final isPrimary = item["is_primary"] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? AppColors.primary.withOpacity(0.4) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: isUpi ? AppColors.gradient : const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(isUpi ? Icons.qr_code : Icons.account_balance, color: Colors.white, size: 20),
        ),
        title: Text(
          isUpi ? (item["upi_id"] ?? "") : (item["account_number"] ?? ""),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(children: [
          Text(item["type"], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          if (isPrimary) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
              child: Text("Primary", style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _iconBtn(Icons.star_rounded, isPrimary ? Colors.amber : Colors.grey.shade400, () => _setPrimary(item["id"])),
          _iconBtn(Icons.edit_rounded, AppColors.primary, () => _edit(item)),
          _iconBtn(Icons.delete_rounded, Colors.red.shade400, () => _delete(item["id"])),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(left: 4),
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 17, color: color),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(children: [
        // ── Curved Header ──────────────────────────────────────────────────
        Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16)),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Payment Details", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("Manage your payment methods", style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
                  ]),
                  const Spacer(),
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ]),

        // ── Body ──────────────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 32), child: Column(children: [
          // List
          if (_list.isNotEmpty) ...[
            Align(alignment: Alignment.centerLeft,
              child: Text("Saved Methods", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade700))),
            const SizedBox(height: 10),
            ..._list.map(_card),
            const SizedBox(height: 8),
          ],

          // Form card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.add_card_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(_editId == null ? "Add Payment Method" : "Edit Payment Method",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (_editId != null) GestureDetector(
                  onTap: _clear,
                  child: Text("Cancel", style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 16),

              // Type selector
              Row(children: [
                _typeChip("UPI", Icons.qr_code_rounded),
                const SizedBox(width: 10),
                _typeChip("BANK", Icons.account_balance_rounded),
              ]),
              const SizedBox(height: 16),

              if (_type == "UPI")
                TextFormField(
                  controller: _upi,
                  decoration: _inputDec("UPI ID (e.g. name@upi)", Icons.alternate_email),
                  validator: (v) => v!.contains("@") ? null : "Enter valid UPI ID",
                )
              else ...[
                TextFormField(controller: _name, decoration: _inputDec("Account Holder Name", Icons.person_outline_rounded),
                    validator: (v) => v!.isNotEmpty ? null : "Required"),
                const SizedBox(height: 12),
                TextFormField(controller: _acc, decoration: _inputDec("Account Number", Icons.tag_rounded), keyboardType: TextInputType.number,
                    validator: (v) => v!.isNotEmpty ? null : "Required"),
                const SizedBox(height: 12),
                TextFormField(controller: _ifsc, decoration: _inputDec("IFSC Code", Icons.code_rounded), textCapitalization: TextCapitalization.characters,
                    validator: (v) => v!.length >= 11 ? null : "Enter valid IFSC"),
              ],

              const SizedBox(height: 20),

              // Save button
              SizedBox(width: double.infinity, height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))]),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_editId == null ? Icons.add_rounded : Icons.check_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(_editId == null ? "Add Method" : "Update Method",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ]),
                  ),
                ),
              ),
            ])),
          ),
        ]))),
      ]),
    );
  }
}

// ── Custom Toast ────────────────────────────────────────────────────────────
class _ToastWidget extends StatelessWidget {
  final String msg;
  final bool isError;
  const _ToastWidget({required this.msg, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 60, left: 24, right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFD32F2F) : const Color(0xFF1B5E20),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14))),
          ]),
        ),
      ),
    );
  }
}