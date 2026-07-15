import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

/// ── Cloudinary config ──────────────────────────────────────────────────
class CloudinaryConfig {
  static const String cloudName = "YOUR_CLOUD_NAME";
  static const String uploadPreset = "YOUR_UPLOAD_PRESET";

  static String get uploadUrl =>
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
}

/// ── Status ──────────────────────────────────────────────────────────────
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

  /// Value sent to / received from the backend (matches the SQL ENUM).
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

const List<String> kComplaintCategories = [
  "Caretaker Behavior",
  "Service Quality",
  "Payment / Billing Issue",
  "Late Arrival / No-show",
  "Safety Concern",
  "App / Technical Issue",
  "Other",
];

/// ── Model ───────────────────────────────────────────────────────────────
class Complaint {
  final int id;
  final String category;
  final String description;
  final List<String> images; // full URLs (Cloudinary secure_url values)
  final DateTime createdAt;
  final ComplaintStatus status;
  final String? adminResponse;
  final DateTime? resolvedAt;

  Complaint({
    required this.id,
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

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: int.tryParse(json["id"].toString()) ?? 0,
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

/// ── Screen ──────────────────────────────────────────────────────────────
class MyComplaintsScreen extends StatefulWidget {
  final int userId;
  const MyComplaintsScreen({super.key, required this.userId});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  bool _loading = true;
  String? _error;
  List<Complaint> _complaints = [];

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
          .get(Uri.parse(Api.getUserComplaints(widget.userId)))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> raw = data["complaints"] ?? [];
        final list = raw
            .map((e) => Complaint.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) {
          setState(() {
            _complaints = list;
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
      debugPrint("FETCH COMPLAINTS ERROR: $e");
      if (mounted) {
        setState(() {
          _error = "Something went wrong. Check your connection.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _openNewComplaintForm() async {
    final created = await Navigator.push<Complaint>(
      context,
      MaterialPageRoute(builder: (_) => _NewComplaintScreen(userId: widget.userId)),
    );
    if (created != null) {
      setState(() => _complaints.insert(0, created));
    }
  }

  void _openDetail(Complaint c) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ComplaintDetailScreen(complaint: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(isDark),
        Expanded(child: _body(isDark)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewComplaintForm,
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Complaint",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _errorState(isDark);
    if (_complaints.isEmpty) return _emptyState(isDark);

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: _complaints.length,
        itemBuilder: (_, i) => _complaintCard(_complaints[i], isDark),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _header(bool isDark) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 14,
          left: 8, right: 20, bottom: 26,
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
                const Text("My Complaints",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  _loading ? "Loading..." : "${_complaints.length} raised so far",
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ]),
      );

  // ── Error state ───────────────────────────────────────────────────────
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

  // ── Empty state ───────────────────────────────────────────────────────
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
                  Text("No complaints yet",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 6),
                  Text(
                    "If something went wrong with a booking or a caretaker,\nlet us know and we'll sort it out.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  // ── Complaint card ────────────────────────────────────────────────────
  Widget _complaintCard(Complaint c, bool isDark) => Container(
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
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.report_problem_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(_formatDate(c.createdAt),
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
              if (c.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.image_rounded, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                      "${c.images.length} photo${c.images.length > 1 ? 's' : ''} attached",
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ]),
              ],
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

/// ── New complaint form ──────────────────────────────────────────────────
class _NewComplaintScreen extends StatefulWidget {
  final int userId;
  const _NewComplaintScreen({required this.userId});

  @override
  State<_NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<_NewComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _selectedCategory;
  final List<XFile> _images = [];
  bool _submitting = false;
  String _submitLabel = "Submit Complaint";

  static const int _maxImages = 5;

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You can attach up to $_maxImages photos.")),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      setState(() {
        final remaining = _maxImages - _images.length;
        _images.addAll(picked.take(remaining));
      });
    } catch (e) {
      debugPrint("IMAGE PICK ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the gallery. Please try again.")),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You can attach up to $_maxImages photos.")),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (shot == null) return;
      setState(() => _images.add(shot));
    } catch (e) {
      debugPrint("CAMERA ERROR: $e");
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text("Choose from gallery"),
            onTap: () { Navigator.pop(context); _pickImages(); },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text("Take a photo"),
            onTap: () { Navigator.pop(context); _takePhoto(); },
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  /// Uploads a single picked image directly to Cloudinary (unsigned preset)
  /// and returns the secure_url, or null on failure.
  Future<String?> _uploadToCloudinary(XFile file) async {
    try {
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest("POST", uri)
        ..fields["upload_preset"] = CloudinaryConfig.uploadPreset
        ..files.add(await http.MultipartFile.fromPath("file", file.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data["secure_url"]?.toString();
      }
      debugPrint("CLOUDINARY UPLOAD FAILED (${res.statusCode}): ${res.body}");
      return null;
    } catch (e) {
      debugPrint("CLOUDINARY UPLOAD ERROR: $e");
      return null;
    }
  }

  /// Uploads all picked images to Cloudinary in parallel, returns the
  /// list of secure_urls. Returns null if any upload fails.
  Future<List<String>?> _uploadAllImages() async {
    if (_images.isEmpty) return [];
    final results = await Future.wait(_images.map(_uploadToCloudinary));
    if (results.any((url) => url == null)) return null;
    return results.cast<String>();
  }

  Future<void> _submit() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;
  if (_selectedCategory == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select a category.")),
    );
    return;
  }

  setState(() => _submitting = true);

  try {
    final uri = Uri.parse(Api.submitComplaint);
    final request = http.MultipartRequest("POST", uri)
      ..fields["user_id"] = widget.userId.toString()
      ..fields["category"] = _selectedCategory!
      ..fields["description"] = _descController.text.trim();

    for (final img in _images) {
  final mimeType = lookupMimeType(img.path) ?? 'image/jpeg';
  final parts = mimeType.split('/');
  request.files.add(
    await http.MultipartFile.fromPath(
      "images",
      img.path,
      contentType: MediaType(parts[0], parts[1]),
    ),
  );
}

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);

    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      if (data["success"] == true && data["complaint"] != null) {
        final complaint = Complaint.fromJson(Map<String, dynamic>.from(data["complaint"]));
        Navigator.pop(context, complaint);
        return;
      }
      _snack(data["message"] ?? "Failed to submit complaint.");
    } else {
      String message = "Failed to submit complaint. Please try again.";
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded["message"] != null) {
          message = decoded["message"].toString();
        }
      } catch (_) {}
      _snack(message);
    }
  } catch (e) {
    debugPrint("SUBMIT COMPLAINT ERROR: $e");
    if (mounted) _snack("Something went wrong. Check your connection.");
  }

  if (mounted) setState(() => _submitting = false);
}

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            const Text("Raise a Complaint",
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
              children: [
                _fieldLabel("Category", isDark),
                const SizedBox(height: 8),
                _categoryPicker(isDark),
                const SizedBox(height: 20),
                _fieldLabel("Describe what happened", isDark),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                  ),
                  child: TextFormField(
                    controller: _descController,
                    maxLines: 6,
                    maxLength: 800,
                    enabled: !_submitting,
                    style: TextStyle(
                        fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                    decoration: const InputDecoration(
                      hintText: "Be as specific as you can — what happened, when, "
                          "and who was involved. This helps our team resolve it faster.Please Share Booking ID, If Possible",
                      hintMaxLines: 4,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Please describe the issue";
                      if (v.trim().length < 15) return "Please add a bit more detail";
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _fieldLabel("Upload Image (optional)", isDark),
                const SizedBox(height: 4),
                Text("Photos of receipts, chats, or the issue itself help admins verify faster.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(height: 10),
                _imagePickerRow(isDark),
                const SizedBox(height: 30),
                _submitButton(),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text, bool isDark) => Text(text,
      style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
          color: isDark ? Colors.white : Colors.black87));

  Widget _categoryPicker(bool isDark) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        ),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          ),
          hint: const Text("Select a category", style: TextStyle(fontSize: 13.5)),
          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
          dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          items: kComplaintCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: _submitting ? null : (val) => setState(() => _selectedCategory = val),
        ),
      );

  Widget _imagePickerRow(bool isDark) => SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ..._images.asMap().entries.map((entry) {
              final i = entry.key;
              final file = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(file.path),
                      width: 84, height: 84, fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6, right: -6,
                    child: GestureDetector(
                      onTap: _submitting ? null : () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ]),
              );
            }),
            if (_images.length < _maxImages)
              GestureDetector(
                onTap: _submitting ? null : _showImageSourceSheet,
                child: Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark ? Colors.white24 : AppColors.border),
                    color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
                  ),
                  child: Icon(Icons.add_a_photo_rounded, color: AppColors.muted, size: 24),
                ),
              ),
          ],
        ),
      );

  Widget _submitButton() => SizedBox(
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
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(_submitLabel,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  )
                : const Text("Submit Complaint",
                    style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      );
}

/// ── Detail screen ────────────────────────────────────────────────────────
class _ComplaintDetailScreen extends StatelessWidget {
  final Complaint complaint;
  const _ComplaintDetailScreen({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = complaint;

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
              _statusTimeline(c, isDark),
              const SizedBox(height: 22),
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
                  itemBuilder: (_, i) => ClipRRect(
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
              ],
              if (c.adminResponse != null && c.adminResponse!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle("Response from Medico Support team", isDark),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ComplaintStatus.resolved.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: ComplaintStatus.resolved.color.withOpacity(0.25)),
                  ),
                  child: Text(c.adminResponse!,
                      style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: isDark ? Colors.white70 : Colors.black87)),
                ),
              ],
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

  Widget _statusTimeline(Complaint c, bool isDark) {
    final steps = [
      ComplaintStatus.pending,
      ComplaintStatus.inProgress,
      c.status == ComplaintStatus.rejected
          ? ComplaintStatus.rejected
          : ComplaintStatus.resolved,
    ];
    final currentIndex = steps.indexOf(c.status) == -1
        ? (c.status == ComplaintStatus.rejected ? 2 : 0)
        : steps.indexOf(c.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final passed = (i ~/ 2) < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: passed ? AppColors.secondary : AppColors.border,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final step = steps[stepIndex];
          final active = stepIndex <= currentIndex;
          return Column(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? step.color : AppColors.border,
              ),
              child: Icon(step.icon,
                  size: 15, color: active ? Colors.white : AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(step.label,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? (isDark ? Colors.white : Colors.black87)
                        : AppColors.muted)),
          ]);
        }),
      ),
    );
  }
}