import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import 'package:medico/utils/app_colors.dart';

class LiveChatScreen extends StatefulWidget {
  final int userId;
  const LiveChatScreen({super.key, required this.userId});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  IO.Socket? socket;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  bool isSending = false, isConnected = false;
  String profileImage = "", firstName = "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMessages();
    _connectSocket();
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─── PROFILE ────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final res = await http
          .get(Uri.parse("${Api.userProfile}/${widget.userId}"));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          firstName = d["first_name"] ?? "";
          profileImage = d["profile_image"] ?? "";
        });
      }
    } catch (_) {}
  }

  String? _avatarUrl() {
    final img = profileImage.trim();
    if (img.isEmpty) return null;
    if (img.startsWith("http")) return img;
    final base = Api.imageBase.replaceAll(RegExp(r'/+$'), '');
    return "$base/${img.replaceFirst(RegExp(r'^/+'), '')}";
  }

  Widget _avatar({double r = 14}) {
    final url = _avatarUrl();
    return CircleAvatar(
      radius: r,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      child: url != null
          ? ClipOval(
              child: Image.network(
                url,
                width: r * 2,
                height: r * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  size: r,
                  color: AppColors.primary,
                ),
              ),
            )
          : Icon(Icons.person_rounded, size: r, color: AppColors.primary),
    );
  }

  // ─── MESSAGES ───────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/chat/${widget.userId}"));
      final data = jsonDecode(res.body);
      if (data["success"]) {
        setState(() => messages =
            List<Map<String, dynamic>>.from(data["data"]));
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  // ─── SOCKET ─────────────────────────────────────────────────────
  void _connectSocket() {
    socket = IO.io(
      Api.baseUrl.replaceAll("/api", ""),
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .build(),
    );
    socket!.onConnect((_) {
      if (mounted) setState(() => isConnected = true);
      socket!.emit("joinRoom", {"userId": widget.userId});
    });
    socket!.onDisconnect((_) {
      if (mounted) setState(() => isConnected = false);
    });
    socket!.on("receiveMessage", (data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data);
      final dup = messages.any((m) =>
          m["message"] == msg["message"] &&
          m["sender"] == msg["sender"] &&
          m["created_at"] == msg["created_at"]);
      if (!dup) setState(() => messages.add(msg));
      _scrollToBottom();
      isSending = false;
    });
  }

  // ─── SEND ────────────────────────────────────────────────────────
  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || isSending) return;
    if (socket == null || socket!.disconnected) {
      socket?.connect();
      socket?.once("connect", (_) => _send());
      return;
    }
    isSending = true;
    socket!.emit("sendMessage", {
      "userId": widget.userId,
      "message": text,
      "sender": "user",
      "created_at": DateTime.now().toIso8601String(),
    });
    _ctrl.clear();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _time(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  // ─── HEADER ─────────────────────────────────────────────────────
  Widget _header() => Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6)
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Support Chat",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? Colors.greenAccent
                              : Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        isConnected ? "Online" : "Connecting...",
                        style: TextStyle(
                          color: isConnected
                              ? Colors.greenAccent
                              : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );

  // ─── NOTICE ──────────────────────────────────────────────────────
  Widget _notice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2200)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFCC02).withOpacity(0.6),
        ),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            color: Color(0xFFF9A825), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Please communicate respectfully. Abusive messages may result in restricted support access.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.amber[200] : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ]),
    );
  }

  // ─── WELCOME BUBBLE ──────────────────────────────────────────────
  Widget _welcome(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 60, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(Icons.support_agent_rounded,
                color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black12,
                    blurRadius: 4,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Medico Support 👋",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Hello${firstName.isNotEmpty ? ', $firstName' : ''}! Welcome to Medico Support.\n\n"
                    "For faster help, please share:\n"
                    "• Your booking ID (if applicable)\n"
                    "• A brief description of your issue",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey[300]
                          : Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGE BUBBLE ──────────────────────────────────────────────
  Widget _bubble(BuildContext context, Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = msg["sender"] == "user";
    final time = _time(msg["created_at"] ?? "");

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMe ? 60 : 12,
        3,
        isMe ? 12 : 60,
        3,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(Icons.support_agent_rounded,
                  color: AppColors.primary, size: 14),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark
                            ? const Color(0xFF1A4731)
                            : const Color(0xFFDCF8C6))
                        : (isDark
                            ? const Color(0xFF1E1E2E)
                            : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black12,
                        blurRadius: 3,
                      )
                    ],
                  ),
                  child: Text(
                    msg["message"] ?? "",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.done_all,
                              size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            _avatar(r: 13),
          ],
        ],
      ),
    );
  }

  // ─── INPUT BAR ───────────────────────────────────────────────────
  Widget _inputBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      color: isDark ? const Color(0xFF1A1A2A) : const Color(0xFFF0F0F0),
      child: SafeArea(
        top: false,
        child: Row(children: [
          _avatar(r: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: "Type a message",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFECE5DD),
      body: Column(children: [
        _header(),
        _notice(context),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length + 1,
            itemBuilder: (ctx, i) =>
                i == 0 ? _welcome(ctx) : _bubble(ctx, messages[i - 1]),
          ),
        ),
        _inputBar(context),
      ]),
    );
  }
}