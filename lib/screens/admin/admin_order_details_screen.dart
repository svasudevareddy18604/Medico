import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ NEW — for Clipboard (copy OTP)
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:medico/screens/admin/document_viewer_screen.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final Map order;
  const AdminOrderDetailsScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailsScreen> createState() => _AdminOrderDetailsScreenState();
}

// ══════════════════════════════════════════════════════════════════════════
//  ADMIN RESCHEDULE BOTTOM SHEET
//  Works at any pre-completion order status. Posts to the admin-only
//  reschedule route, which bypasses the cooldown/notice-period limits
//  that exist to stop end-user self-service abuse — this is a support
//  action taken on the careseeker's behalf.
// ══════════════════════════════════════════════════════════════════════════

class _AdminRescheduleSheet extends StatefulWidget {
  final int orderId;
  final String currentDate;
  final String currentSlot;
  final void Function(String newDate, String newSlot) onRescheduled;

  const _AdminRescheduleSheet({
    required this.orderId,
    required this.currentDate,
    required this.currentSlot,
    required this.onRescheduled,
  });

  @override
  State<_AdminRescheduleSheet> createState() => _AdminRescheduleSheetState();
}

class _AdminRescheduleSheetState extends State<_AdminRescheduleSheet> {
  late List<Map<String, String>> _dates;
  String _selectedDate = "";

  List<Map<String, String>> _slots = [];
  int? _selectedSlotId;
  String _selectedSlotTime = "";

  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dates = _buildDates();
    _selectedDate = _dates.first["value"]!;
    _fetchSlots();
  }

  List<Map<String, String>> _buildDates() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(14, (i) {
      final d = now.add(Duration(days: i));
      final value =
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final label = i == 0 ? "Today" : "${days[d.weekday - 1]} ${d.day}";
      return {"value": value, "label": label};
    });
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _loadingSlots = true;
      _selectedSlotId = null;
      _selectedSlotTime = "";
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(
              "${Api.getAvailableSlots(widget.orderId)}?date=$_selectedDate"))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final rawSlots = List<Map<String, dynamic>>.from(data["slots"] ?? []);
        setState(() {
          _slots = rawSlots
              .map((s) => {
                    "id": s["id"].toString(),
                    "slot_time": s["slot_time"].toString(),
                  })
              .toList();
          _loadingSlots = false;
        });
      } else {
        setState(() {
          _slots = [];
          _loadingSlots = false;
          _error = data["message"]?.toString();
        });
      }
    } catch (_) {
      setState(() {
        _slots = [];
        _loadingSlots = false;
        _error = "Could not load slots. Please try again.";
      });
    }
  }

  String _formatTime(String hhmm) {
    try {
      final p = hhmm.split(":");
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])).format(context);
    } catch (_) {
      return hhmm;
    }
  }

  Future<void> _confirmReschedule() async {
    if (_selectedSlotId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse(Api.adminRescheduleOrder(widget.orderId)),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "date": _selectedDate,
          "slot_id": _selectedSlotId,
        }),
      );
      final data = jsonDecode(res.body);

      if (mounted) {
        if (data["success"] == true) {
          Navigator.pop(context);
          widget.onRescheduled(_selectedDate, _selectedSlotTime);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Booking rescheduled successfully!",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.all(16),
            ),
          );
        } else {
          setState(() =>
              _error = data["message"]?.toString() ?? "Could not reschedule booking.");
          if ((data["message"]?.toString() ?? "").toLowerCase().contains("taken")) {
            _fetchSlots();
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Network error. Please try again.");
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final chipBg = Colors.grey[100]!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_repeat_rounded,
                      color: Colors.deepPurple, size: 20),
                ),
                const SizedBox(width: 12),
                const Text("Reschedule Booking (Admin)",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  "Current: ${widget.currentDate}, ${widget.currentSlot}",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),

              const Text("Select Date",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2D3142))),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  itemBuilder: (_, i) {
                    final sel = _dates[i]["value"] == _selectedDate;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = _dates[i]["value"]!);
                        _fetchSlots();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? Colors.deepPurple : chipBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? Colors.deepPurple : Colors.transparent,
                          ),
                        ),
                        child: Text(_dates[i]["label"]!,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              Row(children: [
                const Text("Available Slots",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2D3142))),
                const Spacer(),
                if (!_loadingSlots)
                  GestureDetector(
                    onTap: _fetchSlots,
                    child: const Icon(Icons.refresh_rounded, size: 18, color: Colors.deepPurple),
                  ),
              ]),
              const SizedBox(height: 10),

              if (_loadingSlots)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_slots.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      Icon(Icons.event_busy_rounded, color: Colors.grey[400], size: 28),
                      const SizedBox(height: 8),
                      Text("No slots available for this date",
                          style: TextStyle(color: Colors.grey[500])),
                    ]),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _slots.map((s) {
                    final id  = int.parse(s["id"]!);
                    final t   = s["slot_time"]!;
                    final sel = _selectedSlotId == id;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedSlotId = id;
                        _selectedSlotTime = t;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? Colors.deepPurple : chipBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? Colors.deepPurple : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(_formatTime(t),
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    );
                  }).toList(),
                ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red, fontSize: 12.5))),
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text("Cancel",
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_selectedSlotId == null || _submitting) ? null : _confirmReschedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _selectedSlotId == null ? "Select a slot" : "Confirm Reschedule",
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  late Map o;
  bool _loadingCaretakers = false;
  bool _loadingRefund     = false;
  bool _loadingDocuments  = false;
  List _caretakers        = [];
  List _documents         = [];
  Map? _refundRequest;

  // ✅ NEW — Admin-only OTP state
  bool _loadingOtp   = false;
  String? _otp;
  bool _otpVerified  = false;
  String? _otpVerifiedAt;
  bool _otpVisible   = false; // masked by default, admin taps to reveal
  String? _otpError;          // set when fetch fails, shown instead of a false "not generated"

  @override
  void initState() {
    super.initState();
    o = Map.from(widget.order);
    _fetchRefundRequest();
    _fetchDocuments();
    _fetchOtp(); // ✅ NEW
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

  // ── FIX (Bug 2): both getters kept — reschedule availability and
  // cancel availability are two separate, independent conditions.
  bool get _canReschedule => !["COMPLETED", "CANCELLED"].contains(_status);
  bool get _canCancel => ["PENDING", "CONFIRMED"].contains(_status);

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

  // turns "id_proof_front" into "Id Proof Front"
  String _prettyDocKey(String key) {
    if (key.isEmpty) return "Document";
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : "${w[0].toUpperCase()}${w.substring(1)}")
        .join(' ');
  }

  // turns an ISO timestamp into "11 Jul 2026 · 6:45 PM"
  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return "-";
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      var hour = dt.hour % 12;
      if (hour == 0) hour = 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return "$day $month ${dt.year} · $hour:$minute $period";
    } catch (_) {
      return raw;
    }
  }

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

  // Fetch documents uploaded by the careseeker for this order
  Future<void> _fetchDocuments() async {
    setState(() => _loadingDocuments = true);
    try {
      final res = await http.get(
          Uri.parse("${Api.baseUrl}/documents/order/${o['id']}"));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() => _documents = List.from(decoded['documents'] ?? []));
      }
    } catch (_) {
      // Silently ignore — documents are supplementary, not critical path.
    } finally {
      if (mounted) setState(() => _loadingDocuments = false);
    }
  }

  // ✅ Fetch the Service OTP for this order (admin-only view).
  // Works regardless of order status/time — admin can check it anytime.
  // Any failure is surfaced in _otpError instead of being swallowed, so a
  // wrong route / auth block / bad response shape is visible in the UI
  // instead of silently looking like "OTP not generated".
  Future<void> _fetchOtp() async {
    setState(() { _loadingOtp = true; _otpError = null; });
    final url = "${Api.baseUrl}/admin/orders/${o['id']}/otp";
    try {
      final res = await http.get(Uri.parse(url));
      // ignore: avoid_print
      print("OTP fetch → $url → ${res.statusCode} → ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] != true || decoded['data'] == null) {
          setState(() => _otpError = "Unexpected response: ${res.body}");
          return;
        }
        final data = decoded['data'];
        setState(() {
          _otp           = data['otp']?.toString();
          _otpVerified   = (data['otp_verified'] == true || data['otp_verified'] == 1);
          _otpVerifiedAt = data['otp_verified_at']?.toString();
        });
      } else if (res.statusCode == 404) {
        setState(() => _otpError = "Order/route not found (404). Check that "
            "'/admin/orders/:id/otp' is registered on the server and the "
            "order id is correct.");
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        setState(() => _otpError = "Not authorized (${res.statusCode}). "
            "This endpoint may require an admin auth header/token that "
            "wasn't sent.");
      } else {
        setState(() => _otpError = "Server error (${res.statusCode}): ${res.body}");
      }
    } catch (e) {
      // ignore: avoid_print
      print("OTP fetch error → $url → $e");
      setState(() => _otpError = "Could not reach server: $e");
    } finally {
      if (mounted) setState(() => _loadingOtp = false);
    }
  }

  void _copyOtp() {
    if (_otp == null || _otp!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _otp!));
    _snack("OTP copied to clipboard", AppColors.primary);
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

  // ── FIX (Bug 1): _showAdminRescheduleSheet() now lives here as its own
  // top-level method, right after _showCancelDialog() and before
  // _showAssignSheet() — no longer nested inside another method.
  void _showAdminRescheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminRescheduleSheet(
        orderId: o['id'] as int,
        currentDate: o['date']?.toString() ?? "",
        currentSlot: o['slot']?.toString() ?? "",
        onRescheduled: (newDate, newSlot) {
          setState(() {
            o['date'] = newDate;
            o['slot'] = newSlot;
          });
        },
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

          // If caretaker cancelled — show who cancelled
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

  // ✅ NEW — Admin-only Service OTP section.
  // Visible at any point in the order lifecycle, independent of status.
  Widget _buildOtpSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("Service OTP (Admin Only)", Icons.lock_clock_rounded, Colors.deepPurple),
      _loadingOtp
          ? _card(const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator())))
          : _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Generated OTP", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _otpVerified
                        ? const Color(0xFFE8F8F4)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _otpVerified ? Icons.verified_rounded : Icons.hourglass_empty_rounded,
                      color: _otpVerified ? const Color(0xFF1B7F6E) : Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _otpVerified ? "VERIFIED" : "NOT VERIFIED",
                      style: TextStyle(
                        color: _otpVerified ? const Color(0xFF1B7F6E) : Colors.orange,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              if (_otpError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("Couldn't load OTP",
                          style: TextStyle(color: Colors.red,
                              fontWeight: FontWeight.bold, fontSize: 13))),
                      TextButton(
                        onPressed: _fetchOtp,
                        child: const Text("Retry", style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(_otpError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 11.5)),
                  ]),
                )
              else if (_otp == null || _otp!.isEmpty)
                Row(children: [
                  Icon(Icons.info_outline_rounded, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 8),
                  Text("OTP not generated for this order",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ])
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _otpVisible ? _otp! : "• • • •",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          color: Color(0xFF5B21B6),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _otpVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF5B21B6),
                      ),
                      tooltip: _otpVisible ? "Hide OTP" : "Reveal OTP",
                      onPressed: () => setState(() => _otpVisible = !_otpVisible),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF5B21B6)),
                      tooltip: "Copy OTP",
                      onPressed: _copyOtp,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B21B6)),
                      tooltip: "Refresh",
                      onPressed: _fetchOtp,
                    ),
                  ]),
                ),
              if (_otpVerified && _otpVerifiedAt != null) ...[
                const SizedBox(height: 10),
                _row("Verified At", _formatDateTime(_otpVerifiedAt)),
              ],
              const SizedBox(height: 6),
              Text(
                "This code is shared with the careseeker and verified on-site by the caretaker. Visible to admin only.",
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ])),
    ]);
  }

  // Uploaded Documents section: neat 2-column grid, tap → full-screen viewer
  Widget _buildDocumentsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("Uploaded Documents", Icons.folder_copy_rounded, Colors.indigo),
      _loadingDocuments
          ? _card(const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator())))
          : _documents.isEmpty
              ? _card(Row(children: [
                  Icon(Icons.folder_off_rounded, color: Colors.grey[400], size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text("No documents uploaded by the careseeker yet",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13))),
                ]))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _documents.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (_, i) {
                    final doc = _documents[i];
                    final isPdf = (doc['file_type'] ?? '').toString().toLowerCase() == 'pdf';
                    final key   = _prettyDocKey(doc['document_key']?.toString() ?? '');

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(
                            documents: _documents,
                            initialIndex: i,
                          ),
                        ),
                      ),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                              blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Stack(fit: StackFit.expand, children: [
                              isPdf
                                  ? Container(
                                      color: const Color(0xFFFDEDEC),
                                      child: const Center(
                                        child: Icon(Icons.picture_as_pdf_rounded,
                                            color: Colors.redAccent, size: 40),
                                      ),
                                    )
                                  : Image.network(
                                      doc['file_url'] ?? '',
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          color: Colors.grey[100],
                                          child: const Center(
                                            child: SizedBox(
                                              width: 18, height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[100],
                                        child: Icon(Icons.broken_image_rounded,
                                            color: Colors.grey[400], size: 30),
                                      ),
                                    ),
                              // Small zoom hint
                              Positioned(
                                right: 6, bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.fullscreen_rounded,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(key,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5,
                                      fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                    size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    doc['uploaded_at'] != null
                                        ? _formatDateTime(doc['uploaded_at'].toString())
                                        : (isPdf ? "PDF" : "Image"),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
    ]);
  }

  // Timeline as a proper connected vertical timeline
  Widget _buildTimelineSection() {
    final items = <Map<String, dynamic>>[
      {
        'label': "Order Created",
        'value': o['created_at'],
        'icon': Icons.add_circle_rounded,
        'color': Colors.blueGrey,
      },
      if (o['accepted_at'] != null)
        {
          'label': "Caretaker Accepted",
          'value': o['accepted_at'],
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF2979FF),
        },
      if (o['completed_at'] != null)
        {
          'label': "Service Completed",
          'value': o['completed_at'],
          'icon': Icons.task_alt_rounded,
          'color': const Color(0xFF1B7F6E),
        },
      if (o['cancelled_at'] != null)
        {
          'label': _wasCancelledByCaretaker ? "Cancelled by Caretaker" : "Order Cancelled",
          'value': o['cancelled_at'],
          'icon': Icons.cancel_rounded,
          'color': Colors.red,
        },
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("Timeline", Icons.timeline_rounded, Colors.teal),
      _card(Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          final color = item['color'] as Color;

          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey[200],
                    ),
                  ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 4, bottom: isLast ? 2 : 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['label'] as String,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142))),
                    const SizedBox(height: 3),
                    Text(_formatDateTime(item['value']?.toString()),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ]),
                ),
              ),
            ]),
          );
        }),
      )),
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

            // ✅ NEW — Service OTP (admin-only, visible at any order stage)
            _buildOtpSection(),

            // Cancelled-by caretaker card
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

            // Uploaded Documents
            _buildDocumentsSection(),

            // Timeline
            _buildTimelineSection(),

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

            // Reschedule button
            if (_canReschedule) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_repeat_rounded, size: 20, color: Colors.deepPurple),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _showAdminRescheduleSheet,
                  label: const Text("Reschedule Booking",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                ),
              ),
            ],

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _showCancelDialog,
                  label: const Text("Cancel Order",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ),
            ],
          ]),
        )),
      ]),
    );
  }
}