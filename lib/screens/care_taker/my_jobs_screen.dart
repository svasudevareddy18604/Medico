import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../config/api.dart';
import 'order_details_screen.dart';

class MyJobsScreen extends StatefulWidget {
  final int userId;
  const MyJobsScreen({super.key, required this.userId});
  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF1B7F6E);
  static const _gradient = LinearGradient(
      colors: [Color(0xFF1B7F6E), Color(0xFF25A98F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const _sortOrder = ["ACCEPTED", "IN_PROGRESS", "COMPLETED", "CARETAKER_CANCELLED"];

  List   _jobs    = [];
  bool   _loading = true;
  bool   _busy    = false;
  String _filter  = "ALL";
  Timer? _timer;
  late AnimationController _anim;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _loadJobs();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _loadJobs(silent: true));
  }

  @override
  void dispose() { _timer?.cancel(); _anim.dispose(); super.dispose(); }

  Future<void> _loadJobs({bool silent = false}) async {
    try {
      if (!silent && mounted) setState(() => _loading = true);
      final res  = await http.get(Uri.parse("${Api.baseUrl}/caretaker/my-jobs/${widget.userId}"));
      final data = jsonDecode(res.body);
      if (mounted) {
        setState(() { _jobs = List.from(data["jobs"] ?? []); _loading = false; });
        if (!silent) _anim.forward(from: 0);
      }
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  List get _sorted {
    final filtered = _filter == "ALL"
        ? List.from(_jobs)
        : _jobs.where((j) => (j["status"] ?? "") == _filter).toList();
    filtered.sort((a, b) {
      final ai = _sortOrder.indexOf((a["status"] ?? "").toString());
      final bi = _sortOrder.indexOf((b["status"] ?? "").toString());
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });
    return filtered;
  }

  // ── Formatters ───────────────────────────────────────────────────────────
  String _fmtDate(dynamic d) {
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day.toString().padLeft(2,'0')} ${mo[dt.month-1]} ${dt.year}";
    } catch (_) { return d?.toString() ?? ""; }
  }

  String _fmtSlot(dynamic s) {
    if (s == null || s.toString().isEmpty) return "—";
    try {
      final parts = s.toString().split(":");
      final h = int.parse(parts[0]);
      final m = parts[1];
      return "${h % 12 == 0 ? 12 : h % 12}:$m ${h >= 12 ? 'PM' : 'AM'}";
    } catch (_) { return s.toString(); }
  }

  // ── Status helpers ───────────────────────────────────────────────────────
  String _statusLabel(String s) => switch (s) {
    "ACCEPTED"            => "Accepted",
    "IN_PROGRESS"         => "In Progress",
    "COMPLETED"           => "Completed",
    "CANCELLED"           => "Cancelled",
    "CARETAKER_CANCELLED" => "Cancelled by You",
    _                     => s,
  };

  Color _statusColor(String s) => switch (s) {
    "ACCEPTED"            => _primary,
    "IN_PROGRESS"         => const Color(0xFFF59E0B),
    "COMPLETED"           => const Color(0xFF1565C0),
    "CANCELLED"           => const Color(0xFFEF4444),
    "CARETAKER_CANCELLED" => const Color(0xFFEF4444),
    _                     => Colors.grey,
  };

  IconData _statusIcon(String s) => switch (s) {
    "ACCEPTED"            => Icons.handshake_rounded,
    "IN_PROGRESS"         => Icons.directions_run_rounded,
    "COMPLETED"           => Icons.check_circle_rounded,
    "CANCELLED"           => Icons.cancel_rounded,
    "CARETAKER_CANCELLED" => Icons.cancel_rounded,
    _                     => Icons.info_rounded,
  };

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5));
    final items = _sorted;
    return Column(children: [
      const SizedBox(height: 10),
      _filterRow(),
      const SizedBox(height: 6),
      Expanded(
        child: items.isEmpty
            ? _empty()
            : RefreshIndicator(
                onRefresh: _loadJobs, color: _primary,
                child: FadeTransition(
                  opacity: _fade,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _card(items[i]),
                  ),
                ),
              ),
      ),
    ]);
  }

  // ── Filter tabs ──────────────────────────────────────────────────────────
  Widget _filterRow() {
    const tabs = [
      ("ALL",                 "All",          _primary,                 Icons.grid_view_rounded),
      ("ACCEPTED",            "Accepted",     _primary,                 Icons.handshake_rounded),
      ("IN_PROGRESS",         "In Progress",  Color(0xFFF59E0B),        Icons.directions_run_rounded),
      ("COMPLETED",           "Completed",    Color(0xFF1565C0),        Icons.check_circle_rounded),
      ("CARETAKER_CANCELLED", "Cancelled",    Color(0xFFEF4444),        Icons.cancel_rounded),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: tabs.map((t) {
          final active = _filter == t.$1;
          final color  = t.$3;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() { _filter = t.$1; _anim.forward(from: 0); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? color : Colors.grey.shade300),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.$4, size: 13,
                      color: active ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(t.$2, style: TextStyle(
                      color: active ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Job card ─────────────────────────────────────────────────────────────
  Widget _card(Map job) {
    final status    = (job["status"]         ?? "").toString();
    final code      = (job["order_code"]     ?? "").toString();
    final services  = (job["services"]       ?? "").toString();
    final category  = (job["category"]       ?? "").toString();
    final location  = (job["location"]       ?? "").toString();
    final total     = (job["total"]          ?? 0).toString();
    final payMethod = (job["payment_method"] ?? "COD").toString();
    final payStatus = (job["payment_status"] ?? "").toString();
    final date      = _fmtDate(job["date"]);
    final slot      = _fmtSlot(job["slot"]);
    final color     = _statusColor(status);
    final isCancelled = status == "CANCELLED" || status == "CARETAKER_CANCELLED";
    // Location is restricted once a service is completed — same privacy
    // rule as the order details screen, applied here in the list card too.
    final isCompleted = status == "COMPLETED";

    return GestureDetector(
      onTap: () async {
        if (_busy) return;
        _busy = true;
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: job, userId: widget.userId)));
        _busy = false;
        _loadJobs(silent: true);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Row 1: code + status chip ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (code.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(7)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tag_rounded, size: 12, color: _primary),
                      const SizedBox(width: 3),
                      Text(code, style: const TextStyle(
                          color: _primary, fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ]),
                  ),
                const SizedBox(width: 8),
                // ✅ Status chip — uses Flexible to prevent overflow
                Flexible(child: _statusChip(status, color)),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: service name + amount ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(
                  services.isNotEmpty ? services : category,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: isCancelled
                        ? Colors.grey.shade500
                        : Colors.black87,
                    decoration: isCancelled
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                )),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: isCancelled ? null : _gradient,
                    color: isCancelled ? Colors.grey.shade200 : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("₹$total", style: TextStyle(
                      color: isCancelled ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Category badge
            if (category.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(category, style: TextStyle(
                    color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),

            // ── Cancelled banner ────────────────────────────────────────
            if (status == "CARETAKER_CANCELLED") ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFEF4444), size: 15),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      "You cancelled this booking. Admin will reassign.",
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
            ],

            // Info rows — location hidden once the service is completed
            if (!isCompleted) ...[
              _infoRow(Icons.location_on_rounded, location),
              const SizedBox(height: 5),
            ],
            _infoRow(Icons.calendar_today_rounded, date),
            const SizedBox(height: 5),
            _infoRow(Icons.access_time_rounded, slot),   // ✅ formatted time
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 10),

            // ── Bottom row: payment + view ──────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Wrap(spacing: 6, children: [
                _chip(payMethod, _primary),
                if (payStatus.toUpperCase() == "PAID")
                  _chip("PAID", const Color(0xFF1565C0)),
              ]),
              Row(children: [
                const Icon(Icons.touch_app_rounded, size: 13, color: _primary),
                const SizedBox(width: 4),
                const Text("View Details",
                    style: TextStyle(fontSize: 12, color: _primary,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Status chip — icon + label, never overflows ───────────────────────
  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 12, color: color),
        const SizedBox(width: 4),
        Text(_statusLabel(status),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11.5)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 15, color: Colors.grey.shade500),
    const SizedBox(width: 7),
    Expanded(child: Text(text,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
  ]);

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
  );

  Widget _empty() => FadeTransition(
    opacity: _fade,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 90, height: 90,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: _primary.withOpacity(0.08)),
          child: const Icon(Icons.work_off_rounded, size: 44, color: _primary)),
      const SizedBox(height: 18),
      const Text("No Services Found",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text("Try a different filter or pull to refresh.",
          style: TextStyle(fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 22),
      ElevatedButton.icon(
        onPressed: _loadJobs,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text("Refresh"),
        style: ElevatedButton.styleFrom(
            backgroundColor: _primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 0),
      ),
    ])),
  );
}