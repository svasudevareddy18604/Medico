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
      showAppToast(
        context: context,
        message:
            "No ${widget.service["category"]} professionals are available near you yet.",
        type: AppToastType.unavailable,
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
        showAppToast(
          context: context,
          message: "Added to cart successfully!",
          type: AppToastType.success,
          actionLabel: "View Cart",
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CartScreen(userId: widget.userId)),
          ).then((_) => loadCartCount()),
        );
      } else {
        showAppToast(
          context: context,
          message: "Failed to add. Please try again.",
          type: AppToastType.error,
        );
      }
    } catch (_) {
      showAppToast(
        context: context,
        message: "Network error. Check your connection.",
        type: AppToastType.error,
      );
    }
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
            backgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
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
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.border,
              foregroundColor: AppColors.muted,
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
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.warning.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_search_rounded,
                        color: AppColors.warning, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "No $category professionals available",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  "We currently don't have any $category caregivers available "
                  "in your area. Other service categories may still be available.",
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.warning.withOpacity(0.85),
                      height: 1.55),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.notifications_active_rounded,
                      color: AppColors.warning, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "You'll be notified as soon as one becomes available!",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
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
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_sectionIcon(title),
                color: AppColors.primary, size: 15),
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
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87)),
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
        // ── HEADER ──────────────────────────────────────────────────────
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
                        builder: (_) =>
                            CartScreen(userId: widget.userId)),
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
                    backgroundColor: AppColors.danger,
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

        // ── BODY ────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                child: Icon(
                                    Icons.medical_services_rounded,
                                    color: AppColors.primary,
                                    size: 48)))
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

                  // ── NAME ──────────────────────────────────────────────
                  Text(s["name"] ?? "",
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E))),
                  const SizedBox(height: 10),

                  // ── PRICE + CATEGORY ──────────────────────────────────
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
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
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.secondary.withOpacity(0.25)),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.category_rounded,
                                    color: AppColors.secondary, size: 13),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width -
                                            200,
                                  ),
                                  child: Text(
                                    category,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondary),
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

                  // Add to cart button
                  _addToCartButton(),
                  const SizedBox(height: 30),

                  // Recommended
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
//  PROFESSIONAL TOAST SYSTEM
//  Uses AppColors throughout — change AppColors, toasts update.
// ══════════════════════════════════════════════════════════════

enum AppToastType { success, error, warning, info, unavailable }

/// Call this from anywhere you have a [BuildContext].
void showAppToast({
  required BuildContext context,
  required String message,
  AppToastType type = AppToastType.success,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppToastWidget(
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onDismiss: () {
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
}

// ── Toast style descriptor ────────────────────────────────────────────────
class _ToastStyle {
  final Color surfaceColor;   // card background
  final Color borderColor;    // left accent bar + border
  final Color iconBgColor;    // icon pill background
  final Color iconColor;      // icon color
  final Color titleColor;     // title text
  final Color messageColor;   // body text
  final Color actionBgColor;  // action button bg
  final Color actionFgColor;  // action button text
  final IconData icon;
  final String label;

  const _ToastStyle({
    required this.surfaceColor,
    required this.borderColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.titleColor,
    required this.messageColor,
    required this.actionBgColor,
    required this.actionFgColor,
    required this.icon,
    required this.label,
  });
}

_ToastStyle _resolveStyle(AppToastType type) {
  switch (type) {
    case AppToastType.success:
      return _ToastStyle(
        surfaceColor: const Color(0xFFF0FDF6),
        borderColor: AppColors.success,
        iconBgColor: AppColors.success.withOpacity(0.25),
        iconColor: Color(0xFF14823A),
        titleColor: Color(0xFF0D6030),
        messageColor: Color(0xFF1A5C35),
        actionBgColor: AppColors.success.withOpacity(0.3),
        actionFgColor: Color(0xFF0D5C2E),
        icon: Icons.check_circle_rounded,
        label: "Success",
      );

    case AppToastType.error:
      return _ToastStyle(
        surfaceColor: const Color(0xFFFFF5F5),
        borderColor: AppColors.danger,
        iconBgColor: AppColors.danger.withOpacity(0.12),
        iconColor: AppColors.danger,
        titleColor: Color(0xFFB91C1C),
        messageColor: Color(0xFFC53030),
        actionBgColor: AppColors.danger.withOpacity(0.1),
        actionFgColor: Color(0xFFB91C1C),
        icon: Icons.cancel_rounded,
        label: "Error",
      );

    case AppToastType.warning:
      return _ToastStyle(
        surfaceColor: const Color(0xFFFFFBEB),
        borderColor: AppColors.warning,
        iconBgColor: AppColors.warning.withOpacity(0.15),
        iconColor: AppColors.warning,
        titleColor: Color(0xFFB45309),
        messageColor: Color(0xFFC0611A),
        actionBgColor: AppColors.warning.withOpacity(0.15),
        actionFgColor: Color(0xFFB45309),
        icon: Icons.warning_amber_rounded,
        label: "Warning",
      );

    case AppToastType.info:
      return _ToastStyle(
        surfaceColor: const Color(0xFFEFF6FF),
        borderColor: AppColors.info,
        iconBgColor: AppColors.info.withOpacity(0.12),
        iconColor: AppColors.info,
        titleColor: Color(0xFF1D4ED8),
        messageColor: Color(0xFF2563EB),
        actionBgColor: AppColors.info.withOpacity(0.1),
        actionFgColor: Color(0xFF1D4ED8),
        icon: Icons.info_rounded,
        label: "Info",
      );

    case AppToastType.unavailable:
      return _ToastStyle(
        surfaceColor: const Color(0xFFF8F7FF),
        borderColor: AppColors.primary,
        iconBgColor: AppColors.primary.withOpacity(0.1),
        iconColor: AppColors.primary,
        titleColor: AppColors.primary,
        messageColor: AppColors.dark.withOpacity(0.7),
        actionBgColor: AppColors.primary.withOpacity(0.1),
        actionFgColor: AppColors.primary,
        icon: Icons.person_off_rounded,
        label: "Not Available",
      );
  }
}

// ── Toast widget ──────────────────────────────────────────────────────────
class _AppToastWidget extends StatefulWidget {
  final String message;
  final AppToastType type;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  const _AppToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

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

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(widget.type);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
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
                decoration: BoxDecoration(
                  color: style.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: style.borderColor.withOpacity(0.35),
                      width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: style.borderColor.withOpacity(0.12),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left accent bar ────────────────────────────
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: style.borderColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),

                      // ── Content ────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon pill
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: style.iconBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(style.icon,
                                    color: style.iconColor, size: 20),
                              ),
                              const SizedBox(width: 12),

                              // Text + action
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      style.label,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: style.titleColor,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: style.messageColor,
                                        height: 1.45,
                                      ),
                                    ),
                                    if (widget.actionLabel != null) ...[
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () {
                                          _dismiss();
                                          widget.onAction?.call();
                                        },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6),
                                          decoration: BoxDecoration(
                                            color: style.actionBgColor,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: style.borderColor
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            widget.actionLabel!,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: style.actionFgColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Close button
                              GestureDetector(
                                onTap: _dismiss,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4),
                                  child: Icon(Icons.close_rounded,
                                      color: style.titleColor
                                          .withOpacity(0.4),
                                      size: 17),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}