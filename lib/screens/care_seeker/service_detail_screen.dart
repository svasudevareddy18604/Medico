import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'cart_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> service;
  final int userId;
  const ServiceDetailScreen(
      {super.key, required this.service, required this.userId});
  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  List<dynamic> recommended = [];
  int cartCount = 0;
  bool isLoadingRecommended = true;
  bool isCheckingAvailability = true;
  bool isCategoryAvailable = false;

  @override
  void initState() {
    super.initState();
    loadRecommended();
    loadCartCount();
    checkCategoryAvailability();
  }

  String getImageUrl(String? img) {
    if (img == null || img.isEmpty) return '';
    return img.startsWith("http") ? img : "${Api.imageBase}/$img";
  }

  // ── AVAILABILITY ──────────────────────────────────────────────────────────
  Future<void> checkCategoryAvailability() async {
    setState(() => isCheckingAvailability = true);
    try {
      final url = Api.caretakerAvailability(
          widget.userId, widget.service["category"] ?? "");
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => isCategoryAvailable = data["available"] == true);
      } else {
        setState(() => isCategoryAvailable = false);
      }
    } catch (e) {
      debugPrint("Availability check error: $e");
      setState(() => isCategoryAvailable = false);
    }
    if (mounted) setState(() => isCheckingAvailability = false);
  }

  // ── RECOMMENDED ───────────────────────────────────────────────────────────
  Future<void> loadRecommended() async {
    setState(() => isLoadingRecommended = true);
    try {
      final res =
          await http.get(Uri.parse("${Api.baseUrl}/services/recommended"));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)["services"] ?? [];
        setState(() => recommended = data
            .where((s) => s["id"] != widget.service["id"])
            .take(6)
            .toList());
      }
    } catch (e) {
      debugPrint("Recommended error: $e");
    }
    if (mounted) setState(() => isLoadingRecommended = false);
  }

  // ── CART COUNT ────────────────────────────────────────────────────────────
  Future<void> loadCartCount() async {
    try {
      final res =
          await http.get(Uri.parse("${Api.baseUrl}/cart/${widget.userId}"));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() => cartCount =
            data.fold(0, (sum, i) => sum + ((i["quantity"] ?? 1) as int)));
      }
    } catch (_) {}
  }

  // ── ADD TO CART ───────────────────────────────────────────────────────────
  Future<void> addToCart() async {
    if (!isCategoryAvailable) {
      showToast(
        "No ${widget.service["category"]} professionals are available near you yet.",
        type: _ToastType.unavailable,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/cart/add"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "service_id": widget.service["id"],
          "quantity": 1,
          "category": widget.service["category"],
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        loadCartCount();
        showToast(
          "Added to cart successfully!",
          type: _ToastType.success,
          actionLabel: "View Cart",
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CartScreen(userId: widget.userId)),
          ).then((_) => loadCartCount()),
        );
      } else {
        showToast("Failed to add. Please try again.", type: _ToastType.error);
      }
    } catch (_) {
      showToast("Network error. Check your connection.",
          type: _ToastType.error);
    }
  }

  // ── TOAST ─────────────────────────────────────────────────────────────────
  void showToast(
    String msg, {
    _ToastType type = _ToastType.success,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _ToastWidget(
              message: msg,
              type: type,
              actionLabel: actionLabel,
              onAction: onAction,
              duration: duration,
              onDismiss: () {
                try {
                  entry.remove();
                } catch (_) {}
              },
            ));
    overlay.insert(entry);
  }

  // ── ADD TO CART BUTTON ────────────────────────────────────────────────────

  Widget _addToCartButton() {
    // State 1: still checking
    if (isCheckingAvailability) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        ),
      );
    }

    // State 2: no caretaker available
    if (!isCategoryAvailable) {
      final category = widget.service["category"] ?? "this service";
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: const Text("Add to Cart",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD166), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_rounded,
                    color: Color(0xFFB7600A), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "No $category professionals available",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A4100),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              "We currently don't have any $category caregivers available "
              "in your area. Other service categories may still be available.",
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF7A4100), height: 1.55),
            ),
            const SizedBox(height: 10),
            Row(children: const [
              Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFB7600A), size: 15),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "You'll be notified as soon as one becomes available!",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A4100),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]);
    }

    // State 3: available
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: addToCart,
        icon: const Icon(Icons.add_shopping_cart_rounded,
            color: Colors.white, size: 20),
        label: const Text("Add to Cart",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
    );
  }

  // ── SECTION CARD ──────────────────────────────────────────────────────────
  Widget _sectionCard(String title, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(_sectionIcon(title), color: AppColors.primary, size: 15),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: isDark ? Colors.grey[300] : Colors.black87)),
      ]),
    );
  }

  IconData _sectionIcon(String title) {
    switch (title.toLowerCase()) {
      case "description":
        return Icons.info_outline_rounded;
      case "includes":
        return Icons.check_circle_outline_rounded;
      case "excludes":
        return Icons.cancel_outlined;
      case "requirements":
        return Icons.assignment_outlined;
      case "duration":
        return Icons.access_time_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  // ── RECOMMENDED CARD ──────────────────────────────────────────────────────
  Widget _recommendedCard(dynamic r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final img = getImageUrl(r["image"]);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ServiceDetailScreen(service: r, userId: widget.userId),
        ),
      ),
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: img.isEmpty
                    ? Container(
                        height: 105,
                        color: isDark
                            ? const Color(0xFF2A2A3E)
                            : Colors.grey[200],
                        child: Center(
                            child: Icon(Icons.medical_services_rounded,
                                color: AppColors.primary, size: 34)))
                    : Image.network(img,
                        height: 105,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            height: 105,
                            color: isDark
                                ? const Color(0xFF2A2A3E)
                                : Colors.grey[200],
                            child: Center(
                                child: Icon(Icons.medical_services_rounded,
                                    color: AppColors.primary, size: 34)))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r["name"] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 6),
                      Text("₹${r["price"] ?? 0}",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ]),
              ),
            ]),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.service;
    final imageUrl = getImageUrl(s["image"]);
    final priceType = s["price_type"] == "per_hour" ? " / hour" : "";
    final category = (s["category"] ?? "").toString().trim();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F7),
      body: Column(children: [

        // ── HEADER ────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 16, 16, 20),
          decoration: const BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(s["name"] ?? "Service",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CartScreen(userId: widget.userId)),
                  );
                  loadCartCount();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white, size: 22),
                ),
              ),
              if (cartCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.red,
                    child: Text("$cartCount",
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
          ]),
        ),

        // ── BODY ──────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Service image
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: imageUrl.isEmpty
                    ? Container(
                        height: 220,
                        color: isDark
                            ? const Color(0xFF2A2A3E)
                            : Colors.grey[200],
                        child: Center(
                            child: Icon(Icons.medical_services_rounded,
                                color: AppColors.primary, size: 48)))
                    : Image.network(imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            height: 220,
                            color: isDark
                                ? const Color(0xFF2A2A3E)
                                : Colors.grey[200])),
              ),
              const SizedBox(height: 18),

              // ── NAME ────────────────────────────────────────────────────
              Text(s["name"] ?? "",
                  style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E))),
              const SizedBox(height: 10),

              // ── PRICE + CATEGORY — FIX: Wrap in a Wrap widget so chips
              //    never overflow horizontally regardless of text length ──
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  // Price chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      "₹${s["price"] ?? 0}$priceType",
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),

                  // Category chip — only if non-empty
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.indigo.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.category_rounded,
                            color: Colors.indigo, size: 13),
                        const SizedBox(width: 5),
                        // FIX: constrain text so it wraps cleanly
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width - 200,
                          ),
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Info sections
              _sectionCard("Description", s["description"]),
              _sectionCard("Includes", s["includes"]),
              _sectionCard("Excludes", s["excludes"]),
              _sectionCard("Requirements", s["requirements"]),
              _sectionCard("Duration", s["duration"]),
              const SizedBox(height: 8),

              // Add to cart button (3 states)
              _addToCartButton(),
              const SizedBox(height: 30),

              // Recommended services
              if (isLoadingRecommended)
                const Center(child: CircularProgressIndicator())
              else if (recommended.isNotEmpty) ...[
                Text("Recommended Services",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E))),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recommended
                        .map((r) => _recommendedCard(r))
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TOAST SYSTEM
// ══════════════════════════════════════════════════════════════

enum _ToastType { success, error, warning, info, unavailable }

class _ToastWidget extends StatefulWidget {
  final String message;
  final _ToastType type;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ({Color bg, Color accent, IconData icon, String label}) get _style =>
      switch (widget.type) {
        _ToastType.success => (
            bg: const Color(0xFF1B7A4A),
            accent: const Color(0xFF34C97B),
            icon: Icons.check_circle_rounded,
            label: "Success"
          ),
        _ToastType.error => (
            bg: const Color(0xFFC0392B),
            accent: const Color(0xFFFF6B6B),
            icon: Icons.cancel_rounded,
            label: "Error"
          ),
        _ToastType.warning => (
            bg: const Color(0xFFB7600A),
            accent: const Color(0xFFFFB347),
            icon: Icons.warning_amber_rounded,
            label: "Warning"
          ),
        _ToastType.info => (
            bg: const Color(0xFF1A6FA8),
            accent: const Color(0xFF4FC3F7),
            icon: Icons.info_rounded,
            label: "Info"
          ),
        _ToastType.unavailable => (
            bg: const Color(0xFF5C4A8A),
            accent: const Color(0xFFB39DDB),
            icon: Icons.person_off_rounded,
            label: "Not Available"
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: s.bg.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon circle
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle),
                      child: Icon(s.icon, color: s.accent, size: 22),
                    ),
                    const SizedBox(width: 12),

                    // Text + action
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  letterSpacing: 0.3)),
                          const SizedBox(height: 3),
                          Text(widget.message,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                  height: 1.45)),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                _dismiss();
                                widget.onAction?.call();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color:
                                        Colors.white.withOpacity(0.2),
                                    borderRadius:
                                        BorderRadius.circular(8)),
                                child: Text(widget.actionLabel!,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Close
                    GestureDetector(
                      onTap: _dismiss,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(left: 6, top: 2),
                        child: Icon(Icons.close_rounded,
                            color: Colors.white.withOpacity(0.6),
                            size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}