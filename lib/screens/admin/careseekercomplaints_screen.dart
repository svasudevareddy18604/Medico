import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';

/// ── Status (mirrors care-seeker side) ─────────────────────────────────
enum ComplaintStatus { pending, inProgress, resolved, rejected }

extension ComplaintStatusX on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.pending:
        return "Pending";
      case ComplaintStatus.inProgress:
        return "In Progress";
      case ComplaintStatus.resolved:
        return "Resolved";
      case ComplaintStatus.rejected:
        return "Rejected";
    }
  }

  Color get color {
    switch (this) {
      case ComplaintStatus.pending:
        return const Color(0xFFF5A524);
      case ComplaintStatus.inProgress:
        return const Color(0xFF2F86EB);
      case ComplaintStatus.resolved:
        return const Color(0xFF20A164);
      case ComplaintStatus.rejected:
        return AppColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintStatus.pending:
        return Icons.hourglass_top_rounded;
      case ComplaintStatus.inProgress:
        return Icons.autorenew_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      case ComplaintStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  String get value {
    switch (this) {
      case ComplaintStatus.pending:
        return "pending";
      case ComplaintStatus.inProgress:
        return "in_progress";
      case ComplaintStatus.resolved:
        return "resolved";
      case ComplaintStatus.rejected:
        return "rejected";
    }
  }

  static ComplaintStatus fromValue(String v) {
    switch (v) {
      case "in_progress":
        return ComplaintStatus.inProgress;
      case "resolved":
        return ComplaintStatus.resolved;
      case "rejected":
        return ComplaintStatus.rejected;
      default:
        return ComplaintStatus.pending;
    }
  }
}

/// ── Model (admin view — includes user info) ────────────────────────────
class AdminComplaint {
  final int id;
  final int userId;
  final String userName;
  final String userEmail;
  final String category;
  final String description;
  final List<String> images;
  final DateTime createdAt;
  final ComplaintStatus status;
  final String? adminResponse;
  final DateTime? resolvedAt;

  AdminComplaint({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.category,
    required this.description,
    required this.images,
    required this.createdAt,
    required this.status,
    this.adminResponse,
    this.resolvedAt,
  });

  static List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    List<dynamic> list;
    if (raw is String) {
      try {
        list = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        return [];
      }
    } else if (raw is List) {
      list = raw;
    } else {
      return [];
    }
    return list.map((p) {
      final s = p.toString();
      return s.startsWith("http") ? s : "${Api.imageBase}/$s";
    }).toList();
  }

  factory AdminComplaint.fromJson(Map<String, dynamic> json) {
    final first = (json["first_name"] ?? "").toString().trim();
    final last = (json["last_name"] ?? "").toString().trim();
    final fullName = ("$first $last").trim();

    return AdminComplaint(
      id: int.tryParse(json["id"].toString()) ?? 0,
      userId: int.tryParse(json["user_id"].toString()) ?? 0,
      userName: fullName.isEmpty ? "Unknown User" : fullName,
      userEmail: (json["email"] ?? "").toString(),
      category: (json["category"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      images: _parseImages(json["images"]),
      status: ComplaintStatusX.fromValue((json["status"] ?? "pending").toString()),
      adminResponse: json["admin_response"]?.toString(),
      createdAt: DateTime.tryParse(json["created_at"]?.toString() ?? "") ?? DateTime.now(),
      resolvedAt: json["resolved_at"] != null
          ? DateTime.tryParse(json["resolved_at"].toString())
          : null,
    );
  }
}

const List<String> _kFilterTabs = ["All", "Pending", "In Progress", "Resolved", "Rejected"];

/// ── Screen ──────────────────────────────────────────────────────────────
class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  bool _loading = true;
  String? _error;
  List<AdminComplaint> _all = [];
  String _activeFilter = "All";

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(Api.adminComplaints))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> raw = data["complaints"] ?? [];
        final list = raw
            .map((e) => AdminComplaint.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _all = list;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Failed to load complaints.";
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("ADMIN FETCH COMPLAINTS ERROR: $e");
      if (mounted) {
        setState(() {
          _error = "Something went wrong. Check your connection.";
          _loading = false;
        });
      }
    }
  }

  List<AdminComplaint> get _filtered {
    if (_activeFilter == "All") return _all;
    final target = _activeFilter == "In Progress"
        ? ComplaintStatus.inProgress
        : ComplaintStatusX.fromValue(_activeFilter.toLowerCase());
    return _all.where((c) => c.status == target).toList();
  }

  Future<void> _openDetail(AdminComplaint c) async {
    final updated = await Navigator.push<AdminComplaint>(
      context,
      MaterialPageRoute(builder: (_) => _AdminComplaintDetailScreen(complaint: c)),
    );
    if (updated != null) {
      setState(() {
        final idx = _all.indexWhere((x) => x.id == updated.id);
        if (idx != -1) _all[idx] = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(isDark),
        _filterTabs(isDark),
        Expanded(child: _body(isDark)),
      ]),
    );
  }

  /* ================= HEADER ================= */

  Widget _header(bool isDark) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 14,
          left: 8, right: 20, bottom: 22,
        ),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
        ),
        child: Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Complaints",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  _loading ? "Loading..." : "${_all.length} total complaints",
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadComplaints,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          ),
        ]),
      );

  /* ================= FILTER TABS ================= */

  Widget _filterTabs(bool isDark) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          itemCount: _kFilterTabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final tab = _kFilterTabs[i];
            final active = _activeFilter == tab;
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.gradient : null,
                  color: active
                      ? null
                      : (isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active
                          ? Colors.transparent
                          : (isDark ? Colors.white12 : AppColors.border)),
                ),
                child: Text(tab,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87))),
              ),
            );
          },
        ),
      );

  /* ================= BODY ================= */

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorState(isDark);
    final list = _filtered;
    if (list.isEmpty) return _emptyState(isDark);

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        itemCount: list.length,
        itemBuilder: (_, i) => _complaintCard(list[i], isDark),
      ),
    );
  }

  Widget _errorState(bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded,
                size: 52, color: isDark ? Colors.white24 : AppColors.muted),
            const SizedBox(height: 14),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                onPressed: _loadComplaints,
                child: const Text("Retry"),
              ),
            ),
          ]),
        ),
      );

  Widget _emptyState(bool isDark) => LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.glowShadow,
                    ),
                    child: const Icon(Icons.report_gmailerrorred_rounded,
                        color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _activeFilter == "All"
                        ? "No complaints yet"
                        : "No ${_activeFilter.toLowerCase()} complaints",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Complaints raised by care-seekers will show up here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  /* ================= CARD ================= */

  Widget _complaintCard(AdminComplaint c, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
          boxShadow: isDark ? [] : AppColors.cardShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetail(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    c.userName.isNotEmpty ? c.userName[0].toUpperCase() : "?",
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 1),
                      Text(c.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                _statusChip(c.status),
              ]),
              const SizedBox(height: 10),
              Text(
                c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 13, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(_formatDate(c.createdAt),
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
                if (c.images.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.image_rounded, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text("${c.images.length}",
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ]),
            ]),
          ),
        ),
      );

  Widget _statusChip(ComplaintStatus status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: status.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: status.color)),
        ]),
      );

  static String _formatDate(DateTime d) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? "PM" : "AM";
    return "${d.day} ${months[d.month - 1]} ${d.year}  •  $h:${d.minute.toString().padLeft(2, '0')} $ampm";
  }
}

/// ── Detail + resolve screen ─────────────────────────────────────────────
class _AdminComplaintDetailScreen extends StatefulWidget {
  final AdminComplaint complaint;
  const _AdminComplaintDetailScreen({required this.complaint});

  @override
  State<_AdminComplaintDetailScreen> createState() => _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState extends State<_AdminComplaintDetailScreen> {
  late ComplaintStatus _selectedStatus;
  late TextEditingController _responseController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.complaint.status;
    _responseController = TextEditingController(text: widget.complaint.adminResponse ?? "");
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _saveUpdate() async {
    setState(() => _saving = true);
    try {
      final res = await http
          .put(
            Uri.parse(Api.updateComplaintStatus(widget.complaint.id)),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "status": _selectedStatus.value,
              "admin_response": _responseController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["success"] == true && data["complaint"] != null) {
          final updated = AdminComplaint.fromJson(
            Map<String, dynamic>.from(data["complaint"]),
          );
          // Preserve user info fields since the update endpoint may not join them
          final merged = AdminComplaint(
            id: updated.id,
            userId: widget.complaint.userId,
            userName: widget.complaint.userName,
            userEmail: widget.complaint.userEmail,
            category: updated.category,
            description: updated.description,
            images: updated.images.isNotEmpty ? updated.images : widget.complaint.images,
            createdAt: updated.createdAt,
            status: updated.status,
            adminResponse: updated.adminResponse,
            resolvedAt: updated.resolvedAt,
          );
          Navigator.pop(context, merged);
          return;
        }
      }
      _snack("Failed to update complaint. Please try again.");
    } catch (e) {
      debugPrint("ADMIN UPDATE COMPLAINT ERROR: $e");
      _snack("Something went wrong. Check your connection.");
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _viewImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.complaint;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 8, right: 20, bottom: 22,
          ),
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
          ),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(c.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
            children: [
              // ── Reporter info ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Text(
                      c.userName.isNotEmpty ? c.userName[0].toUpperCase() : "?",
                      style: TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.userName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87)),
                        if (c.userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(c.userEmail,
                              style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Description ──
              _sectionTitle("Description", isDark),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                ),
                child: Text(c.description,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.black87)),
              ),

              // ── Images ──
              if (c.images.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle("Attached Photos", isDark),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: c.images.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _viewImage(c.images[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        c.images[i],
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(
                                child: SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))),
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.border,
                          child: const Icon(Icons.broken_image_rounded,
                              color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _sectionTitle("Update Status", isDark),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                ),
                child: DropdownButtonFormField<ComplaintStatus>(
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  ),
                  dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  items: ComplaintStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Row(children: [
                              Icon(s.icon, size: 16, color: s.color),
                              const SizedBox(width: 8),
                              Text(s.label,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87)),
                            ]),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                ),
              ),

              const SizedBox(height: 20),
              _sectionTitle("Response to Care-seeker", isDark),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                ),
                child: TextField(
                  controller: _responseController,
                  maxLines: 5,
                  maxLength: 800,
                  enabled: !_saving,
                  style: TextStyle(
                      fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Write a response explaining the resolution or next steps...",
                    hintMaxLines: 3,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppColors.glowShadow,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : _saveUpdate,
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save Update",
                            style: TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String text, bool isDark) => Text(text,
      style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
          color: isDark ? Colors.white : Colors.black87));
}