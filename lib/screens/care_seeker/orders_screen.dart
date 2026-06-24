import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int userId;
  const OrdersScreen({super.key, required this.userId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  List   _orders  = [];
  bool   _loading = true;
  String _error   = "";
  String _filter  = "All";
  bool   _liveBlip = false;
  Timer? _timer;

  late AnimationController _anim;
  late Animation<double>   _fade;

  bool get _dark => themeNotifier.value == ThemeMode.dark;

  // ── Deep green for COMPLETED ───────────────────────────────────────────
  static const Color _completedGreen = Color(0xFF16A34A);

  // ── Status config ─────────────────────────────────────────────────────

  static const _filters = [
    "All",
    "CONFIRMED",
    "ACCEPTED",
    "IN_PROGRESS",
    "ON_THE_WAY",
    "COMPLETED",
    "CANCELLED",
  ];

  static String _label(String s) => switch (s.toUpperCase()) {
    "CONFIRMED"   => "Pending",
    "ACCEPTED"    => "Assigned",
    "IN_PROGRESS" => "In Progress",
    "ON_THE_WAY"  => "On The Way",
    "COMPLETED"   => "Completed",
    "CANCELLED"   => "Cancelled",
    _             => s,
  };

  static Color _statusColor(String s) => switch (s.toUpperCase()) {
    "COMPLETED"   => _completedGreen,   // ← was AppColors.success (too light)
    "ACCEPTED"    => AppColors.primary,
    "IN_PROGRESS" => AppColors.secondary,
    "ON_THE_WAY"  => AppColors.accent,
    "CONFIRMED"   => AppColors.warning,
    "CANCELLED"   => AppColors.danger,
    _             => AppColors.muted,
  };

  static IconData _statusIcon(String s) => switch (s.toUpperCase()) {
    "COMPLETED"   => Icons.check_circle_rounded,
    "ACCEPTED"    => Icons.assignment_turned_in_rounded,
    "IN_PROGRESS" => Icons.handyman_rounded,
    "ON_THE_WAY"  => Icons.directions_bike_rounded,
    "CONFIRMED"   => Icons.hourglass_top_rounded,
    "CANCELLED"   => Icons.cancel_rounded,
    _             => Icons.help_outline_rounded,
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    themeNotifier.addListener(_rebuild);
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_rebuild);
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _startTimer() {
    _timer?.cancel();
    final hasActive = _orders.any((o) => !["COMPLETED", "CANCELLED"]
        .contains((o["status"] ?? "").toString().toUpperCase()));
    _timer = Timer.periodic(
        Duration(seconds: hasActive ? 12 : 30), (_) => _load(silent: true));
  }

  // ── Data ──────────────────────────────────────────────────────────────

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() { _loading = true; _error = ""; });
    }
    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/orders/${widget.userId}"))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final all = jsonDecode(res.body) as List;
        if (mounted) {
          final changed = _didChange(all);
          setState(() {
            _orders   = all;
            _loading  = false;
            _liveBlip = !_liveBlip;
          });
          if (!silent || changed) _anim.forward(from: 0);
          _startTimer();
        }
      } else {
        if (!silent && mounted) {
          setState(() { _error = "Failed to load orders"; _loading = false; });
        }
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() { _error = "Connection error"; _loading = false; });
      }
    }
  }

  bool _didChange(List fresh) {
    if (fresh.length != _orders.length) return true;
    for (int i = 0; i < fresh.length; i++) {
      if ((fresh[i]["status"] ?? "") != (_orders[i]["status"] ?? "")) return true;
    }
    return false;
  }

  List get _filtered {
    final list = [..._orders];
    list.sort((a, b) {
      const done = ["COMPLETED", "CANCELLED"];
      final aC = done.contains((a["status"] ?? "").toUpperCase()) ? 1 : 0;
      final bC = done.contains((b["status"] ?? "").toUpperCase()) ? 1 : 0;
      if (aC != bC) return aC.compareTo(bC);
      try {
        return DateTime.parse(b["date"].toString())
            .compareTo(DateTime.parse(a["date"].toString()));
      } catch (_) { return 0; }
    });
    if (_filter == "All") return list;
    return list
        .where((o) =>
            (o["status"] ?? "").toString().toUpperCase() == _filter)
        .toList();
  }

  String _fmtDate(String? d) {
    if (d == null) return "";
    try {
      final dt = DateTime.parse(d).toLocal();
      const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day.toString().padLeft(2, '0')} "
             "${mo[dt.month - 1]} ${dt.year}";
    } catch (_) { return d; }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF0F172A) : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _header(),
          _filterBar(),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5,
                    ),
                  )
                : _error.isNotEmpty
                    ? _errorState()
                    : _filtered.isEmpty
                        ? _emptyState()
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: FadeTransition(
                              opacity: _fade,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                    top: 4, bottom: 28),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => _card(_filtered[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _header() => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 12,
      bottom: 24,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "My Bookings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_liveBlip ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record,
                  color: Colors.greenAccent, size: 8),
              SizedBox(width: 5),
              Text(
                "Live",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 22),
          onPressed: _load,
          tooltip: "Refresh",
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );

  // ── Filter Bar ────────────────────────────────────────────────────────

  Widget _filterBar() => SizedBox(
    height: 52,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: _filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f      = _filters[i];
        final active = _filter == f;
        final color  = f == "All" ? null : _statusColor(f);

        return GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: active ? AppColors.gradient : null,
              color: active
                  ? null
                  : (_dark
                      ? const Color(0xFF1E293B)
                      : AppColors.cardBg),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? Colors.transparent
                    : (color ?? AppColors.primary).withOpacity(0.25),
                width: 1.2,
              ),
            ),
            child: Text(
              f == "All" ? "All" : _label(f),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.white
                    : (_dark ? Colors.white60 : Colors.black54),
              ),
            ),
          ),
        );
      },
    ),
  );

  // ── Order Card ────────────────────────────────────────────────────────

  Widget _card(Map order) {
    final status    = (order["status"] ?? "").toString();
    final statusUp  = status.toUpperCase();
    final color     = _statusColor(status);
    final icon      = _statusIcon(status);
    final code      = (order["order_code"] ?? "").toString();
    final svc       = (order["service_names"] ??
                       order["service_name"]  ??
                       order["category"]      ??
                       "Service").toString();
    final category  = (order["category"] ?? "").toString();
    final date      = _fmtDate(order["date"]?.toString());
    final slot      = (order["slot"] ?? "-").toString();
    final total     = order["total"] ?? 0;
    final svcCharge = num.tryParse(
        order["service_charge"]?.toString() ?? "0") ?? 0;
    final payment   = (order["payment_method"] ?? "COD").toString();
    final cancelled = statusUp == "CANCELLED";
    final hasCharge = svcCharge > 0;

    final cardBg = _dark ? const Color(0xFF1E293B) : AppColors.cardBg;

    return Opacity(
      opacity: cancelled ? 0.65 : 1.0,
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(orders: [order]),
            ),
          );
          _load(silent: true);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_dark ? 0.18 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Top accent stripe ──────────────────────────────────
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Order code + Status chip ───────────────────
                      Row(children: [
                        const Icon(Icons.tag_rounded,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            code,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.primary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        _statusChip(_label(status), color, icon),
                      ]),

                      const SizedBox(height: 10),

                      // ── Service name + Total ───────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              svc,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _dark ? Colors.white : AppColors.dark,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: AppColors.gradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppColors.glowShadow,
                                ),
                                child: Text(
                                  "₹$total",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (hasCharge) ...[
                                const SizedBox(height: 3),
                                Text(
                                  "incl. ₹$svcCharge charge",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ── Category badge ────────────────────────────
                      if (category.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      // ── Date + Slot ───────────────────────────────
                      _infoRow(Icons.calendar_today_rounded, date),
                      const SizedBox(height: 5),
                      _infoRow(Icons.access_time_rounded, slot),

                      const SizedBox(height: 12),

                      Divider(
                        height: 1,
                        thickness: 0.8,
                        color: _dark ? Colors.white10 : AppColors.border,
                      ),

                      const SizedBox(height: 10),

                      // ── Payment + View Details ────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.payment_rounded,
                                size: 14,
                                color: _dark
                                    ? Colors.white38
                                    : AppColors.muted),
                            const SizedBox(width: 5),
                            Text(
                              payment,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _dark
                                    ? Colors.white54
                                    : AppColors.muted,
                              ),
                            ),
                          ]),
                          const Row(children: [
                            Icon(Icons.touch_app_rounded,
                                size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              "View Details",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 15, color: AppColors.primary),
    const SizedBox(width: 7),
    Expanded(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: _dark ? Colors.white60 : Colors.black87,
        ),
      ),
    ),
  ]);

  Widget _statusChip(String text, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );

  // ── Empty State ───────────────────────────────────────────────────────

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.softGradient,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.15),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 46,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            "No Bookings Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _dark ? Colors.white : AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == "All"
                ? "Book a service to get started."
                : "No ${_label(_filter)} bookings.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: _dark ? Colors.white38 : AppColors.muted,
            ),
          ),
          const SizedBox(height: 28),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: AppColors.glowShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text("Browse Services"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Error State ───────────────────────────────────────────────────────

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withOpacity(0.08),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.danger.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _dark ? Colors.white54 : AppColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.glowShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}