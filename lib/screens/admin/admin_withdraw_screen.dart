import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminWithdrawScreen extends StatefulWidget {
  const AdminWithdrawScreen({super.key});
  @override
  State<AdminWithdrawScreen> createState() => _AdminWithdrawScreenState();
}

class _AdminWithdrawScreenState extends State<AdminWithdrawScreen> {
  List withdrawals = [];
  List selectedIds = [];
  bool loading = true;
  String filter = "all";

  final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(Api.withdraw));
      final data = jsonDecode(res.body);
      if (data["success"]) setState(() => withdrawals = data["data"]);
    } catch (_) { _snack("Failed to load withdrawals", error: true); }
    setState(() => loading = false);
  }

  List get filtered {
    if (filter == "all") return withdrawals;
    return withdrawals.where((e) => e["status"] == filter).toList();
  }

  Map<String, int> get counts => {
    "all": withdrawals.length,
    "pending": withdrawals.where((e) => e["status"] == "pending").length,
    "approved": withdrawals.where((e) => e["status"] == "approved").length,
    "paid": withdrawals.where((e) => e["status"] == "paid").length,
    "rejected": withdrawals.where((e) => e["status"] == "rejected").length,
  };

  Future<void> _post(String endpoint, Map body, String successMsg) async {
    try {
      await http.post(Uri.parse("${Api.baseUrl}/admin/withdraw/$endpoint"),
        headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
      _snack(successMsg);
      load();
    } catch (_) { _snack("Action failed", error: true); }
  }

  Future<void> approve(int id) => _post("approve", {"withdrawal_id": id}, "✅ Request approved");
  Future<void> reject(int id) => _post("reject", {"withdrawal_id": id}, "❌ Request rejected");
  Future<void> markPaid(int id) => _post("mark-paid", {"withdrawal_id": id}, "💰 Marked as paid");

  Future<void> bulkApprove() async {
    await _post("approve-bulk", {"ids": selectedIds}, "✅ ${selectedIds.length} requests approved");
    setState(() => selectedIds.clear());
  }

  Future<void> openUPI(String upi, double amount) async {
    final uri = Uri.parse("upi://pay?pa=$upi&pn=Caregiver%20Payment&tn=Caregiver%20Payment"
        "&am=${amount.toStringAsFixed(2)}&cu=INR&tr=TXN${DateTime.now().millisecondsSinceEpoch}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack("No UPI app found on this device", error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: error ? Colors.red.shade600 : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  Future<bool?> _confirm(String title, String msg) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Confirm"),
        ),
      ],
    ),
  );

  // ── STATUS HELPERS ─────────────────────────────────────

  Color _statusColor(String s) => switch (s) {
    "pending"  => Colors.orange,
    "approved" => Colors.blue,
    "paid"     => AppColors.primary,
    "rejected" => Colors.red,
    _          => Colors.grey,
  };

  IconData _statusIcon(String s) => switch (s) {
    "pending"  => Icons.hourglass_empty_rounded,
    "approved" => Icons.thumb_up_rounded,
    "paid"     => Icons.check_circle_rounded,
    "rejected" => Icons.cancel_rounded,
    _          => Icons.help_outline,
  };

  // ── WIDGETS ────────────────────────────────────────────

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
        const SizedBox(width: 10),
        const Expanded(child: Text("Withdraw Requests",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: load),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _statBadge("Total", counts["all"]!),
        const SizedBox(width: 8),
        _statBadge("Pending", counts["pending"]!, color: Colors.orange.shade100),
        const SizedBox(width: 8),
        _statBadge("Paid", counts["paid"]!, color: Colors.green.shade100),
      ]),
    ]),
  );

  Widget _statBadge(String label, int count, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color ?? Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text("$label: $count",
      style: TextStyle(
        color: color != null ? Colors.black87 : Colors.white,
        fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _filterBar() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: ["all", "pending", "approved", "paid", "rejected"].map((v) {
        final selected = filter == v;
        return GestureDetector(
          onTap: () => setState(() { filter = v; selectedIds.clear(); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
              boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)] : [],
            ),
            child: Row(children: [
              if (v != "all") Icon(_statusIcon(v),
                size: 14,
                color: selected ? Colors.white : _statusColor(v)),
              if (v != "all") const SizedBox(width: 4),
              Text(v[0].toUpperCase() + v.substring(1),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.3) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("${counts[v]}", style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        );
      }).toList(),
    ),
  );

  Widget _bulkBar() => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    height: selectedIds.isNotEmpty ? 56 : 0,
    child: selectedIds.isNotEmpty ? Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.checklist_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text("${selectedIds.length} selected",
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(onPressed: () => setState(() => selectedIds.clear()),
          child: const Text("Clear")),
        ElevatedButton(
          onPressed: () async {
            final ok = await _confirm("Bulk Approve", "Approve ${selectedIds.length} requests?");
            if (ok == true) bulkApprove();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          child: const Text("Approve All"),
        ),
      ]),
    ) : const SizedBox.shrink(),
  );

  Widget _card(Map w) {
    final id = w["id"] as int;
    final status = w["status"] ?? "pending";
    final amount = double.tryParse(w["amount"].toString()) ?? 0;
    final name = w["caretaker_name"] ?? "Unknown";
    final mobile = w["caretaker_mobile"] ?? "—";
    final upi = w["upi_id"]?.toString() ?? "";
    final acc = w["account_number"]?.toString();
    final ifsc = w["ifsc_code"]?.toString();
    final isSelected = selectedIds.contains(id);
    final sColor = _statusColor(status);

    return GestureDetector(
      onLongPress: () => setState(() =>
        isSelected ? selectedIds.remove(id) : selectedIds.add(id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0,3))],
        ),
        child: Column(children: [

          // ── TOP COLOR BAR ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: sColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() =>
                  isSelected ? selectedIds.remove(id) : selectedIds.add(id)),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.white,
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300, width: 2),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(status), size: 12, color: sColor),
                  const SizedBox(width: 4),
                  Text(status.toUpperCase(),
                    style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── AMOUNT + MOBILE ──
              Row(children: [
                Text(fmt.format(amount),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Spacer(),
                Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(mobile, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ]),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── PAYMENT DETAILS ──
              if (upi.isNotEmpty) ...[
                _detailRow(Icons.qr_code_rounded, "UPI ID", upi, copyable: true),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => openUPI(upi, amount),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text("Pay ${fmt.format(amount)} via UPI"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else if (acc != null) ...[
                _detailRow(Icons.account_balance_rounded, "Account", acc, copyable: true),
                const SizedBox(height: 6),
                _detailRow(Icons.numbers_rounded, "IFSC", ifsc ?? "—"),
              ] else
                _detailRow(Icons.warning_amber_rounded, "Payment", "No details provided", warn: true),

              const SizedBox(height: 14),

              // ── ACTIONS ──
              if (status == "pending") Row(children: [
                Expanded(child: _actionBtn("Approve", Icons.check_rounded, AppColors.primary, () async {
                  final ok = await _confirm("Approve", "Approve this withdrawal request?");
                  if (ok == true) approve(id);
                })),
                const SizedBox(width: 10),
                Expanded(child: _actionBtn("Reject", Icons.close_rounded, Colors.red.shade400, () async {
                  final ok = await _confirm("Reject", "Reject this withdrawal request?");
                  if (ok == true) reject(id);
                })),
              ]),

              if (status == "approved")
                SizedBox(width: double.infinity,
                  child: _actionBtn("Mark as Paid", Icons.payment_rounded, Colors.blue.shade500, () async {
                    final ok = await _confirm("Mark Paid", "Confirm payment has been sent?");
                    if (ok == true) markPaid(id);
                  }),
                ),

              if (status == "paid") Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text("Payment Completed", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ]),
              ),

              if (status == "rejected") Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 6),
                  Text("Request Rejected", style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                ]),
              ),

            ]),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool copyable = false, bool warn = false}) =>
    Row(children: [
      Icon(icon, size: 16, color: warn ? Colors.orange : AppColors.secondary),
      const SizedBox(width: 8),
      Text("$label: ", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      Expanded(child: Text(value,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
          color: warn ? Colors.orange : Colors.black87))),
      if (copyable) GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          _snack("$label copied!");
        },
        child: Icon(Icons.copy_rounded, size: 16, color: Colors.grey.shade400),
      ),
    ]);

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
    ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    Text("No $filter requests", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
    const SizedBox(height: 8),
    TextButton(onPressed: load, child: const Text("Refresh")),
  ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F6F9),
    body: Column(children: [
      _header(),
      _filterBar(),
      _bulkBar(),
      if (loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
      else if (filtered.isEmpty)
        Expanded(child: _empty())
      else
        Expanded(child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: filtered.map((e) => _card(e)).toList(),
          ),
        )),
    ]),
  );
}