import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';
import 'admin_caregiver_details.dart';

class AdminCaregivers extends StatefulWidget {
  const AdminCaregivers({super.key});

  @override
  State<AdminCaregivers> createState() => _AdminCaregiversState();
}

class _AdminCaregiversState extends State<AdminCaregivers> {
  List _all  = [];   // full list from API
  List _shown = [];  // filtered list shown in UI
  bool loading = true;
  final TextEditingController _search = TextEditingController();
  Timer? _autoRefresh;

  // ── Filter state ─────────────────────────────────────────────────────────
  String _filterStatus = "all"; // all | pending | approved | rejected | blocked

  @override
  void initState() {
    super.initState();
    fetchCaregivers();
    // Auto-refresh every 30 seconds
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => fetchCaregivers(silent: true));
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future fetchCaregivers({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(Api.adminCaregivers));
      if (res.statusCode == 200) {
        _all = jsonDecode(res.body);
        _applyFilter();
      }
    } catch (e) {
      debugPrint("API ERROR: $e");
    }
    if (!silent) setState(() => loading = false);
  }

  void _applyFilter() {
    final query = _search.text.toLowerCase();
    setState(() {
      _shown = _all.where((c) {
        final name = "${c["first_name"]} ${c["last_name"]}".toLowerCase();
        final mobile = (c["mobile"] ?? "").toLowerCase();
        final matchSearch = query.isEmpty || name.contains(query) || mobile.contains(query);

        final status   = c["approval_status"] ?? "pending";
        final blocked  = c["is_blocked"] == 1 || c["is_blocked"] == true;

        bool matchFilter;
        if (_filterStatus == "all")      matchFilter = true;
        else if (_filterStatus == "blocked") matchFilter = blocked;
        else matchFilter = !blocked && status == _filterStatus;

        return matchSearch && matchFilter;
      }).toList();
    });
  }

  // ── Counts ────────────────────────────────────────────────────────────────
  int _count(String type) {
    if (type == "all")     return _all.length;
    if (type == "blocked") return _all.where((c) => c["is_blocked"] == 1 || c["is_blocked"] == true).length;
    return _all.where((c) {
      final blocked = c["is_blocked"] == 1 || c["is_blocked"] == true;
      return !blocked && c["approval_status"] == type;
    }).length;
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  _StatusStyle _statusStyle(Map c) {
    final blocked = c["is_blocked"] == 1 || c["is_blocked"] == true;
    if (blocked) return _StatusStyle("Blocked", Icons.block, Colors.red.shade600);
    switch (c["approval_status"]) {
      case "approved": return _StatusStyle("Approved", Icons.check_circle, Colors.green.shade600);
      case "rejected": return _StatusStyle("Rejected", Icons.cancel,        Colors.red.shade400);
      default:         return _StatusStyle("Pending",  Icons.hourglass_top, Colors.orange.shade600);
    }
  }

  String? _avatarUrl(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return null;
    if (raw.toString().startsWith("http")) return raw.toString();
    return "${Api.imageBase}/${raw.toString().replaceAll("\\", "/")}";
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(children: [

        // ── HEADER ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(children: [
            // Title row
            Row(children: [
              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Text("Caregivers",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: () => fetchCaregivers(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: "Refresh",
              ),
            ]),
            const SizedBox(height: 12),
            // Search bar
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by name or mobile...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () { _search.clear(); _applyFilter(); },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),

        // ── FILTER CHIPS ──────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip("all",      "All",      Icons.list_alt,      Colors.blueGrey),
              _chip("pending",  "Pending",  Icons.hourglass_top, Colors.orange.shade600),
              _chip("approved", "Approved", Icons.check_circle,  Colors.green.shade600),
              _chip("rejected", "Rejected", Icons.cancel,        Colors.red.shade400),
              _chip("blocked",  "Blocked",  Icons.block,         Colors.red.shade700),
            ]),
          ),
        ),

        // ── SUMMARY BAR ───────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem("Total",    _count("all"),      Icons.group,         Colors.white),
              _vDivider(),
              _summaryItem("Pending",  _count("pending"),  Icons.hourglass_top, Colors.yellow.shade200),
              _vDivider(),
              _summaryItem("Approved", _count("approved"), Icons.check_circle,  Colors.greenAccent.shade100),
              _vDivider(),
              _summaryItem("Blocked",  _count("blocked"),  Icons.block,         Colors.red.shade200),
            ],
          ),
        ),

        // ── LIST ──────────────────────────────────────────────
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _shown.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => fetchCaregivers(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: _shown.length,
                        itemBuilder: (_, i) => _caregiverCard(_shown[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  // ── Filter chip ───────────────────────────────────────────────────────────
  Widget _chip(String value, String label, IconData icon, Color color) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () { setState(() => _filterStatus = value); _applyFilter(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 5),
          Text(
            "$label (${_count(value)})",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Summary item ──────────────────────────────────────────────────────────
  Widget _summaryItem(String label, int count, IconData icon, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 3),
          Text("$count",
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color.withOpacity(0.85), fontSize: 10)),
        ],
      );

  Widget _vDivider() => Container(
        height: 36, width: 1, color: Colors.white.withOpacity(0.3));

  // ── Caregiver card ────────────────────────────────────────────────────────
  Widget _caregiverCard(Map c) {
    final name    = "${c["first_name"] ?? ""} ${c["last_name"] ?? ""}".trim();
    final mobile  = c["mobile"] ?? "";
    final imgUrl  = _avatarUrl(c["profile_image"]);
    final style   = _statusStyle(c);
    final blocked = c["is_blocked"] == 1 || c["is_blocked"] == true;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminCaregiverDetails(caregiver: c)),
        );
        if (result == true) fetchCaregivers(); // ✅ auto-refresh after action
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: blocked
              ? Border.all(color: Colors.red.shade300, width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [

            // Avatar
            Stack(children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: blocked ? Colors.red.shade300 : AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade100,
                  child: ClipOval(
                    child: imgUrl != null
                        ? Image.network(imgUrl, width: 52, height: 52, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, size: 26, color: Colors.grey))
                        : const Icon(Icons.person, size: 26, color: Colors.grey),
                  ),
                ),
              ),
              if (blocked)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.block, size: 13, color: Colors.red.shade600),
                  ),
                ),
            ]),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(mobile, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ]),
              ]),
            ),

            const SizedBox(width: 8),

            // Status badge + arrow
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.color.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(style.icon, size: 13, color: style.color),
                  const SizedBox(width: 4),
                  Text(style.label,
                      style: TextStyle(
                          color: style.color, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey[400]),
            ]),

          ]),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text("No caregivers found",
              style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text("Try changing your filter or search",
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ]),
      );
}

// ── Status style model ────────────────────────────────────────────────────────
class _StatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusStyle(this.label, this.icon, this.color);
}