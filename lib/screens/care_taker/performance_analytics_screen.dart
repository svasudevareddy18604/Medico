import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';

class PerformanceAnalyticsScreen extends StatefulWidget {
  final int userId;
  const PerformanceAnalyticsScreen({super.key, required this.userId});

  @override
  State<PerformanceAnalyticsScreen> createState() =>
      _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState
    extends State<PerformanceAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map _data = {};

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fetch();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(Api.caretakerPerformance(widget.userId)))
          .timeout(const Duration(seconds: 12));
      final d = jsonDecode(res.body);
      if (d["success"] == true) {
        setState(() {
          _data = d["data"] ?? {};
          _loading = false;
        });
        _animController.forward(from: 0);
      } else {
        setState(() {
          _error = d["message"]?.toString() ?? "Failed to load analytics";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  int _i(dynamic v) => (v ?? 0) is int ? v : int.tryParse(v.toString()) ?? 0;
  double _d(dynamic v) =>
      (v ?? 0) is double ? v : double.tryParse(v.toString()) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      body: Column(children: [
        _header(),
        Expanded(
          child: _loading
              ? _loadingState()
              : _error != null
                  ? _errorState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetch,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ratingHero(),
                                const SizedBox(height: 18),
                                _statsGrid(),
                                const SizedBox(height: 24),
                                _sectionTitle("Earnings Overview", Icons.account_balance_wallet_rounded),
                                const SizedBox(height: 12),
                                _earningsCard(),
                                const SizedBox(height: 24),
                                _sectionTitle("Monthly Performance", Icons.show_chart_rounded),
                                const SizedBox(height: 12),
                                _monthlyChart(),
                                const SizedBox(height: 24),
                                _sectionTitle("Rating Breakdown", Icons.star_rounded),
                                const SizedBox(height: 12),
                                _ratingBreakdown(),
                                const SizedBox(height: 24),
                                if ((_data["category_breakdown"] as List?)
                                        ?.isNotEmpty ==
                                    true) ...[
                                  _sectionTitle("Services Completed", Icons.category_rounded),
                                  const SizedBox(height: 12),
                                  _categoryBreakdown(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _header() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B8FAC), Color(0xFF14B8A6), Color(0xFF0EAE8E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0B8FAC).withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 10))
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 22),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 17),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Performance Analytics",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _fetch,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 19),
                ),
              ),
            ]),
          ),
        ),
      );

  // ── Loading state ───────────────────────────────────────────
  Widget _loadingState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3.4,
              ),
            ),
            const SizedBox(height: 14),
            Text("Loading analytics...",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );

  // ── Error state ──────────────────────────────────────────────
  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 36, color: Colors.red.shade300),
            ),
            const SizedBox(height: 16),
            Text(_error ?? "Something went wrong",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              label: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
          ]),
        ),
      );

  // ── Rating hero ──────────────────────────────────────────────
  Widget _ratingHero() {
    final rating = _d(_data["avg_rating"]);
    final reviews = _i(_data["total_reviews"]);
    final completion = _d(_data["completion_rate"]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8FAC), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0B8FAC).withOpacity(0.32),
              blurRadius: 22,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFD54F), size: 26),
              ]),
              const SizedBox(height: 4),
              Text("$reviews review${reviews == 1 ? '' : 's'}",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.88), fontSize: 12.5)),
            ],
          ),
        ),
        Container(width: 1, height: 54, color: Colors.white.withOpacity(0.25)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${completion.toStringAsFixed(0)}%",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Completion Rate",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.88), fontSize: 12.5)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Stats grid ───────────────────────────────────────────────
  Widget _statsGrid() {
    final items = [
      (
        "Total Jobs",
        _i(_data["total_jobs"]).toString(),
        Icons.work_history_rounded,
        AppColors.primary
      ),
      (
        "Completed",
        _i(_data["completed_jobs"]).toString(),
        Icons.check_circle_rounded,
        const Color(0xFF00875A)
      ),
      (
        "Active",
        _i(_data["active_jobs"]).toString(),
        Icons.directions_run_rounded,
        const Color(0xFF1565C0)
      ),
      (
        "Cancelled",
        _i(_data["cancelled_jobs"]).toString(),
        Icons.cancel_rounded,
        const Color(0xFFD32F2F)
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55, // was 1.7 — more vertical room fixes overflow
      children: items
          .map((it) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: (it.$4 as Color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(it.$3 as IconData,
                          color: it.$4 as Color, size: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(it.$2 as String,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold)),
                    Text(it.$1 as String,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Section title ────────────────────────────────────────────
  Widget _sectionTitle(String label, IconData icon) => Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 9),
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]);

  // ── Earnings card ────────────────────────────────────────────
  Widget _earningsCard() {
    final total = _d(_data["total_earnings"]);
    final pending = _d(_data["pending_earnings"]);
    final paid = _d(_data["paid_earnings"]);
    final thisMonth = _d(_data["this_month_earnings"]);
    final thisMonthJobs = _i(_data["this_month_jobs"]);

    Widget row(String label, String value, Color color, {bool last = false}) =>
        Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 9),
                  Text(label,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ]),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: color)),
              ],
            ),
          ),
          if (!last) Divider(height: 1, color: Colors.grey.shade100),
        ]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("₹${total.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text("Total Earnings",
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "₹${thisMonth.toStringAsFixed(0)} this month · $thisMonthJobs job${thisMonthJobs == 1 ? '' : 's'}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.grey.shade100),
        row("Paid Out", "₹${paid.toStringAsFixed(0)}", const Color(0xFF00875A)),
        row("Pending", "₹${pending.toStringAsFixed(0)}", const Color(0xFFE65100),
            last: true),
      ]),
    );
  }

  // ── Monthly bar chart (custom, no external package) ─────────
  Widget _monthlyChart() {
    final trend = (_data["monthly_trend"] as List?) ?? [];
    if (trend.isEmpty) {
      return _emptyCard("No completed jobs in the last 6 months yet");
    }

    final maxJobs = trend
        .map((m) => _i(m["jobs"]))
        .fold<int>(1, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: trend.map((m) {
          final jobs = _i(m["jobs"]);
          final earnings = _d(m["earnings"]);
          final heightFrac = jobs / maxJobs;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("₹${earnings.toStringAsFixed(0)}",
                  style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: heightFrac.clamp(0.08, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Container(
                  width: 26,
                  height: 92 * value,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.5)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(m["month"]?.toString() ?? "",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              Text("$jobs job${jobs == 1 ? '' : 's'}",
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Rating breakdown bars ────────────────────────────────────
  Widget _ratingBreakdown() {
    final breakdown = (_data["rating_breakdown"] as Map?) ?? {};
    final total = _i(_data["total_reviews"]);

    if (total == 0) {
      return _emptyCard("No reviews yet");
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [5, 4, 3, 2, 1].map((star) {
          final count = _i(breakdown[star.toString()] ?? breakdown[star] ?? 0);
          final frac = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                width: 32,
                child: Row(children: [
                  Text("$star", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFD54F), size: 13),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 9,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFFD54F)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 26,
                child: Text("$count",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Category breakdown ───────────────────────────────────────
  Widget _categoryBreakdown() {
    final cats = (_data["category_breakdown"] as List?) ?? [];
    final maxCount = cats
        .map((c) => _i(c["count"]))
        .fold<int>(1, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: cats.map((c) {
          final name = c["category"]?.toString() ?? "Unknown";
          final count = _i(c["count"]);
          final frac = count / maxCount;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                    Text("$count",
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, size: 30, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(msg,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5)),
            ],
          ),
        ),
      );
}