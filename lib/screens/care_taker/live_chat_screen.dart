import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List messages = [];
  bool isLoading = true;
  bool isSending = false;
  int? userId;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── INIT ───────────────────────────────────────────────

  Future<void> _initializeChat() async {
    debugPrint("🔄 Initializing chat...");
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id");
    debugPrint("👤 userId from prefs: $userId");

    if (userId == null) {
      debugPrint("❌ No userId found in SharedPreferences");
      setState(() => isLoading = false);
      return;
    }

    await _fetchMessages();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchMessages(showLoader: false),
    );
  }

  // ─── FETCH ──────────────────────────────────────────────

  Future<void> _fetchMessages({bool showLoader = true}) async {
    if (showLoader) setState(() => isLoading = true);

    try {
      final url = Api.supportChat(userId!);
      debugPrint("📥 Fetching messages from: $url");

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      debugPrint("📥 Status: ${response.statusCode}");
      debugPrint("📥 Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        setState(() => messages = data["data"]);
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollToBottom();
        debugPrint("✅ Fetched ${messages.length} messages");
      } else {
        debugPrint("⚠️ API returned success=false: ${data['message']}");
      }
    } on TimeoutException {
      debugPrint("⏳ Fetch timed out");
    } catch (e, st) {
      debugPrint("❌ Fetch error: $e\n$st");
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ─── SEND ───────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    debugPrint("📤 Send tapped | text='$text' | userId=$userId");

    if (text.isEmpty) {
      debugPrint("⚠️ Aborted: message is empty");
      return;
    }
    if (userId == null) {
      debugPrint("⚠️ Aborted: userId is null");
      return;
    }
    if (isSending) {
      debugPrint("⚠️ Aborted: already sending");
      return;
    }

    setState(() => isSending = true);

    final body = jsonEncode({
      "userId": userId,
      "role": "care_taker",
      "sender": "user",
      "message": text,
    });

    debugPrint("📤 POST ${Api.sendSupportMessage}");
    debugPrint("📤 Body: $body");

    try {
      final response = await http
          .post(
            Uri.parse(Api.sendSupportMessage),
            headers: {"Content-Type": "application/json"},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint("📤 Status: ${response.statusCode}");
      debugPrint("📤 Response: ${response.body}");

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        debugPrint("✅ Message sent! id=${data['id']}");
        _messageController.clear();
        await _fetchMessages(showLoader: false);
      } else {
        debugPrint("❌ Send failed: ${data['message']}");
        _showSnack("Failed to send: ${data['message'] ?? 'Unknown error'}");
      }
    } on TimeoutException {
      debugPrint("⏳ Send timed out");
      _showSnack("Request timed out. Check your connection.");
    } catch (e, st) {
      debugPrint("❌ Send error: $e\n$st");
      _showSnack("Error: $e");
    }

    if (mounted) setState(() => isSending = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(String date) {
    try {
      return DateFormat("hh:mm a").format(DateTime.parse(date).toLocal());
    } catch (_) {
      return "";
    }
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date).toLocal();
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        return "Today";
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
        return "Yesterday";
      }
      return DateFormat("dd MMM yyyy").format(d);
    } catch (_) {
      return "";
    }
  }

  // ─── BUILD ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // WhatsApp bg

      appBar: _buildAppBar(),

      body: Column(
        children: [
          Expanded(child: _buildChatArea()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── APP BAR ────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 1,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Live Support",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Colors.greenAccent),
                    SizedBox(width: 5),
                    Text("Online",
                        style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CHAT AREA ──────────────────────────────────────────

  Widget _buildChatArea() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (messages.isEmpty) return _emptyState();

    // Group by date
    final List<dynamic> items = [];
    String? lastDate;
    for (final msg in messages) {
      final dateStr = _formatDate(msg["created_at"].toString());
      if (dateStr != lastDate) {
        items.add({"_type": "divider", "label": dateStr});
        lastDate = dateStr;
      }
      items.add(msg);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item["_type"] == "divider") return _dateDivider(item["label"]);
        final isUser = item["sender"] == "user";
        return _messageBubble(
          isUser: isUser,
          message: item["message"] ?? "",
          time: _formatTime(item["created_at"].toString()),
        );
      },
    );
  }

  // ─── DATE DIVIDER ───────────────────────────────────────

  Widget _dateDivider(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ─── EMPTY STATE ────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 18),
            const Text("Start a Conversation",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Our support team is available 24/7 to help you.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.6)),
          ],
        ),
      ),
    );
  }

  // ─── BUBBLE ─────────────────────────────────────────────

  Widget _messageBubble({
    required bool isUser,
    required String message,
    required String time,
  }) {
    const userBg = Color(0xFFDCF8C6);   // WhatsApp green
    const adminBg = Colors.white;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isUser ? userBg : adminBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 16),
          ),
          boxShadow: [
            BoxShadow(blurRadius: 4, offset: const Offset(0, 2), color: Colors.black.withOpacity(0.08)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message,
                style: const TextStyle(fontSize: 14.5, color: Colors.black87, height: 1.4)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 14, color: Colors.blue.shade400),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── INPUT BAR ──────────────────────────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: const Color(0xFFECE5DD),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.06)),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: "Message",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: isSending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      color: AppColors.primary.withOpacity(0.35),
                    ),
                  ],
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}