import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';

import '../../config/api.dart';
import 'cart_screen.dart';
import 'service_detail_screen.dart';

class ServiceScreen extends StatefulWidget {
  final String category;
  final int userId;

  const ServiceScreen({super.key, required this.category, required this.userId});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  List<dynamic> services = [];
  bool loading = true;
  int cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadServices(), _loadCartCount()]);
  }

  Future<void> _loadServices() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/services"));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List data = decoded["services"];
        setState(() {
          services = data
              .where((s) =>
                  s["category"] == widget.category && s["active"] == true)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Load Services Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final res =
          await http.get(Uri.parse("${Api.baseUrl}/cart/${widget.userId}"));
      if (res.statusCode == 200) {
        final List cart = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            cartCount = cart.fold(
                0,
                (sum, item) =>
                    sum + ((item["quantity"] as num?)?.toInt() ?? 1));
          });
        }
      }
    } catch (e) {
      debugPrint("Cart Count Error: $e");
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CartScreen(userId: widget.userId)),
    ).then((_) => _loadCartCount());
  }

  String _imageUrl(String? image) {
    if (image == null || image.trim().isEmpty) return "";
    return image.startsWith("http") ? image : "${Api.imageBase}/$image";
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 16),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 22),
            ),
            Expanded(
              child: Text(
                widget.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _openCart,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_rounded,
                        color: Colors.white, size: 30),
                    if (cartCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cartCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SERVICE CARD ─────────────────────────────────────────────────
  Widget _buildServiceCard(BuildContext context, dynamic service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = _imageUrl(service["image"]);
    final price = service["price"] ?? 0;
    final name = service["name"] ?? "Service";
    final desc = service["description"] ?? "";

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ServiceDetailScreen(service: service, userId: widget.userId),
        ),
      ).then((_) => _loadCartCount()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Service Image ──
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 86,
                        height: 86,
                        color: isDark
                            ? const Color(0xFF2A2A3E)
                            : const Color(0xFFF0F4F8),
                        child: Icon(Icons.medical_services_rounded,
                            color: AppColors.primary, size: 36),
                      )
                    : Image.network(
                        imageUrl,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 86,
                          height: 86,
                          color: isDark
                              ? const Color(0xFF2A2A3E)
                              : const Color(0xFFF0F4F8),
                          child: Icon(Icons.medical_services_rounded,
                              color: AppColors.primary, size: 36),
                        ),
                      ),
              ),

              const SizedBox(width: 14),

              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Text(
                          "₹$price",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // View Details Button
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "View Details",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 12, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── EMPTY STATE ──────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined,
              size: 80,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No services available",
            style: TextStyle(
                fontSize: 17,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            "Check back later for ${widget.category} services",
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : services.isEmpty
                    ? _buildEmpty(context)
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadAll,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          itemCount: services.length,
                          itemBuilder: (ctx, i) =>
                              _buildServiceCard(ctx, services[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}