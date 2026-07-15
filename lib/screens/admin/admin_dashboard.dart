import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import 'package:medico/config/api.dart';

import 'admin_services.dart';
import 'admin_users.dart';
import 'admin_orders.dart';
import 'admin_caregivers.dart';
import 'admin_timeslot_screen.dart';
import 'admin_withdraw_screen.dart';
import 'careseekercomplaints_screen.dart';
import 'careseekerinvoice_screen.dart';

class AdminDashboard extends StatefulWidget {
  final int userId;

  const AdminDashboard({super.key, required this.userId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _today = {};
  Map<String, dynamic> _yesterday = {};
  Map<String, dynamic> _allTime = {};
  List<dynamic> _todayOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(Api.adminDashboardSummary))
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        setState(() {
          _today = Map<String, dynamic>.from(body['today'] ?? {});
          _yesterday = Map<String, dynamic>.from(body['yesterday'] ?? {});
          _allTime = Map<String, dynamic>.from(body['allTime'] ?? {});
          _todayOrders = List<dynamic>.from(body['todayOrders'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = body['message'] ?? "Couldn't load dashboard data";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Network error — pull down to retry";
        _loading = false;
      });
    }
  }

  /* ================= HEADER ================= */

  Widget _appHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getGreeting(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    "Admin Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _fetchSummary,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _heroStatsRow(),
        ],
      ),
    );
  }

  /* ================= HERO STATS (in header, on gradient) ================= */

  Widget _heroStatsRow() {
    final todayRevenue = _num(_today['today_revenue']);
    final yesterdayRevenue = _num(_yesterday['revenue']);
    final trendUp = todayRevenue >= yesterdayRevenue;
    final trendPct = yesterdayRevenue > 0
        ? (((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100).abs()
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "TODAY'S EARNINGS",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                _loading
                    ? _shimmerLine(width: 120, height: 26)
                    : Text(
                        "₹${todayRevenue.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                if (!_loading && yesterdayRevenue > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        trendUp
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: trendUp ? Colors.greenAccent : Colors.orangeAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "${trendPct.toStringAsFixed(0)}% vs yesterday",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: trendUp ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: Colors.white.withOpacity(0.25),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "TODAY'S BOOKINGS",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                _loading
                    ? _shimmerLine(width: 60, height: 26)
                    : Text(
                        "${_today['today_bookings'] ?? 0}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                if (!_loading) ...[
                  const SizedBox(height: 6),
                  Text(
                    "${_today['completed_count'] ?? 0} completed · ${_today['cancelled_count'] ?? 0} cancelled",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  /* ================= SECONDARY STAT CARDS ================= */

  Widget _statCardsRow() {
    final cards = [
      _StatCardData(
        label: "Confirmed",
        value: "${_today['confirmed_count'] ?? 0}",
        icon: Icons.event_available_rounded,
        color: const Color(0xFF2979FF),
      ),
      _StatCardData(
        label: "Collected (Paid)",
        value: "₹${_num(_today['today_collected']).toStringAsFixed(0)}",
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF00B894),
      ),
      _StatCardData(
        label: "COD Pending",
        value: "${_today['cod_count'] ?? 0}",
        icon: Icons.money_rounded,
        color: const Color(0xFFFF8C00),
      ),
      _StatCardData(
        label: "All-Time Revenue",
        value: "₹${_num(_allTime['total_revenue']).toStringAsFixed(0)}",
        icon: Icons.insights_rounded,
        color: const Color(0xFF7C4DFF),
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _statCard(cards[i]),
      ),
    );
  }

  Widget _statCard(_StatCardData data) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          _loading
              ? _shimmerLine(width: 50, height: 16)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[850] ?? Colors.grey[900],
                    ),
                  ),
                ),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /* ================= TODAY'S BOOKINGS LIST ================= */

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF00B894);
      case 'CANCELLED':
        return const Color(0xFFE53935);
      case 'CONFIRMED':
      default:
        return const Color(0xFF2979FF);
    }
  }

  Widget _todayBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Today's Bookings",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[850] ?? Colors.grey[900],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminOrders())),
              child: const Text("View all"),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          )
        else if (_loading)
          Column(
            children: List.generate(
              3,
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
        else if (_todayOrders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text("No bookings yet today",
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _bookingTile(_todayOrders[i]),
          ),
      ],
    );
  }

  Widget _bookingTile(dynamic order) {
    final status = (order['status'] ?? '').toString();
    final color = _statusColor(status);
    final serviceName = (order['service_names'] ?? order['category'] ?? 'Service').toString();
    final total = _num(order['total']);
    final orderCode = (order['order_code'] ?? '').toString();
    final paymentMethod = (order['payment_method'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              paymentMethod == 'COD'
                  ? Icons.payments_rounded
                  : Icons.qr_code_scanner_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  orderCode,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${total.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ================= MENU GRID ================= */

  Widget _menuGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [
        DashboardCard(
          title: "Services",
          icon: Icons.medical_services_rounded,
          color: AppColors.primary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminServices())),
        ),
        DashboardCard(
          title: "CareSeekers",
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF2979FF),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminUsers())),
        ),
        DashboardCard(
          title: "Bookings",
          icon: Icons.assignment_rounded,
          color: const Color(0xFFFF8C00),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminOrders())),
        ),
        DashboardCard(
          title: "Caregivers",
          icon: Icons.health_and_safety_rounded,
          color: const Color(0xFFE53935),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminCaregivers())),
        ),
        DashboardCard(
          title: "Time Slots",
          icon: Icons.access_time_rounded,
          color: const Color(0xFF7C4DFF),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminTimeSlotScreen())),
        ),
        DashboardCard(
          title: "Withdraw\nRequests",
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.secondary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminWithdrawScreen())),
        ),
        DashboardCard(
          title: "Complaints",
          icon: Icons.report_problem_rounded,
          color: const Color(0xFFD84315),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminComplaintsScreen())),
        ),
        DashboardCard(
          title: "Invoices",
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFFD84315),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminInvoicesScreen()),
          ),
        ),
      ],
    );
  }

  /* ================= BODY ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _appHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchSummary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statCardsRow(),
                    const SizedBox(height: 24),
                    _todayBookingsSection(),
                    const SizedBox(height: 26),
                    Text(
                      "Manage",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[850] ?? Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _menuGrid(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

/* ================= CARD ================= */

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}