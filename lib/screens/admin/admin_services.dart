import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api.dart';
import 'package:medico/utils/app_colors.dart';

// ══════════════════════════════════════════════════════════════
//  TOAST
// ══════════════════════════════════════════════════════════════

enum ToastType { success, error, warning, info }

class AppToast {
  static void show(BuildContext ctx, String msg,
      {ToastType type = ToastType.success,
      Duration duration = const Duration(seconds: 3)}) {
    final overlay = Overlay.of(ctx);
    late OverlayEntry e;
    e = OverlayEntry(
        builder: (_) => _Toast(
            msg: msg,
            type: type,
            duration: duration,
            onDone: () {
              try {
                e.remove();
              } catch (_) {}
            }));
    overlay.insert(e);
  }
}

class _Toast extends StatefulWidget {
  final String msg;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDone;
  const _Toast(
      {required this.msg,
      required this.type,
      required this.duration,
      required this.onDone});
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final Animation<double> _f =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _s =
      Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(_f);

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(widget.duration, _go);
  }

  void _go() async {
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({Color bg, Color acc, IconData icon, String label}) get _s2 =>
      switch (widget.type) {
        ToastType.success => (
            bg: const Color(0xFF1B7A4A),
            acc: const Color(0xFF34C97B),
            icon: Icons.check_circle_rounded,
            label: "Success"
          ),
        ToastType.error => (
            bg: const Color(0xFFC0392B),
            acc: const Color(0xFFFF6B6B),
            icon: Icons.cancel_rounded,
            label: "Error"
          ),
        ToastType.warning => (
            bg: const Color(0xFFB7600A),
            acc: const Color(0xFFFFB347),
            icon: Icons.warning_amber_rounded,
            label: "Warning"
          ),
        ToastType.info => (
            bg: const Color(0xFF1A6FA8),
            acc: const Color(0xFF4FC3F7),
            icon: Icons.info_rounded,
            label: "Info"
          ),
      };

  @override
  Widget build(BuildContext context) {
    final t = _s2;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _s,
        child: FadeTransition(
          opacity: _f,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _go,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: t.bg.withOpacity(0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 7))
                    ]),
                child: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle),
                      child: Icon(t.icon, color: t.acc, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(t.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text(widget.msg,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.88),
                                fontSize: 12.5,
                                height: 1.4)),
                      ])),
                  GestureDetector(
                      onTap: _go,
                      child: Icon(Icons.close_rounded,
                          color: Colors.white.withOpacity(0.6), size: 18)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ADMIN SERVICES SCREEN
// ══════════════════════════════════════════════════════════════

class AdminServices extends StatefulWidget {
  const AdminServices({super.key});
  @override
  State<AdminServices> createState() => _AdminServicesState();
}

class _AdminServicesState extends State<AdminServices> {
  List services = [];
  bool loading = true;
  String? selectedCategory;
  final categories = ["Nurse", "Physiotherapy", "Non-Medical Support"];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(Api.adminServices));
      if (res.statusCode == 200) {
        setState(() => services = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Load error: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  List get _filtered => selectedCategory == null
      ? []
      : services.where((e) => e["category"] == selectedCategory).toList();

  Future<void> _toggle(int id) async {
    try {
      final res =
          await http.put(Uri.parse("${Api.adminServices}/toggle/$id"));
      if (res.statusCode == 200) {
        AppToast.show(context, "Service status updated.", type: ToastType.info);
        _load();
      }
    } catch (_) {
      AppToast.show(context, "Toggle failed.", type: ToastType.error);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text("Delete Service",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: const Text("This action cannot be undone."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.white))),
              ],
            ));
    if (ok != true) return;
    try {
      final res =
          await http.delete(Uri.parse("${Api.adminServices}/$id"));
      if (res.statusCode == 200) {
        AppToast.show(context, "Deleted.", type: ToastType.success);
        _load();
      } else {
        AppToast.show(context, "Delete failed.", type: ToastType.error);
      }
    } catch (_) {
      AppToast.show(context, "Network error.", type: ToastType.error);
    }
  }

  void _openForm([Map? s]) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddServiceScreen(
              service: s,
              onSaved: (msg) {
                _load();
                AppToast.show(context, msg, type: ToastType.success);
              })));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(children: [
        _header(),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : selectedCategory == null
                    ? _categoryGrid()
                    : _serviceList()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Add Service",
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openForm(),
      ),
    );
  }

  Widget _header() {
    final total = _filtered.length;
    final active = _filtered
        .where((s) => s["active"] == 1 || s["active"] == true)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 52, 16, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(children: [
        if (selectedCategory != null)
          IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => setState(() => selectedCategory = null))
        else
          const SizedBox(width: 16),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(selectedCategory ?? "Services",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text(
                  selectedCategory == null
                      ? "Manage all service categories"
                      : "$total service${total == 1 ? '' : 's'}  •  $active active",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 13)),
            ])),
      ]),
    );
  }

  Widget _categoryGrid() {
    final icons = [
      Icons.local_hospital_rounded,
      Icons.accessibility_new_rounded,
      Icons.support_agent_rounded
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final all =
            services.where((s) => s["category"] == categories[i]).length;
        final active = services
            .where((s) =>
                s["category"] == categories[i] &&
                (s["active"] == 1 || s["active"] == true))
            .length;
        return GestureDetector(
          onTap: () => setState(() => selectedCategory = categories[i]),
          child: Container(
            decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ]),
            padding: const EdgeInsets.all(16),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12)),
                      child:
                          Icon(icons[i], color: Colors.white, size: 22)),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(categories[i],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text("$active/$all active",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12)),
                      ]),
                ]),
          ),
        );
      },
    );
  }

  Widget _serviceList() {
    if (_filtered.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.medical_services_outlined,
            size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text("No services yet",
            style: TextStyle(color: Colors.grey[500], fontSize: 15)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _ServiceCard(
        service: _filtered[i],
        onToggle: () => _toggle(_filtered[i]["id"]),
        onEdit: () => _openForm(_filtered[i]),
        onDelete: () => _delete(_filtered[i]["id"]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SERVICE CARD
// ══════════════════════════════════════════════════════════════

class _ServiceCard extends StatelessWidget {
  final Map service;
  final VoidCallback onToggle, onEdit, onDelete;
  const _ServiceCard(
      {required this.service,
      required this.onToggle,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = service;
    final isActive = s["active"] == 1 || s["active"] == true;
    final requiresDocs =
        s["requires_documents"] == 1 || s["requires_documents"] == true;
    final img = (s["image"] ?? "").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isActive
            ? null
            : Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isActive ? 0.06 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        if (img.isNotEmpty)
          Stack(children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.network(img,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
            if (!isActive)
              Positioned.fill(
                  child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: const Center(
                    child: Text("INACTIVE",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5))),
              )),
          ]),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (img.isEmpty)
              Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.medical_services_rounded,
                      color: isActive ? AppColors.primary : Colors.grey,
                      size: 26)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(s["name"] ?? "",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isActive
                                    ? Colors.black87
                                    : Colors.grey[600]))),
                    // Active/Inactive toggle badge
                    GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isActive
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              isActive
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_rounded,
                              size: 14,
                              color: isActive
                                  ? Colors.green[700]
                                  : Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(isActive ? "Active" : "Inactive",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.green[700]
                                      : Colors.orange[700])),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text("₹${s["price"]}  •  ${s["price_type"]}",
                      style: TextStyle(
                          color: isActive ? AppColors.primary : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  if ((s["duration"] ?? "").toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text("⏱ ${s["duration"]}",
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                  if ((s["description"] ?? "").toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(s["description"],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                Colors.grey[isActive ? 700 : 500],
                            fontSize: 12,
                            height: 1.4)),
                  ],
                  // ── Badges row ──
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (s["recommended"] == true || s["recommended"] == 1)
                      _badge(Icons.star_rounded, "Recommended",
                          Colors.amber, Colors.amber.withOpacity(0.15)),
                    // ✅ NEW: requires_documents badge
                    if (requiresDocs)
                      _badge(Icons.folder_copy_rounded, "Docs Required",
                          Colors.indigo, Colors.indigo.withOpacity(0.10)),
                  ]),
                ])),
            // Edit / Delete actions
            Column(mainAxisSize: MainAxisSize.min, children: [
              _iconBtn(Icons.edit_rounded, Colors.blue, onEdit),
              const SizedBox(height: 4),
              _iconBtn(Icons.delete_rounded, Colors.red, onDelete),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _badge(IconData icon, String label, Color color, Color bg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      Material(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: color, size: 20))));
}

// ══════════════════════════════════════════════════════════════
//  ADD / EDIT SERVICE SCREEN
// ══════════════════════════════════════════════════════════════

class AddServiceScreen extends StatefulWidget {
  final Map? service;
  final void Function(String) onSaved;
  const AddServiceScreen(
      {super.key, this.service, required this.onSaved});
  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _name         = TextEditingController();
  final _price        = TextEditingController();
  final _desc         = TextEditingController();
  final _duration     = TextEditingController();
  final _includes     = TextEditingController();
  final _excludes     = TextEditingController();
  final _requirements = TextEditingController();

  String _category = "Nurse",
      _type = "Home Visit",
      _priceType = "per_service";
  bool _recommended = false;
  bool _requiresDocuments = false; // ✅ NEW
  bool _saving = false;
  File? _image;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    if (s != null) {
      _name.text         = s["name"] ?? "";
      _price.text        = s["price"]?.toString() ?? "";
      _desc.text         = s["description"] ?? "";
      _duration.text     = s["duration"] ?? "";
      _includes.text     = s["includes"] ?? "";
      _excludes.text     = s["excludes"] ?? "";
      _requirements.text = s["requirements"] ?? "";
      _category          = s["category"] ?? "Nurse";
      _type              = s["service_type"] ?? "Home Visit";
      _priceType         = s["price_type"] ?? "per_service";
      _recommended       = s["recommended"] == true || s["recommended"] == 1;
      // ✅ Load requires_documents from existing service
      _requiresDocuments =
          s["requires_documents"] == true || s["requires_documents"] == 1;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _price, _desc, _duration, _includes, _excludes, _requirements
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final p = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (p != null) setState(() => _image = File(p.path));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) {
      AppToast.show(context, "Name and Price are required.",
          type: ToastType.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      final isEdit = widget.service != null;
      final req = http.MultipartRequest(
          isEdit ? "PUT" : "POST",
          Uri.parse(isEdit
              ? "${Api.adminServices}/${widget.service!["id"]}"
              : Api.adminServices));
      req.fields.addAll({
        "name":               _name.text.trim(),
        "category":           _category,
        "service_type":       _type,
        "price":              _price.text.trim(),
        "price_type":         _priceType,
        "description":        _desc.text.trim(),
        "duration":           _duration.text.trim(),
        "includes":           _includes.text.trim(),
        "excludes":           _excludes.text.trim(),
        "requirements":       _requirements.text.trim(),
        "recommended":        _recommended ? "1" : "0",
        "requires_documents": _requiresDocuments ? "1" : "0", // ✅ NEW
      });
      if (_image != null) {
        req.files.add(
            await http.MultipartFile.fromPath("image", _image!.path));
      }
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) {
        widget.onSaved(isEdit ? "Service updated!" : "Service added!");
        if (mounted) Navigator.pop(context);
      } else {
        AppToast.show(context, "Save failed (${res.statusCode}).",
            type: ToastType.error);
      }
    } catch (_) {
      AppToast.show(context, "Network error.", type: ToastType.error);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.service != null;
    final oldImg = widget.service?["image"]?.toString() ?? "";
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(children: [
        // ── Header ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 52, 16, 28),
          decoration: const BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32))),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(isEdit ? "Edit Service" : "Add Service",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text(
                      isEdit
                          ? "Update service details"
                          : "Fill in details below",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13)),
                ])),
          ]),
        ),

        Expanded(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
              // ── Image Picker ──
              Center(
                  child: GestureDetector(
                onTap: _pick,
                child: Stack(children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 2),
                        color: AppColors.primary.withOpacity(0.05)),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _image != null
                            ? Image.file(_image!, fit: BoxFit.cover)
                            : (oldImg.isNotEmpty
                                ? Image.network(oldImg,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgHolder())
                                : _imgHolder())),
                  ),
                  Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14))),
                ]),
              )),
              const SizedBox(height: 24),

              // ── Basic Info ──
              _sec("Basic Info"),
              _f(_name, "Service Name", Icons.medical_services_outlined),
              _f(_price, "Price (₹)", Icons.currency_rupee, num: true),
              _f(_duration, "Duration", Icons.timer_outlined),
              _f(_desc, "Description", Icons.description_outlined, lines: 3),

              // ── Details ──
              _sec("Details"),
              _f(_includes, "What's Included", Icons.check_circle_outline),
              _f(_excludes, "What's Excluded", Icons.cancel_outlined),
              _f(_requirements, "Requirements", Icons.info_outline, lines: 2),

              // ── Configuration ──
              _sec("Configuration"),
              _dd("Category", _category,
                  ["Nurse", "Physiotherapy", "Non-Medical Support"],
                  (v) => setState(() => _category = v),
                  Icons.category_outlined),
              _dd("Service Type", _type, ["Home Visit", "Clinic Visit"],
                  (v) => setState(() => _type = v),
                  Icons.home_repair_service_outlined),
              _dd("Price Type", _priceType, ["per_service", "per_hour"],
                  (v) => setState(() => _priceType = v),
                  Icons.payments_outlined),
              const SizedBox(height: 4),

              // ── Recommended Toggle ──
              _switchTile(
                value: _recommended,
                onChanged: (v) => setState(() => _recommended = v),
                title: "Mark as Recommended",
                subtitle: "Shows in recommended section",
                icon: Icons.star_rounded,
                iconColor: AppColors.primary,
              ),
              const SizedBox(height: 10),

              // ✅ NEW: Requires Documents Toggle
              _switchTile(
                value: _requiresDocuments,
                onChanged: (v) => setState(() => _requiresDocuments = v),
                title: "Requires Documents",
                subtitle:
                    "Patient must upload documents to book this service",
                icon: Icons.folder_copy_rounded,
                iconColor: Colors.indigo,
              ),

              const SizedBox(height: 28),

              // ── Save Button ──
              SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor:
                            AppColors.primary.withOpacity(0.4)),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  isEdit
                                      ? Icons.save_rounded
                                      : Icons.add_circle_outline,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                  isEdit
                                      ? "Update Service"
                                      : "Add Service",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ]),
                  )),
            ])),
      ]),
    );
  }

  // ── Reusable switch tile ──
  Widget _switchTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 8)
            ]),
        child: SwitchListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          value: value,
          activeColor: iconColor,
          onChanged: onChanged,
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20)),
        ),
      );

  Widget _imgHolder() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: AppColors.primary.withOpacity(0.5), size: 32),
        const SizedBox(height: 4),
        Text("Tap to upload",
            style: TextStyle(
                color: AppColors.primary.withOpacity(0.5), fontSize: 11)),
      ]);

  Widget _sec(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(t,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5)));

  Widget _f(TextEditingController c, String label, IconData icon,
          {bool num = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: c,
              keyboardType:
                  num ? TextInputType.number : TextInputType.multiline,
              maxLines: lines,
              decoration: InputDecoration(
                  labelText: label,
                  prefixIcon:
                      Icon(icon, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5)),
                  labelStyle: TextStyle(
                      color: Colors.grey[600], fontSize: 14))));

  Widget _dd(String label, String value, List<String> items,
          ValueChanged<String> onChange, IconData icon) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                  labelText: label,
                  prefixIcon:
                      Icon(icon, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5)),
                  labelStyle: TextStyle(
                      color: Colors.grey[600], fontSize: 14)),
              items: items
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChange(v);
              }));
}