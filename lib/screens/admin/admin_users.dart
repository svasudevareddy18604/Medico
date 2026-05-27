import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';
import 'admin_careseeker_details_screen.dart'; // ← new screen

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  List _all   = [];
  List _shown = [];
  bool loading = true;
  String _filter = "all";
  final TextEditingController _search = TextEditingController();
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) => fetchUsers(silent: true));
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future fetchUsers({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(Api.adminCareSeekers));
      if (res.statusCode == 200) {
        _all = jsonDecode(res.body);
        _applyFilter();
      }
    } catch (e) {
      debugPrint("USERS ERROR: $e");
    }
    if (!silent) setState(() => loading = false);
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _shown = _all.where((u) {
        final name   = "${u['first_name']} ${u['last_name']}".toLowerCase();
        final mobile = (u['mobile'] ?? '').toLowerCase();
        final email  = (u['email']  ?? '').toLowerCase();
        final matchQ = q.isEmpty || name.contains(q) || mobile.contains(q) || email.contains(q);
        final blocked = u['is_blocked'] == 1 || u['is_blocked'] == true;
        final matchF = _filter == "all" ? true : _filter == "blocked" ? blocked : !blocked;
        return matchQ && matchF;
      }).toList();
    });
  }

  int _count(String type) {
    if (type == "all")     return _all.length;
    if (type == "blocked") return _all.where((u) => u['is_blocked'] == 1 || u['is_blocked'] == true).length;
    return _all.where((u) => u['is_blocked'] != 1 && u['is_blocked'] != true).length;
  }

  Future _toggleBlock(Map user) async {
    final blocked = user['is_blocked'] == 1 || user['is_blocked'] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(blocked ? "Unblock User" : "Block User",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(blocked
            ? "This user will be unblocked and can login again."
            : "This user will be blocked and cannot login."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blocked ? Colors.green.shade600 : Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(blocked ? "Unblock" : "Block"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.put(
        Uri.parse(Api.blockUser(user['id'])),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_blocked": blocked ? 0 : 1}),
      );
      _toast(blocked ? "✅ User Unblocked!" : "🚫 User Blocked",
          color: blocked ? Colors.green.shade600 : Colors.orange.shade700);
      fetchUsers(silent: true);
    } catch (e) {
      _toast("Network error", isError: true);
    }
  }

  void _toast(String msg, {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.cancel : Icons.check_circle, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color ?? (isError ? Colors.red.shade600 : AppColors.primary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(children: [
        // ── HEADER ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Admin Dashboard", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text("Care Seekers",    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
              const Spacer(),
              IconButton(onPressed: fetchUsers, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _search,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by name, mobile or email...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () { _search.clear(); _applyFilter(); })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),

        // ── FILTER CHIPS ─────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(children: [
            _chip("all",     "All",     Icons.list_alt,    Colors.blueGrey),
            _chip("active",  "Active",  Icons.check_circle, Colors.green.shade600),
            _chip("blocked", "Blocked", Icons.block,        Colors.red.shade600),
          ]),
        ),

        // ── SUMMARY BAR ───────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _summaryItem("Total",   _count("all"),     Icons.group,        Colors.white),
            _vDivider(),
            _summaryItem("Active",  _count("active"),  Icons.check_circle, Colors.greenAccent.shade100),
            _vDivider(),
            _summaryItem("Blocked", _count("blocked"), Icons.block,        Colors.red.shade200),
          ]),
        ),

        // ── LIST ──────────────────────────────────────────────────────────────
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _shown.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => fetchUsers(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        itemCount: _shown.length,
                        itemBuilder: (_, i) => _userCard(_shown[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _chip(String value, String label, IconData icon, Color color) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _applyFilter(); },
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
          Text("$label (${_count(value)})",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _summaryItem(String label, int count, IconData icon, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 3),
          Text("$count", style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label,    style: TextStyle(color: color.withOpacity(0.85), fontSize: 10)),
        ],
      );

  Widget _vDivider() => Container(height: 36, width: 1, color: Colors.white.withOpacity(0.3));

  // ── User card — tap → details screen ─────────────────────────────────────
  Widget _userCard(Map user) {
    final blocked  = user['is_blocked'] == 1 || user['is_blocked'] == true;
    final initials = (user['first_name'] ?? 'U')[0].toUpperCase();

    return GestureDetector(
      // ✅ TAP → navigate to details
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminCareSeekerDetails(user: user)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: blocked ? Colors.red.shade200 : Colors.transparent, width: 1.5),
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
                  border: Border.all(color: blocked ? Colors.red.shade300 : AppColors.primary.withOpacity(0.4), width: 2),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: blocked ? Colors.red.shade50 : AppColors.primary.withOpacity(0.12),
                  child: Text(initials, style: TextStyle(color: blocked ? Colors.red.shade600 : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              if (blocked)
                Positioned(bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.block, size: 13, color: Colors.red.shade600),
                  ),
                ),
            ]),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.phone_outlined, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(user['mobile'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.email_outlined, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(child: Text(user['email'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 7),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: blocked ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: blocked ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(blocked ? Icons.block : Icons.check_circle, size: 12, color: blocked ? Colors.red.shade600 : Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(blocked ? "Blocked" : "Active",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: blocked ? Colors.red.shade600 : Colors.green.shade600)),
                  ]),
                ),
                const SizedBox(width: 6),
                // "View Details" hint
                Text("Tap to view →", style: TextStyle(fontSize: 10, color: AppColors.primary.withOpacity(0.7), fontStyle: FontStyle.italic)),
              ]),
            ])),

            const SizedBox(width: 10),

            // Block / Unblock button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blocked ? Colors.green.shade600 : Colors.red.shade500,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => _toggleBlock(user),
              child: Text(blocked ? "Unblock" : "Block",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text("No users found", style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text("Try changing your filter or search", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ]),
      );
}