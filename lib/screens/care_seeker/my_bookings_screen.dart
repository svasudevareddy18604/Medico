import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';
import 'order_details_screen.dart';

/// Shows only the care-seeker's COMPLETED bookings.
/// Tapping a booking opens [OrderDetailsScreen] for that order.
///
/// NOTE: This assumes `OrderDetailsScreen` has a constructor of the shape
/// `OrderDetailsScreen({required int orderId})`. If yours takes a different
/// parameter name (e.g. `orderId` vs `id`), just adjust the _go() call below.
class MyBookingsScreen extends StatefulWidget {
  final int userId;
  const MyBookingsScreen({super.key, required this.userId});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _completedOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse("${Api.orders}/${widget.userId}"),
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final completed = data
            .map((e) => Map<String, dynamic>.from(e))
            .where((o) =>
                (o["status"] ?? "").toString().toUpperCase() == "COMPLETED")
            .toList();

        // Most recent completed booking first.
        completed.sort((a, b) {
          final aId = int.tryParse(a["id"].toString()) ?? 0;
          final bId = int.tryParse(b["id"].toString()) ?? 0;
          return bId.compareTo(aId);
        });

        if (mounted) {
          setState(() {
            _completedOrders = completed;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Failed to load bookings.";
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("MY BOOKINGS ERROR: $e");
      if (mounted) {
        setState(() {
          _error = "Something went wrong. Check your connection.";
          _loading = false;
        });
      }
    }
  }

  void _openOrderDetails(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orders: [order]),
      ),
    );
  }
  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(dynamic raw) {
    if (raw == null) return "";
    try {
      final d = DateTime.parse(raw.toString());
      const months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}";
    } catch (_) {
      return raw.toString();
    }
  }

  String _fmtAmount(dynamic raw) {
    final val = double.tryParse(raw?.toString() ?? "") ?? 0;
    return "₹${val.toStringAsFixed(0)}";
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(
        children: [
          _header(context),
          Expanded(child: _body(isDark)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 18,
          left: 12,
          right: 20,
          bottom: 26,
        ),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 4),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "My Bookings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _body(bool isDark) {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState(isDark);
    if (_completedOrders.isEmpty) return _emptyState(isDark);

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _fetchBookings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: _completedOrders.length,
        itemBuilder: (_, i) => _bookingCard(_completedOrders[i], isDark),
      ),
    );
  }

  Widget _loadingState() => const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );

  Widget _errorState(bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 52, color: isDark ? Colors.white24 : AppColors.muted),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                  ),
                  onPressed: _fetchBookings,
                  child: const Text("Retry"),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _emptyState(bool isDark) => LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.glowShadow,
                      ),
                      child: const Icon(Icons.event_available_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "No completed bookings yet",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Your completed service bookings will\nshow up here.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  // ── Booking card ──────────────────────────────────────────────────────────

  Widget _bookingCard(Map<String, dynamic> order, bool isDark) {
    final orderCode = (order["order_code"] ?? "—").toString();
    final serviceNames =
        (order["service_names"] ?? order["category"] ?? "Service").toString();
    final date = _fmtDate(order["date"]);
    final slot = (order["slot"] ?? "").toString();
    final total = _fmtAmount(order["total"]);
    final feedbackGiven = order["feedback_given"] == 1 ||
        order["feedback_given"] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: AppColors.glowShadow,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          orderCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusPill("COMPLETED"),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: isDark ? Colors.white12 : AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(Icons.calendar_today_rounded, date, isDark),
                  const SizedBox(width: 10),
                  _infoChip(Icons.access_time_rounded, slot, isDark),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.currency_rupee_rounded,
                      size: 15,
                      color: isDark ? Colors.white54 : AppColors.muted),
                  const SizedBox(width: 2),
                  Text(
                    total.replaceAll("₹", ""),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (!feedbackGiven)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            "Rate service",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? Colors.white38 : AppColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );

  Widget _infoChip(IconData icon, String label, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: isDark ? Colors.white54 : AppColors.muted),
            const SizedBox(width: 5),
            Text(
              label.isEmpty ? "—" : label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      );
}