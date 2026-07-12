import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';
import 'widgets/reject_caregiver_dialog.dart'; // 🔥 NEW

class AdminCaregiverDetails extends StatefulWidget {
  final Map caregiver;
  const AdminCaregiverDetails({super.key, required this.caregiver});

  @override
  State<AdminCaregiverDetails> createState() => _AdminCaregiverDetailsState();
}

class _AdminCaregiverDetailsState extends State<AdminCaregiverDetails> {
  // ─── State ─────────────────────────────────────────────────────────────────
  Map?   data;
  bool   loading    = true;
  bool   isBlocked  = false;

  // Availability state (read from API)
  bool   isAvailable        = false;
  bool   availabilityLocked = false;
  int    inactiveDays       = 0;
  String lastAvailableAt    = "";
  String lastUnavailableAt  = "";
  List   dailyHistory       = [];

  // ─── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  // ─── API ───────────────────────────────────────────────────────────────────
  Future<void> fetchDetails() async {
    try {
      final res = await http.get(
          Uri.parse(Api.caregiverDetails(widget.caregiver["id"])));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final avail = d["availability"] ?? {};
        setState(() {
          data              = d;
          isBlocked         = (d["user"]?["is_blocked"] == 1 || d["user"]?["is_blocked"] == true);
          isAvailable       = (avail["is_available"]        == 1 || avail["is_available"] == true);
          availabilityLocked= (avail["availability_locked"] == 1 || avail["availability_locked"] == true);
          inactiveDays      = avail["inactive_days"] ?? 0;
          lastAvailableAt   = avail["last_available_at"]   ?? "";
          lastUnavailableAt = avail["last_unavailable_at"] ?? "";
          dailyHistory      = (d["daily_history"] as List?) ?? [];
        });
      }
    } catch (e) {
      debugPrint("DETAIL ERROR: $e");
    }
    setState(() => loading = false);
  }

  /// Admin sets availability (true = available & unlock, false = unavailable & lock)
  Future<void> _setAvailability(bool makeAvailable) async {
    final confirmed = await _confirmDialog(
      title:   makeAvailable ? "Mark as Available" : "Mark as Unavailable",
      message: makeAvailable
          ? "This caregiver will be reactivated and can receive jobs."
          : "This caregiver will be marked unavailable and LOCKED.\nThey must contact admin to go online again.",
      confirmLabel:  makeAvailable ? "Activate"    : "Mark Unavailable",
      confirmColor:  makeAvailable ? Colors.green.shade600 : Colors.orange.shade700,
    );
    if (!confirmed) return;

    try {
      final res = await http.post(
        Uri.parse(Api.setCaregiverAvailability(widget.caregiver["id"])),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_available": makeAvailable ? 1 : 0}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          isAvailable        = makeAvailable;
          availabilityLocked = !makeAvailable;
        });
        _toast(
          body["message"] ?? (makeAvailable ? "Marked Available" : "Marked Unavailable"),
          color: makeAvailable ? Colors.green.shade600 : Colors.orange.shade700,
        );
        await fetchDetails(); // refresh history
      } else {
        _toast("Failed (${res.statusCode})", isError: true);
      }
    } catch (_) {
      _toast("Network error", isError: true);
    }
  }

  Future<void> _approve() async {
    try {
      final res = await http.post(
          Uri.parse(Api.approveCaregiver(widget.caregiver["id"])));
      if (res.statusCode == 200) {
        _toast("Caregiver Approved!");
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context, true);
      } else {
        _toast("Approve failed (${res.statusCode})", isError: true);
      }
    } catch (_) {
      _toast("Network error", isError: true);
    }
  }

  /// 🔥 REJECT — now opens the categorized reason dialog.
  /// The dialog itself calls the reject API (with reason + allow_reupload)
  /// and returns `true` on success, so we just react to that here.
  Future<void> _reject() async {
    final result = await showRejectCaregiverDialog(
      context,
      userId: widget.caregiver["id"],
    );

    if (result == true) {
      _toast("Caregiver Rejected", isError: true);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _blockUnblock(bool block) async {
    final confirmed = await _confirmDialog(
      title:   block ? "Block Caregiver" : "Unblock Caregiver",
      message: block
          ? "This caregiver will be blocked and cannot login."
          : "This caregiver will be unblocked and can login again.",
      confirmLabel: block ? "Block"    : "Unblock",
      confirmColor: block ? Colors.orange.shade700 : Colors.green.shade600,
    );
    if (!confirmed) return;
    try {
      final url = block
          ? Api.blockCaregiver(widget.caregiver["id"])
          : Api.unblockCaregiver(widget.caregiver["id"]);
      final res = await http.post(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() => isBlocked = block);
        _toast(
          block ? "Caregiver Blocked" : "Caregiver Unblocked!",
          color: block ? Colors.orange.shade700 : Colors.green.shade600,
        );
      } else {
        String msg = "${block ? 'Block' : 'Unblock'} failed (${res.statusCode})";
        try { msg = jsonDecode(res.body)["message"] ?? msg; } catch (_) {}
        _toast(msg, isError: true);
      }
    } catch (_) {
      _toast("Network error", isError: true);
    }
  }

  // ─── Reusable confirm dialog ────────────────────────────────────────────────
  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color  confirmColor,
  }) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        )) ??
        false;
  }

  // ─── Toast ─────────────────────────────────────────────────────────────────
  void _toast(String msg, {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.cancel : Icons.check_circle,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
        backgroundColor:
            color ?? (isError ? Colors.red.shade600 : AppColors.primary),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
  }

  // ─── URL builder ───────────────────────────────────────────────────────────
  String? buildUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith("http")) return path;
    return "${Api.imageBase}/${path.replaceAll("\\", "/")}";
  }

  // ─── Status helpers ────────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case "COMPLETED":
      case "PAID":
        return const Color(0xFF00897B);
      case "ACCEPTED":
      case "IN_PROGRESS":
        return const Color(0xFF1E88E5);
      case "PENDING":
        return const Color(0xFFFB8C00);
      case "CANCELLED":
      case "CARETAKER_CANCELLED":
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toUpperCase()) {
      case "COMPLETED":
      case "PAID":
        return Icons.check_circle_rounded;
      case "ACCEPTED":
      case "IN_PROGRESS":
        return Icons.autorenew_rounded;
      case "PENDING":
        return Icons.schedule_rounded;
      case "CANCELLED":
      case "CARETAKER_CANCELLED":
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _shortStatus(String s) {
    switch (s.toUpperCase()) {
      case "CARETAKER_CANCELLED":
        return "CT CANCEL";
      case "IN_PROGRESS":
        return "ACTIVE";
      case "COMPLETED":
        return "DONE";
      default:
        return s.toUpperCase();
    }
  }

  // ─── Widget helpers ─────────────────────────────────────────────────────────

  Widget _netImage(String? path, {double height = 180}) {
    final url = buildUrl(path);
    if (url == null) return _placeholder(height);
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) => prog == null
          ? child
          : SizedBox(
              height: height,
              child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))),
      errorBuilder: (_, __, ___) => _placeholder(height),
    );
  }

  Widget _placeholder(double h) => Container(
        height: h,
        color: const Color(0xFFF5F5F5),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.image_not_supported_outlined,
              color: Colors.grey, size: 32),
          const SizedBox(height: 6),
          Text("Not available",
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ]),
      );

  Widget _avatar(String? path) {
    final url = buildUrl(path);
    if (url == null)
      return const Icon(Icons.person, size: 48, color: Colors.white70);
    return Image.network(url,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, size: 48, color: Colors.white70));
  }

  Widget _statCell(
          String label, String value, Color color, IconData icon) =>
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Column(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color))),
            const SizedBox(height: 3),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.75),
                        fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  Widget _earnCell(
          String label, String value, Color color, IconData icon) =>
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color))),
            const SizedBox(height: 3),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.75),
                        fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  Widget _section(String title, IconData icon, Widget child) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                blurRadius: 12,
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _infoRow(String label, String value, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primary, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E))),
              ])),
        ]),
      );

  Widget _chip(String raw) {
    final color = _statusColor(raw);
    final short = _shortStatus(raw);
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(raw), size: 11, color: color),
        const SizedBox(width: 3),
        Flexible(
            child: Text(short,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color))),
      ]),
    );
  }

  Widget _orderTile(Map o) {
    final status = (o["status"] ?? "").toString();
    final color  = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.05))
        ],
      ),
      child: Column(children: [
        Container(
            height: 3,
            decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)))),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                  child: Text(
                      o["order_code"] ?? "#${o["id"] ?? ""}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary))),
              const SizedBox(width: 8),
              _chip(status),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _miniInfo(Icons.category_rounded,
                  o["category"] ?? "N/A", Colors.indigo),
              _miniInfo(Icons.calendar_today_rounded,
                  o["date"] ?? "N/A", Colors.purple),
              _miniInfo(Icons.access_time_rounded,
                  o["slot"] ?? "N/A", Colors.teal),
              _miniInfo(
                  Icons.currency_rupee_rounded,
                  "${o["total"] ?? 0}",
                  const Color(0xFF00897B)),
            ]),
            if (o["cancel_reason"] != null &&
                o["cancel_reason"].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(o["cancel_reason"],
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _miniInfo(IconData icon, String value, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500)),
      ]);

  Widget _earningTile(Map e) {
    final status = (e["status"] ?? "").toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.05))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.10),
              shape: BoxShape.circle),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Color(0xFF00897B), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text("Order #${e["order_id"] ?? ""}",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 3),
          Text(
              "Total ₹${e["total_amount"] ?? 0}  •  Commission ₹${e["commission"] ?? 0}",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text("₹${e["caretaker_amount"] ?? 0}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF00897B))),
          const SizedBox(height: 4),
          _chip(status),
        ]),
      ]),
    );
  }

  Widget _docCard(String title, String? path) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                blurRadius: 8,
                color: Colors.black.withOpacity(0.06))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration:
                  const BoxDecoration(gradient: AppColors.gradient),
              child: Row(children: [
                const Icon(Icons.file_present_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ]),
            ),
            GestureDetector(
              onTap: () {
                final url = buildUrl(path);
                if (url == null) return;
                showDialog(
                    context: context,
                    builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: InteractiveViewer(
                              child: Image.network(url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(300))),
                        ));
              },
              child: _netImage(path),
            ),
          ]),
        ),
      );

  Widget _btn(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  // ─── AVAILABILITY CARD ──────────────────────────────────────────────────────
  Widget _availabilityCard() {
    // Determine warning level for inactive days
    final bool overOneMonth    = inactiveDays > 30;
    final bool nearOneMonth    = inactiveDays >= 20 && inactiveDays <= 30;
    final Color warningColor   = overOneMonth  ? Colors.red.shade700
                                : nearOneMonth ? Colors.orange.shade700
                                :                Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              blurRadius: 12,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header row ──
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.toggle_on_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Daily Availability",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
          ),
          const SizedBox(width: 8),
          // Today's status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAvailable
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isAvailable
                      ? Colors.green.shade200
                      : Colors.red.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAvailable
                          ? Colors.green.shade600
                          : Colors.red.shade500)),
              const SizedBox(width: 5),
              Text(
                isAvailable ? "Online Today" : "Offline Today",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? Colors.green.shade700
                        : Colors.red.shade600),
              ),
            ]),
          ),
        ]),

        const SizedBox(height: 16),

        // ── Big status indicator ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAvailable
                  ? [Colors.green.shade50, Colors.teal.shade50]
                  : [Colors.red.shade50, Colors.orange.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isAvailable
                    ? Colors.green.shade200
                    : Colors.red.shade200),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAvailable
                    ? Colors.green.shade100
                    : Colors.red.shade100,
              ),
              child: Icon(
                isAvailable
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                color: isAvailable
                    ? Colors.green.shade700
                    : Colors.red.shade600,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                isAvailable ? "Currently Available" : "Currently Unavailable",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isAvailable
                        ? Colors.green.shade800
                        : Colors.red.shade700),
              ),
              const SizedBox(height: 4),
              if (availabilityLocked && !isAvailable)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 11, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Locked — Admin action required to reactivate",
                        softWrap: true,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                            height: 1.3),
                      ),
                    ),
                  ],
                )
              else if (!isAvailable && lastUnavailableAt.isNotEmpty)
                Text(
                  "Offline since: ${_formatDate(lastUnavailableAt)}",
                  softWrap: true,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]),
                )
              else if (isAvailable && lastAvailableAt.isNotEmpty)
                Text(
                  "Online since: ${_formatDate(lastAvailableAt)}",
                  softWrap: true,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]),
                ),
            ])),
          ]),
        ),

        // ── Inactive days warning ──
        if (!isAvailable && inactiveDays > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: warningColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: warningColor.withOpacity(0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                overOneMonth
                    ? Icons.warning_rounded
                    : Icons.info_outline_rounded,
                color: warningColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                  "Inactive for $inactiveDays day${inactiveDays == 1 ? '' : 's'}",
                  softWrap: true,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: warningColor),
                ),
                if (overOneMonth)
                  Text(
                    "Auto-locked: inactive > 30 days. Only admin can reactivate.",
                    softWrap: true,
                    style: TextStyle(
                        fontSize: 11,
                        color: warningColor.withOpacity(0.85)),
                  )
                else if (nearOneMonth)
                  Text(
                    "Will be auto-locked after 30 days of inactivity.",
                    softWrap: true,
                    style: TextStyle(
                        fontSize: 11,
                        color: warningColor.withOpacity(0.85)),
                  ),
              ])),
            ]),
          ),
        ],

        const SizedBox(height: 16),

        // ── Admin toggle button ──
        SizedBox(
          width: double.infinity,
          child: isAvailable
              ? _btn(
                  "Mark Unavailable (Lock)",
                  Icons.wifi_off_rounded,
                  Colors.orange.shade700,
                  () => _setAvailability(false),
                )
              : _btn(
                  availabilityLocked
                      ? "Reactivate Caregiver"
                      : "Mark Available",
                  Icons.wifi_rounded,
                  Colors.green.shade600,
                  () => _setAvailability(true),
                ),
        ),

        // ── Daily history calendar grid ──
        if (dailyHistory.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text("Last 30 Days",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 10),
          _dailyHistoryGrid(),
        ],
      ]),
    );
  }

  // ── Calendar-style dot grid for daily history ──
  Widget _dailyHistoryGrid() {
    // Build a map of date → is_available
    final Map<String, bool> statusMap = {};
    for (final row in dailyHistory) {
      final raw = row["status_date"]?.toString() ?? "";
      final date = raw.length >= 10 ? raw.substring(0, 10) : raw;
      statusMap[date] =
          (row["is_available"] == 1 || row["is_available"] == true);
    }

    final today = DateTime.now();
    final days = List.generate(
        30, (i) => today.subtract(Duration(days: 29 - i)));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        const int columns = 10;
        const double spacing = 5;
        final double cellSize =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: days.map((d) {
            final key =
                "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
            final isToday = (d.day == today.day &&
                d.month == today.month &&
                d.year == today.year);
            final hasData = statusMap.containsKey(key);
            final avail  = hasData ? statusMap[key]! : null;

            Color bgColor;
            if (!hasData)      bgColor = const Color(0xFFEEEEEE);
            else if (avail!)   bgColor = Colors.green.shade400;
            else               bgColor = Colors.red.shade300;

            return Tooltip(
              message:
                  "$key: ${!hasData ? 'No data' : (avail! ? 'Available' : 'Unavailable')}",
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(5),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: isToday
                    ? Center(
                        child: Icon(Icons.circle,
                            size: cellSize * 0.3,
                            color: Colors.white.withOpacity(0.9)))
                    : null,
              ),
            );
          }).toList(),
        );
      }),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 6, children: [
        _legendDot(Colors.green.shade400, "Available"),
        _legendDot(Colors.red.shade300, "Unavailable"),
        _legendDot(const Color(0xFFEEEEEE), "No data"),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.primary, width: 2)),
          ),
          const SizedBox(width: 4),
          Text("Today",
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ]),
      ]),
    ]);
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      );

  String _formatDate(String raw) {
    if (raw.isEmpty) return "N/A";
    try {
      final dt = DateTime.parse(raw).toLocal();
      return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return raw;
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (loading)
      return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Center(
              child: CircularProgressIndicator(color: AppColors.primary)));

    final user      = data?["user"]            ?? {};
    final profile   = data?["profile"]         ?? {};
    final docs      = data?["documents"]        ?? {};
    final stats     = data?["statistics"]       ?? {};
    final earn      = data?["earnings"]         ?? {};
    final orders    = (data?["recent_orders"]   as List?) ?? [];
    final earns     = (data?["recent_earnings"] as List?) ?? [];
    final profileImg =
        profile["profile_image"]?.toString().isNotEmpty == true
            ? profile["profile_image"]
            : user["profile_image"];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SingleChildScrollView(
        child: Column(children: [

          // ── HEADER ──────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 0),
            decoration: const BoxDecoration(
              gradient: AppColors.gradient,
            ),
            child: Column(children: [
              // Nav row
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text("Caregiver Details",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                ),
                // Blocked badge
                if (isBlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text("BLOCKED",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ]),
                  ),
              ]),

              const SizedBox(height: 24),

              // Profile hero
              Column(children: [
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 16,
                            color: Colors.black.withOpacity(0.2))
                      ],
                    ),
                    child: ClipOval(child: _avatar(profileImg)),
                  ),
                  if (isBlocked)
                    Positioned.fill(
                        child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5)),
                      child: const Icon(Icons.block,
                          color: Colors.red, size: 36),
                    )),
                ]),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "${user["first_name"] ?? ""} ${user["last_name"] ?? ""}"
                        .trim(),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(user["mobile"] ?? "",
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(user["email"] ?? "",
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ),
                const SizedBox(height: 12),

                // Status pills row
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                  // Account status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBlocked
                          ? Colors.red.shade600
                          : Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Icon(
                          isBlocked
                              ? Icons.block
                              : Icons.verified_rounded,
                          color: Colors.white,
                          size: 13),
                      const SizedBox(width: 6),
                      Text(
                          isBlocked
                              ? "Account Blocked"
                              : "Account Active",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),

                  // Online/Offline pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? Colors.green.withOpacity(0.30)
                          : Colors.red.withOpacity(0.30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAvailable
                                  ? Colors.greenAccent
                                  : Colors.redAccent)),
                      const SizedBox(width: 6),
                      Text(
                          isAvailable ? "Online" : "Offline",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),

                const SizedBox(height: 24),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // ── AVAILABILITY MANAGEMENT CARD ─────────────────────────────────
          _availabilityCard(),

          const SizedBox(height: 16),

          // ── JOB STATISTICS ───────────────────────────────────────────────
          _section(
              "Job Statistics",
              Icons.bar_chart_rounded,
              Row(children: [
                _statCell("Total", "${stats["total_orders"] ?? 0}",
                    AppColors.primary, Icons.receipt_long_rounded),
                _statCell(
                    "Done",
                    "${stats["completed_orders"] ?? 0}",
                    const Color(0xFF00897B),
                    Icons.check_circle_rounded),
                _statCell(
                    "Active",
                    "${stats["active_orders"] ?? 0}",
                    const Color(0xFF1E88E5),
                    Icons.autorenew_rounded),
                _statCell(
                    "Cancelled",
                    "${stats["cancelled_orders"] ?? 0}",
                    const Color(0xFFE53935),
                    Icons.cancel_rounded),
              ])),

          const SizedBox(height: 16),

          // ── EARNINGS SUMMARY ─────────────────────────────────────────────
          _section(
              "Earnings Summary",
              Icons.account_balance_wallet_rounded,
              Row(children: [
                _earnCell(
                    "Total Earned",
                    "₹${earn["total_earned"] ?? 0}",
                    const Color(0xFF00897B),
                    Icons.trending_up_rounded),
                _earnCell(
                    "Paid Out",
                    "₹${earn["paid_earnings"] ?? 0}",
                    AppColors.primary,
                    Icons.payments_rounded),
                _earnCell(
                    "Pending",
                    "₹${earn["pending_earnings"] ?? 0}",
                    const Color(0xFFFB8C00),
                    Icons.hourglass_top_rounded),
              ])),

          const SizedBox(height: 16),

          // ── PROFILE INFO ─────────────────────────────────────────────────
          _section(
              "Profile Info",
              Icons.person_outline_rounded,
              Column(children: [
                _infoRow("Caregiver Type",
                    profile["caregiver_type"] ?? "N/A",
                    Icons.badge_rounded),
                _infoRow("Experience",
                    profile["experience"] ?? "N/A",
                    Icons.work_outline_rounded),
                _infoRow("Availability",
                    profile["availability"] ?? "N/A",
                    Icons.access_time_rounded),
                _infoRow(
                    "Services",
                    profile["services"]?.toString().isNotEmpty == true
                        ? profile["services"]
                        : "N/A",
                    Icons.medical_services_outlined),
              ])),

          const SizedBox(height: 16),

          // ── DOCUMENTS ────────────────────────────────────────────────────
          _section(
              "Uploaded Documents",
              Icons.folder_rounded,
              Column(children: [
                _docCard("Aadhaar Front", docs["aadhaar_front"]),
                _docCard("Aadhaar Back",  docs["aadhaar_back"]),
                _docCard("PAN Card",      docs["pan_card"]),
                _docCard("Certificate",   docs["certificate"]),
              ])),

          const SizedBox(height: 16),

          // ── RECENT ORDERS ────────────────────────────────────────────────
          if (orders.isNotEmpty) ...[
            _section(
                "Recent Orders",
                Icons.receipt_rounded,
                Column(
                    children: orders
                        .map((o) => _orderTile(o as Map))
                        .toList())),
            const SizedBox(height: 16),
          ],

          // ── RECENT EARNINGS ──────────────────────────────────────────────
          if (earns.isNotEmpty) ...[
            _section(
                "Recent Earnings",
                Icons.account_balance_wallet_outlined,
                Column(
                    children: earns
                        .map((e) => _earningTile(e as Map))
                        .toList())),
            const SizedBox(height: 16),
          ],

          // ── ACTION BUTTONS ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: _btn(
                        "Approve",
                        Icons.check_circle_outline_rounded,
                        AppColors.primary,
                        _approve)),
                const SizedBox(width: 10),
                Expanded(
                    child: _btn(
                        "Reject",
                        Icons.cancel_outlined,
                        Colors.red.shade600,
                        _reject)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: isBlocked
                    ? _btn(
                        "Unblock User",
                        Icons.lock_open_rounded,
                        Colors.green.shade600,
                        () => _blockUnblock(false))
                    : _btn(
                        "Block User",
                        Icons.block_rounded,
                        Colors.orange.shade700,
                        () => _blockUnblock(true)),
              ),
            ]),
          ),

          const SizedBox(height: 36),
        ]),
      ),
    );
  }
}