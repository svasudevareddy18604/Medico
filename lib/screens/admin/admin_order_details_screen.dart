import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final Map order;
  const AdminOrderDetailsScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailsScreen> createState() => _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  late Map o;
  bool _loadingCaretakers = false;
  bool _loadingRefund     = false;
  List _caretakers        = [];
  Map? _refundRequest;

  @override
  void initState() {
    super.initState();
    o = Map.from(widget.order);
    _fetchRefundRequest();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _status => (o['status'] ?? "").toString().trim().toUpperCase();

  Color _statusColor(String s) => switch (s) {
    "COMPLETED"           => const Color(0xFF1B7F6E),
    "ACCEPTED"            => const Color(0xFF1B7F6E),
    "CONFIRMED"           => const Color(0xFF2979FF),
    "IN_PROGRESS"         => const Color(0xFFF59E0B),
    "CANCELLED"           => const Color(0xFFE53935),
    "CARETAKER_CANCELLED" => const Color(0xFFE53935),
    "PENDING"             => const Color(0xFF7C4DFF),
    _                     => Colors.grey,
  };

  String _statusLabel(String s) => switch (s) {
    "CARETAKER_CANCELLED" => "Cancelled by Caretaker",
    _                     => s,
  };

  bool get _canCancel  => ["PENDING", "CONFIRMED"].contains(_status);
  bool get _canAssign  =>
      ["PENDING", "CONFIRMED", "CARETAKER_CANCELLED"].contains(_status);

  bool get _wasCancelledByCaretaker => _status == "CARETAKER_CANCELLED";

  String get _cancelledCaretakerName {
    final fn = o['cancelled_caretaker_first_name']?.toString() ?? "";
    final ln = o['cancelled_caretaker_last_name']?.toString()  ?? "";
    return "$fn $ln".trim();
  }

  String get _cancelledCaretakerMobile =>
      o['cancelled_caretaker_mobile']?.toString() ?? "";

  // ── Refund ────────────────────────────────────────────────────────────────
  Future<void> _fetchRefundRequest() async {
    final rs = (o['refund_status'] ?? '').toString().toUpperCase();
    if (!['PENDING', 'APPROVED', 'REJECTED', 'REFUNDED'].contains(rs)) return;
    setState(() => _loadingRefund = true);
    try {
      final res = await http.get(
          Uri.parse("${Api.baseUrl}/admin/orders/refunds?order_id=${o['id']}"));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'] ?? [];
        if (data.isNotEmpty) setState(() => _refundRequest = Map.from(data.first));
      }
    } catch (_) {} finally {
      setState(() => _loadingRefund = false);
    }
  }

  Future<void> _approveRefund(int refundId) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/orders/refunds/$refundId/approve"),
        headers: {"Content-Type": "application/json"},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          _refundRequest!['status'] = 'APPROVED';
          o['refund_status']  = 'REFUNDED';
          o['payment_status'] = 'REFUNDED';
        });
        _snack("✅ Refund of ₹${_refundRequest!['refund_amount']} approved!", const Color(0xFF1B7F6E));
      } else {
        _snack(body['message'] ?? "Approval failed", Colors.red);
      }
    } catch (e) { _snack("Error: $e", Colors.red); }
  }

  Future<void> _rejectRefund(int refundId, String reason) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/orders/refunds/$refundId/reject"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"reason": reason}),
      );
      if (res.statusCode == 200) {
        setState(() {
          _refundRequest!['status']        = 'REJECTED';
          _refundRequest!['reject_reason'] = reason;
          o['refund_status'] = 'REJECTED';
        });
        _snack("Refund request rejected.", Colors.orange);
      } else {
        _snack("Rejection failed", Colors.red);
      }
    } catch (e) { _snack("Error: $e", Colors.red); }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  Future<void> _cancelOrder(String reason) async {
    try {
      final res = await http.put(
        Uri.parse("${Api.baseUrl}/admin/orders/${o['id']}/cancel"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"reason": reason}),
      );
      if (res.statusCode == 200) {
        setState(() { o['status'] = 'CANCELLED'; o['cancel_reason'] = reason; });
        _snack("Order cancelled", Colors.red);
      }
    } catch (e) { _snack("Error: $e", Colors.red); }
  }

  // ── Fetch available caretakers (slot-aware) ───────────────────────────────
  Future<void> _fetchAvailableCaretakers() async {
    setState(() { _loadingCaretakers = true; _caretakers = []; });
    try {
      // ✅ Uses new slot-aware endpoint
      final res = await http.get(Uri.parse(
          "${Api.baseUrl}/admin/orders/available-caretakers/${o['id']}"));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() => _caretakers = decoded['data'] ?? []);
      } else {
        _snack("Failed to load caretakers", Colors.red);
      }
    } catch (e) {
      _snack("Error: $e", Colors.red);
    } finally {
      setState(() => _loadingCaretakers = false);
    }
  }

  // ── Assign caretaker ──────────────────────────────────────────────────────
  Future<void> _assignCaretaker(int caretakerId, String name) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/admin/orders/${o['id']}/assign"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"caretaker_id": caretakerId}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        setState(() {
          o['caretaker_first_name']  = name.split(" ").first;
          o['caretaker_last_name']   = name.split(" ").length > 1 ? name.split(" ").last : "";
          o['status']                = "ACCEPTED";
          o['assigned_caretaker_id'] = caretakerId;
        });
        if (mounted) Navigator.pop(context);
        _snack("Caretaker assigned successfully!", AppColors.primary);
      } else {
        _snack(body['message'] ?? "Assignment failed", Colors.red);
      }
    } catch (e) { _snack("Error: $e", Colors.red); }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showApproveRefundDialog() {
    if (_refundRequest == null) return;
    final amount = _refundRequest!['refund_amount']?.toString() ?? '0';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF1B7F6E)),
          SizedBox(width: 8), Text("Approve Refund"),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFE8F8F4),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.currency_rupee, color: Color(0xFF1B7F6E), size: 28),
              Text(amount, style: const TextStyle(fontSize: 28,
                  fontWeight: FontWeight.bold, color: Color(0xFF1B7F6E))),
            ]),
          ),
          const SizedBox(height: 12),
          Text("Initiate Razorpay refund of ₹$amount and notify user via email.",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B7F6E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { _approveRefund(_refundRequest!['id']); Navigator.pop(context); },
            label: const Text("Approve & Refund"),
          ),
        ],
      ),
    );
  }

  void _showRejectRefundDialog() {
    if (_refundRequest == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cancel_rounded, color: Colors.red),
          SizedBox(width: 8), Text("Reject Refund"),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Reason for rejecting:", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3,
              decoration: InputDecoration(
                hintText: "e.g. Service was delivered as scheduled...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2)),
              )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton.icon(
            icon: const Icon(Icons.block_rounded, size: 18),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _rejectRefund(_refundRequest!['id'], ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            label: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cancel_rounded, color: Colors.red),
          SizedBox(width: 8), Text("Cancel Order"),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Reason for cancellation:"),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3,
              decoration: InputDecoration(
                hintText: "e.g. No provider available...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2)),
              )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton.icon(
            icon: const Icon(Icons.cancel_rounded, size: 18),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _cancelOrder(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            label: const Text("Confirm Cancel"),
          ),
        ],
      ),
    );
  }

  void _showAssignSheet() async {
    await _fetchAvailableCaretakers();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.person_search_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _wasCancelledByCaretaker ? "Reassign Caretaker" : "Assign Caretaker",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text("Free for this slot · ${o['category'] ?? '-'}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
            ]),
          ),

          // ✅ If caretaker cancelled — show who cancelled
          if (_wasCancelledByCaretaker && _cancelledCaretakerName.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.person_off_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Previously cancelled by:",
                      style: TextStyle(color: Color(0xFFEF4444),
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text("$_cancelledCaretakerName · $_cancelledCaretakerMobile",
                      style: const TextStyle(color: Color(0xFFEF4444),
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ])),
              ]),
            ),

          const Divider(height: 1),

          // Caretaker list
          Expanded(
            child: _loadingCaretakers
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _caretakers.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.event_busy_rounded, size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text("No caretakers free for this slot",
                            style: TextStyle(color: Colors.grey[500],
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text("All ${o['category']} caretakers are busy",
                            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _caretakers.length,
                        itemBuilder: (_, i) {
                          final ct   = _caretakers[i];
                          final full = "${ct['first_name']} ${ct['last_name']}";
                          final isCurrent = o['assigned_caretaker_id'] == ct['id'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary.withOpacity(0.05)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent ? AppColors.primary : Colors.grey[200]!,
                                width: isCurrent ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.12),
                                child: Text(full[0].toUpperCase(),
                                    style: TextStyle(color: AppColors.primary,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(full,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const SizedBox(height: 2),
                                Text(ct['mobile'] ?? "",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                if (ct['caregiver_type'] != null)
                                  Text(ct['caregiver_type'],
                                      style: TextStyle(color: AppColors.primary,
                                          fontSize: 12, fontWeight: FontWeight.w600)),
                                if (ct['experience'] != null)
                                  Text("${ct['experience']} yrs exp",
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                              ]),
                              trailing: isCurrent
                                  ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _assignCaretaker(ct['id'], full),
                                      child: const Text("Assign",
                                          style: TextStyle(fontSize: 13)),
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _section(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 9),
      Text(title, style: TextStyle(fontSize: 14.5,
          fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  Widget _row(String label, String value, {Color? valueColor, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130,
              child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
          Expanded(child: Text(value.isEmpty ? "—" : value,
              style: TextStyle(fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? const Color(0xFF2D3142)))),
        ]),
      );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _refundBadge(String status) {
    final cfg = switch (status) {
      'PENDING'  => (const Color(0xFFFFF3E0), Colors.orange,        Icons.hourglass_empty_rounded, 'PENDING'),
      'APPROVED' => (const Color(0xFFE8F8F4), const Color(0xFF1B7F6E), Icons.check_circle_rounded, 'REFUNDED'),
      'REFUNDED' => (const Color(0xFFE8F8F4), const Color(0xFF1B7F6E), Icons.check_circle_rounded, 'REFUNDED'),
      'REJECTED' => (const Color(0xFFFFEBEE), Colors.red,           Icons.cancel_rounded,          'REJECTED'),
      _          => (Colors.grey.shade100,    Colors.grey,           Icons.info_rounded,            status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: cfg.$1, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(cfg.$3, color: cfg.$2, size: 14),
        const SizedBox(width: 4),
        Text(cfg.$4, style: TextStyle(color: cfg.$2,
            fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── Refund section ────────────────────────────────────────────────────────
  Widget _buildRefundSection() {
    final rs = (o['refund_status'] ?? '').toString().toUpperCase();
    if (!['PENDING', 'APPROVED', 'REFUNDED', 'REJECTED'].contains(rs))
      return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("Refund Request", Icons.account_balance_wallet_rounded, Colors.deepOrange),
      _loadingRefund
          ? _card(const Center(child: Padding(padding: EdgeInsets.all(12),
              child: CircularProgressIndicator())))
          : _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Refund Status", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                _refundBadge(rs),
              ]),
              if (_refundRequest != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _row("Amount", "₹${_refundRequest!['refund_amount'] ?? o['refund_amount'] ?? '0'}",
                    valueColor: Colors.deepOrange, bold: true),
                if (_refundRequest!['reason'] != null)
                  _row("User Reason", _refundRequest!['reason']),
                if (_refundRequest!['requested_at'] != null)
                  _row("Requested At", _refundRequest!['requested_at'].toString()),
                if (_refundRequest!['razorpay_refund_id'] != null)
                  _row("Razorpay Ref", _refundRequest!['razorpay_refund_id']),
                if (_refundRequest!['reject_reason'] != null && rs == 'REJECTED')
                  _row("Reject Reason", _refundRequest!['reject_reason'],
                      valueColor: Colors.red),
              ] else
                Padding(padding: const EdgeInsets.only(top: 8),
                    child: _row("Amount", "₹${o['refund_amount'] ?? '0'}",
                        valueColor: Colors.deepOrange, bold: true)),

              if (rs == 'PENDING' && _refundRequest != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B7F6E),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _showApproveRefundDialog,
                    label: const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.block_rounded, size: 18, color: Colors.red),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showRejectRefundDialog,
                    label: const Text("Reject",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  )),
                ]),
              ],
            ])),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final topPad   = MediaQuery.of(context).padding.top;
    final statusClr = _statusColor(_status);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(children: [

        // ── Header ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topPad + 18, 20, 22),
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Text("Booking Details",
                  style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['order_code'] ?? "#${o['id']}",
                    style: const TextStyle(color: Colors.white,
                        fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text("Order ID: #${o['id']}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(_status),
                    style: TextStyle(color: statusClr,
                        fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ]),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Careseeker
            _section("Careseeker Info", Icons.person_rounded, AppColors.primary),
            _card(Column(children: [
              _row("Name",
                  "${o['user_first_name'] ?? ''} ${o['user_last_name'] ?? ''}".trim()),
              _row("Mobile", o['user_mobile']?.toString() ?? ""),
            ])),

            // Caretaker
            _section("Caretaker Info", Icons.health_and_safety_rounded,
                const Color(0xFF2979FF)),
            _card(Column(children: [
              _row("Assigned To",
                o['caretaker_first_name'] != null
                    ? "${o['caretaker_first_name']} ${o['caretaker_last_name'] ?? ''}".trim()
                    : "Not Assigned",
                valueColor: o['caretaker_first_name'] != null
                    ? const Color(0xFF2979FF)
                    : Colors.orange,
                bold: true,
              ),
              if (o['caretaker_mobile'] != null)
                _row("Mobile", o['caretaker_mobile'].toString()),
              _row("Category", o['category'] ?? "-"),
            ])),

            // ✅ Cancelled-by caretaker card
            if (_wasCancelledByCaretaker) ...[
              _section("Cancelled By", Icons.person_off_rounded, Colors.red),
              _card(Column(children: [
                _row("Caretaker",
                    _cancelledCaretakerName.isNotEmpty
                        ? _cancelledCaretakerName
                        : "Unknown",
                    valueColor: Colors.red, bold: true),
                if (_cancelledCaretakerMobile.isNotEmpty)
                  _row("Mobile", _cancelledCaretakerMobile),
                if (o['cancel_reason'] != null)
                  _row("Reason", o['cancel_reason'], valueColor: Colors.red),
              ])),
            ],

            // Booking Info
            _section("Booking Info", Icons.calendar_today_rounded, Colors.purple),
            _card(Column(children: [
              _row("Date",      o['date']     ?? "-"),
              _row("Time Slot", o['slot']     ?? "-"),
              _row("Location",  o['location'] ?? "-"),
              _row("Latitude",  o['latitude']?.toString()  ?? "-"),
              _row("Longitude", o['longitude']?.toString() ?? "-"),
            ])),

            // Payment
            _section("Payment Info", Icons.payment_rounded, Colors.brown),
            _card(Column(children: [
              _row("Total", "₹${o['total']}", valueColor: AppColors.primary, bold: true),
              _row("Method",     o['payment_method'] ?? "-"),
              _row("Payment ID",
                  (o['payment_id']?.toString().isNotEmpty == true)
                      ? o['payment_id']
                      : "N/A"),
              _row("Pay Status", o['payment_status'] ?? "-",
                  valueColor: switch ((o['payment_status'] ?? "")) {
                    "PAID"     => AppColors.primary,
                    "REFUNDED" => Colors.deepOrange,
                    _          => Colors.orange,
                  }),
            ])),

            // Refund
            _buildRefundSection(),

            // Timeline
            _section("Timeline", Icons.timeline_rounded, Colors.teal),
            _card(Column(children: [
              _row("Created At", o['created_at']?.toString() ?? "-"),
              if (o['accepted_at']  != null) _row("Accepted At",  o['accepted_at'].toString()),
              if (o['completed_at'] != null) _row("Completed At", o['completed_at'].toString()),
              if (o['cancelled_at'] != null) _row("Cancelled At", o['cancelled_at'].toString()),
            ])),

            // Cancel reason (non-caretaker cancel)
            if (o['cancel_reason'] != null && !_wasCancelledByCaretaker) ...[
              _section("Cancellation", Icons.info_rounded, Colors.red),
              _card(_row("Reason", o['cancel_reason'], valueColor: Colors.red)),
            ],

            const SizedBox(height: 24),

            // Assign button
            if (_canAssign)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_wasCancelledByCaretaker
                      ? Icons.swap_horiz_rounded
                      : Icons.person_search_rounded, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _showAssignSheet,
                  label: Text(
                    _wasCancelledByCaretaker
                        ? "Reassign Caretaker"
                        : "Assign Caretaker",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Cancel button
            if (_canCancel) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_rounded, size: 20, color: Colors.red),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _showCancelDialog,
                  label: const Text("Cancel Order",
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ),
            ],
          ]),
        )),
      ]),
    );
  }
}