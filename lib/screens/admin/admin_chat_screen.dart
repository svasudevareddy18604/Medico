import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminChatScreen extends StatefulWidget {
  final int userId;
  final String name, profileImage, role;
  const AdminChatScreen({super.key, required this.userId, required this.name,
    this.profileImage = "", this.role = ""});
  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  late IO.Socket socket;
  final msgCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  List<Map<String, dynamic>> messages = [];
  bool connected = false, loadingMsgs = true, sending = false;

  @override
  void initState() { super.initState(); loadMessages(); connectSocket(); }

  @override
  void dispose() { socket.dispose(); msgCtrl.dispose(); scrollCtrl.dispose(); super.dispose(); }

  void connectSocket() {
    socket = IO.io(Api.imageBase,
      IO.OptionBuilder().setTransports(['websocket']).enableAutoConnect().setTimeout(20000).build());
    socket.onConnect((_) {
      setState(() => connected = true);
      socket.emit("joinRoom", {"userId": widget.userId});
    });
    socket.onDisconnect((_) => setState(() => connected = false));
    // Only receive real-time messages FROM the user side
    socket.on("receiveMessage", (data) {
      final msg = Map<String, dynamic>.from(data);
      if (msg["sender"] != "admin") {
        setState(() => messages.add(msg));
        _scrollBottom();
      }
    });
  }

  Future<void> loadMessages() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/chat/${widget.userId}"));
      final data = jsonDecode(res.body);
      if (data["success"]) {
        setState(() { messages = List<Map<String, dynamic>>.from(data["data"]); loadingMsgs = false; });
        _scrollBottom();
      }
    } catch (_) { setState(() => loadingMsgs = false); }
  }

  // ✅ HTTP POST saves to DB, then socket notifies user in real-time
  Future<void> sendMessage() async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);
    msgCtrl.clear();

    // Optimistic UI
    final optimistic = {"user_id": widget.userId, "sender": "admin",
      "message": text, "created_at": DateTime.now().toIso8601String()};
    setState(() => messages.add(optimistic));
    _scrollBottom();

    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/chat/send"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": widget.userId, "message": text, "sender": "admin"}),
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        socket.emit("sendMessage", {"userId": widget.userId, "message": text, "sender": "admin"});
      } else {
        setState(() => messages.remove(optimistic));
        _snack("Failed to send. Try again.");
      }
    } catch (_) {
      setState(() => messages.remove(optimistic));
      _snack("Network error. Try again.");
    }
    setState(() => sending = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _scrollBottom() => Future.delayed(const Duration(milliseconds: 200), () {
    if (scrollCtrl.hasClients) scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  });

  String _time(dynamic t) {
    try {
      final dt = DateTime.parse(t.toString()).toLocal();
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) { return ""; }
  }

  bool _isSameDay(int i) {
    if (i == 0) return false;
    try {
      final a = DateTime.parse(messages[i - 1]["created_at"].toString()).toLocal();
      final b = DateTime.parse(messages[i]["created_at"].toString()).toLocal();
      return a.day == b.day && a.month == b.month;
    } catch (_) { return true; }
  }

  String _dayLabel(dynamic t) {
    try {
      final dt = DateTime.parse(t.toString()).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month) return "Today";
      if (dt.day == now.day - 1 && dt.month == now.month) return "Yesterday";
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) { return ""; }
  }

  Color get _roleColor => widget.role == "care_taker" ? Colors.indigo : Colors.teal;
  String get _roleLabel => widget.role == "care_taker" ? "Care Taker" : "Care Seeker";

  Widget _avatar({double radius = 20}) {
    final img = widget.profileImage;
    return CircleAvatar(
      radius: radius,
      backgroundColor: _roleColor.withOpacity(0.15),
      backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
      child: img.isEmpty ? Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
        style: TextStyle(color: _roleColor, fontWeight: FontWeight.bold, fontSize: radius * 0.75)) : null,
    );
  }

  Widget _dateDivider(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(children: [
      Expanded(child: Divider(color: Colors.grey.shade300)),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
        child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Divider(color: Colors.grey.shade300)),
    ]),
  );

  Widget _bubble(Map<String, dynamic> msg, bool showAvatar) {
    final isAdmin = msg["sender"] == "admin";
    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 2, left: isAdmin ? 48 : 0, right: isAdmin ? 0 : 48),
      child: Row(
        mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAdmin) ...[
            showAvatar ? _avatar(radius: 16) : const SizedBox(width: 32),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAdmin ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isAdmin ? 18 : 4),
                  bottomRight: Radius.circular(isAdmin ? 4 : 18)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(msg["message"] ?? "",
                  style: TextStyle(color: isAdmin ? Colors.white : Colors.black87, fontSize: 14, height: 1.4)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_time(msg["created_at"]),
                    style: TextStyle(fontSize: 10, color: isAdmin ? Colors.white60 : Colors.grey.shade400)),
                  if (isAdmin) ...[const SizedBox(width: 3),
                    const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70)],
                ]),
              ]),
            ),
          ),
          if (isAdmin) const SizedBox(width: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F4F8),
    body: Column(children: [

      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(4, 50, 16, 14),
        decoration: const BoxDecoration(gradient: AppColors.gradient),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
          Stack(clipBehavior: Clip.none, children: [
            Container(decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
              child: _avatar(radius: 22)),
            Positioned(bottom: 0, right: 0,
              child: Container(width: 11, height: 11,
                decoration: BoxDecoration(
                  color: connected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10)),
                child: Text(_roleLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
              const SizedBox(width: 6),
              Text(connected ? "● Online" : "● Connecting",
                style: TextStyle(color: connected ? const Color(0xFFA5D6A7) : Colors.white54, fontSize: 11)),
            ]),
          ])),
        ]),
      ),

      // Messages
      Expanded(
        child: loadingMsgs
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : messages.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 52, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text("No messages yet", style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                const SizedBox(height: 4),
                Text("Start the conversation below",
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
              ]))
            : ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isAdmin = msg["sender"] == "admin";
                  final showAvatar = !isAdmin && (i == 0 || messages[i - 1]["sender"] == "admin");
                  return Column(children: [
                    if (!_isSameDay(i)) _dateDivider(_dayLabel(msg["created_at"])),
                    _bubble(msg, showAvatar),
                  ]);
                },
              ),
      ),

      // Input
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F9),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: msgCtrl, maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: "Type a reply...", border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14)),
                onSubmitted: (_) => sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: !sending ? AppColors.gradient : null,
                color: sending ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
                boxShadow: !sending
                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]
                  : []),
              child: sending
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    ]),
  );
}