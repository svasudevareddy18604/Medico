import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';

class RatingsReviewsScreen extends StatefulWidget {
  final int userId;
  const RatingsReviewsScreen({super.key, required this.userId});

  @override
  State<RatingsReviewsScreen> createState() => _RatingsReviewsScreenState();
}

class _RatingsReviewsScreenState extends State<RatingsReviewsScreen> {
  bool _loading = true;
  double _avgRating = 0.0;
  int _totalReviews = 0;
  int _totalJobs = 0;
  List<int> _starCounts = [0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─── LOAD ────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse(Api.getCaregiverFeedback(widget.userId)),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          _avgRating    = double.tryParse(data["avgRating"]?.toString() ?? "0") ?? 0.0;
          _totalReviews = int.tryParse(data["total"]?.toString()       ?? "0") ?? 0;
          _reviews      = List<Map<String, dynamic>>.from(data["feedback"] ?? []);
          _totalJobs    = _totalReviews;

          // Build star breakdown from reviews
          _starCounts = [0, 0, 0, 0, 0];
          for (final r in _reviews) {
            final star = int.tryParse(r["rating"]?.toString() ?? "0") ?? 0;
            if (star >= 1 && star <= 5) _starCounts[star - 1]++;
          }
        }
      }
    } catch (e) {
      debugPrint("RATINGS ERROR: $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(context),
        _loading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 16),
                  _breakdownCard(isDark),
                  const SizedBox(height: 20),
                  _sectionLabel("Reviews", isDark),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
                    _emptyReviews(isDark)
                  else
                    ..._reviews.map((r) => _reviewCard(r, isDark)),
                ],
              )),
      ]),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────

  Widget _header(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16, right: 16, bottom: 24,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Ratings & Reviews",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text("Your performance summary",
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
      ])),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
        child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
      ),
    ]),
  );

  // ─── SUMMARY CARD ─────────────────────────────────────────

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppColors.glowShadow,
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_avgRating.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 56,
                fontWeight: FontWeight.w900, height: 1.0)),
        const SizedBox(height: 6),
        _starRow(_avgRating, size: 18),
        const SizedBox(height: 6),
        Text("Based on $_totalReviews reviews",
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
      const Spacer(),
      Column(children: [
        _statChip(Icons.work_rounded,       "$_totalJobs",    "Jobs Done"),
        const SizedBox(height: 10),
        _statChip(Icons.rate_review_rounded, "$_totalReviews", "Reviews"),
        const SizedBox(height: 10),
        _statChip(Icons.emoji_events_rounded,
            "${_totalReviews == 0 ? 0 : ((_starCounts[4] / _totalReviews) * 100).round()}%",
            "5★ Rate"),
      ]),
    ]),
  );

  Widget _statChip(IconData icon, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(14)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 15),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    ]),
  );

  // ─── BREAKDOWN ────────────────────────────────────────────

  Widget _breakdownCard(bool isDark) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      boxShadow: isDark ? [] : AppColors.cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Rating Breakdown",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
              color: isDark ? Colors.white : Colors.black87)),
      const SizedBox(height: 14),
      ...List.generate(5, (i) {
        final star  = 5 - i;
        final count = _starCounts[star - 1];
        final frac  = _totalReviews == 0 ? 0.0 : count / _totalReviews;
        return _barRow(star, count, frac, isDark);
      }),
    ]),
  );

  Widget _barRow(int star, int count, double fraction, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
      const SizedBox(width: 4),
      Text("$star", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54)),
      const SizedBox(width: 10),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: fraction, minHeight: 8,
          backgroundColor: isDark ? Colors.white12 : AppColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            star >= 4 ? AppColors.primary : star == 3 ? AppColors.warning : AppColors.danger),
        ),
      )),
      const SizedBox(width: 10),
      SizedBox(width: 28, child: Text("$count",
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12,
              color: isDark ? Colors.white54 : AppColors.muted))),
    ]),
  );

  // ─── SECTION LABEL ────────────────────────────────────────

  Widget _sectionLabel(String text, bool isDark) => Row(children: [
    Container(
      width: 3, height: 18, margin: const EdgeInsets.only(right: 9),
      decoration: BoxDecoration(
        gradient: AppColors.gradient, borderRadius: BorderRadius.circular(4)),
    ),
    Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
        color: isDark ? Colors.white : Colors.black87)),
  ]);

  // ─── REVIEW CARD (careseeker identity hidden — booking ID shown) ──

  Widget _reviewCard(Map<String, dynamic> r, bool isDark) {
    final rating   = double.tryParse(r["rating"]?.toString() ?? "5") ?? 5.0;
    final comment  = r["feedback"] ?? "";
    final date     = r["created_at"]?.toString() ?? "";
    final bookingId = (r["order_code"] ?? "").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        boxShadow: isDark ? [] : AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              bookingId.isNotEmpty ? "Booking $bookingId" : "Booking ID unavailable",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(_formatDate(date),
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ])),
          _starRow(rating, size: 14),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(comment, style: TextStyle(fontSize: 13.5, height: 1.55,
              color: isDark ? Colors.white70 : const Color(0xFF444444))),
        ],
      ]),
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────────

  Widget _emptyReviews(bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          shape: BoxShape.circle,
          boxShadow: AppColors.glowShadow),
        child: const Icon(Icons.star_outline_rounded, color: Colors.white, size: 36),
      ),
      const SizedBox(height: 16),
      Text("No Reviews Yet",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87)),
      const SizedBox(height: 6),
      const Text("Complete bookings to start receiving reviews.",
          style: TextStyle(color: AppColors.muted, fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );

  // ─── HELPERS ──────────────────────────────────────────────

  Widget _starRow(double rating, {double size = 16}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final filled = i < rating.floor();
      final half   = !filled && i < rating;
      return Icon(
        half ? Icons.star_half_rounded : filled ? Icons.star_rounded : Icons.star_outline_rounded,
        color: const Color(0xFFF59E0B), size: size,
      );
    }),
  );

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ["Jan","Feb","Mar","Apr","May","Jun",
                      "Jul","Aug","Sep","Oct","Nov","Dec"];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) { return raw; }
  }
}