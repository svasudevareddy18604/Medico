import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';
import 'admin_chat_screen.dart';          // ← AdminChatScreen lives here

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});
  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen>
    with SingleTickerProviderStateMixin {

  List chatUsers = [];
  List allCareSeekers = [];
  List allCareTakers = [];
  Map<int, int> unreadMap = {};
  bool loading = true;
  String search = "";
  late TabController tabCtrl;

  @override
  void initState() { super.initState(); tabCtrl = TabController(length: 3, vsync: this); load(); }

  @override
  void dispose() { tabCtrl.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r1 = await http.get(Uri.parse("${Api.baseUrl}/chat/admin/users"));
      final d1 = jsonDecode(r1.body);
      if (d1["success"]) {
        chatUsers = d1["data"];
        for (var u in chatUsers) {
          final r = await http.get(Uri.parse("${Api.baseUrl}/chat/admin/unread/${u["id"]}"));
          final d = jsonDecode(r.body);
          if (d["success"]) unreadMap[u["id"] as int] = d["unread"] ?? 0;
        }
      }
      final r2 = await http.get(Uri.parse("${Api.baseUrl}/chat/admin/all-users"));
      final d2 = jsonDecode(r2.body);
      if (d2["success"]) {
        allCareSeekers = d2["care_seekers"] ?? [];
        allCareTakers  = d2["care_takers"]  ?? [];
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  List _filter(List src) {
    if (search.isEmpty) return src;
    return src.where((u) => "${u["first_name"]} ${u["last_name"]}"
        .toLowerCase().contains(search.toLowerCase())).toList();
  }

  String _time(String? t) {
    if (t == null) return "";
    try {
      final dt = DateTime.parse(t).toLocal();
      final now = DateTime.now();
      return (dt.day == now.day && dt.month == now.month)
          ? "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}"
          : "${dt.day}/${dt.month}";
    } catch (_) { return ""; }
  }

  Color _roleColor(String? role) => role == "care_taker" ? Colors.indigo : Colors.teal;

  Widget _avatar(Map u, {double radius = 24}) {
    final img = u["profile_image"]?.toString() ?? "";
    final color = _roleColor(u["role"]?.toString());
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.12),
      backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
      child: img.isEmpty ? Text(
        (u["first_name"] ?? "?")[0].toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: radius * 0.72),
      ) : null,
    );
  }

  void _openChat(Map u) async {
    final id = u["id"] as int;
    // Clear unread immediately on open
    if ((unreadMap[id] ?? 0) > 0) setState(() => unreadMap[id] = 0);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AdminChatScreen(
        userId: id,
        name: "${u["first_name"] ?? ""} ${u["last_name"] ?? ""}".trim(),
        profileImage: u["profile_image"]?.toString() ?? "",
        role: u["role"]?.toString() ?? "",
      ),
    ));
    load(); // refresh on return
  }

  Widget _chatTile(Map u) {
    final id = u["id"] as int;
    final name = "${u["first_name"] ?? ""} ${u["last_name"] ?? ""}".trim();
    final lastMsg = u["last_message"]?.toString() ?? "Tap to start chat";
    final unread = unreadMap[id] ?? 0;
    final role = u["role"]?.toString() ?? "";

    return InkWell(
      onTap: () => _openChat(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Stack(children: [
            _avatar(u),
            if (unread > 0) Positioned(right: 0, top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text("$unread",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              )),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name,
                style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15, color: Colors.black87),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(_time(u["last_time"]?.toString()),
                style: TextStyle(fontSize: 11,
                  color: unread > 0 ? AppColors.primary : Colors.grey.shade400,
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _roleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(role == "care_taker" ? "Caretaker" : "Care Seeker",
                  style: TextStyle(fontSize: 10, color: _roleColor(role), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(lastMsg,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12,
                  color: unread > 0 ? Colors.black87 : Colors.grey.shade500,
                  fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal))),
              if (unread > 0) Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _userTile(Map u) {
    final name = "${u["first_name"] ?? ""} ${u["last_name"] ?? ""}".trim();
    final role = u["role"]?.toString() ?? "";
    return InkWell(
      onTap: () => _openChat(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _avatar(u),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 12, color: _roleColor(role)),
              const SizedBox(width: 4),
              Text("Tap to chat", style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          ])),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
        ]),
      ),
    );
  }

  Widget _listView(List items, {bool isChatTile = true}) {
    final list = _filter(items);
    if (list.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Colors.grey.shade200),
      const SizedBox(height: 12),
      Text("No users found", style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
    ]));
    return ListView.separated(
      padding: const EdgeInsets.only(top: 6, bottom: 20),
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 70, color: Colors.grey.shade200),
      itemBuilder: (_, i) => isChatTile ? _chatTile(list[i]) : _userTile(list[i]),
    );
  }

  Widget _tabItem(IconData icon, String label, int count, {bool isUnread = false}) =>
    Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16),
      const SizedBox(width: 5),
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isUnread ? Colors.red : Colors.white24,
            borderRadius: BorderRadius.circular(8)),
          child: Text("$count", style: const TextStyle(fontSize: 10, color: Colors.white)),
        ),
      ],
    ]));

  @override
  Widget build(BuildContext context) {
    final totalUnread = unreadMap.values.fold(0, (a, b) => a + b);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(8, 52, 16, 0),
          decoration: const BoxDecoration(gradient: AppColors.gradient),
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text("Support Chats",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              if (totalUnread > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  child: Text("$totalUnread new",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: load),
            ]),
            const SizedBox(height: 10),

            // Search
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
              child: TextField(
                onChanged: (v) => setState(() => search = v),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Search by name...",
                  hintStyle: TextStyle(color: Colors.white60),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                  border: InputBorder.none, isDense: true),
              ),
            ),
            const SizedBox(height: 10),

            // Tabs — labelPadding: zero fixes the overflow
            TabBar(
              controller: tabCtrl,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelPadding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                _tabItem(Icons.headset_mic_rounded, "Chats", totalUnread, isUnread: true),
                _tabItem(Icons.person_search_rounded, "Seekers", allCareSeekers.length),
                _tabItem(Icons.medical_services_rounded, "Takers", allCareTakers.length),
              ],
            ),
          ]),
        ),

        // Body
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else
          Expanded(child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: load,
            child: TabBarView(
              controller: tabCtrl,
              children: [
                _listView(chatUsers, isChatTile: true),
                _listView(allCareSeekers, isChatTile: false),
                _listView(allCareTakers, isChatTile: false),
              ],
            ),
          )),
      ]),
    );
  }
}