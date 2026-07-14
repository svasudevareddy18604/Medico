import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:medico/utils/app_colors.dart';

import '../../config/api.dart';
import 'payment_details_screen.dart';

class CaretakerEarningsScreen extends StatefulWidget {
  final int caretakerId;

  const CaretakerEarningsScreen({
    super.key,
    required this.caretakerId,
  });

  @override
  State<CaretakerEarningsScreen> createState() =>
      _CaretakerEarningsScreenState();
}

class _CaretakerEarningsScreenState
    extends State<CaretakerEarningsScreen> {

  Map summary = {"total": 0, "pending": 0, "paid": 0};
  List history = [];

  bool loading = true;
  bool withdrawing = false;
  bool hasPaymentDetails = false;

  // ✅ NEW: Day / Month breakdown state
  String breakdownPeriod = "day"; // "day" | "month"
  List<dynamic> breakdownData = [];
  bool breakdownLoading = false;

  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /* ================= LOAD ================= */

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      await checkPaymentDetails();

      final summaryRes = await http.get(
        Uri.parse(Api.earnings(widget.caretakerId))
      );

      final historyRes = await http.get(
        Uri.parse(Api.earningsHistory(widget.caretakerId))
      );

      final summaryData = jsonDecode(summaryRes.body);
      final historyData = jsonDecode(historyRes.body);

      if (summaryData["success"] == true) {
        summary = summaryData["data"] ?? summary;
      }

      if (historyData["success"] == true) {
        history = historyData["data"] ?? [];
      }

      // ✅ load the breakdown for whichever tab is active
      await loadBreakdown();

    } catch (e) {
      showSnack("Failed to load data");
    }

    setState(() => loading = false);
  }

  /* ================= NEW: LOAD DAY/MONTH BREAKDOWN ================= */

  Future<void> loadBreakdown() async {
    setState(() => breakdownLoading = true);

    try {
      final res = await http.get(
        Uri.parse(Api.earningsBreakdown(widget.caretakerId, breakdownPeriod)),
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        breakdownData = data["data"] ?? [];
      } else {
        breakdownData = [];
      }
    } catch (e) {
      breakdownData = [];
    }

    if (mounted) setState(() => breakdownLoading = false);
  }

  Future<void> switchBreakdown(String period) async {
    if (breakdownPeriod == period) return;
    setState(() => breakdownPeriod = period);
    await loadBreakdown();
  }

  /* ================= CHECK PAYMENT ================= */

  Future<void> checkPaymentDetails() async {
    try {
      final res = await http.get(
        Uri.parse("${Api.baseUrl}/caretaker/payment-details/${widget.caretakerId}")
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true && data["data"].isNotEmpty) {
        hasPaymentDetails = true;
      } else {
        hasPaymentDetails = false;
      }

    } catch (e) {
      hasPaymentDetails = false;
    }
  }

  /* ================= WITHDRAW ================= */

  Future<void> requestWithdraw() async {

    if (!hasPaymentDetails) {
      showSnack("Add payment details first");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentDetailsScreen(
            userId: widget.caretakerId,
          ),
        ),
      );
      return;
    }

    if (withdrawing) return;

    setState(() => withdrawing = true);

    try {
      final res = await http.post(
        Uri.parse(Api.withdraw),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "caretaker_id": widget.caretakerId
        }),
      );

      final data = jsonDecode(res.body);

      showSnack(data["message"] ?? "Request sent");

      await loadData();

    } catch (e) {
      showSnack("Withdraw failed");
    }

    setState(() => withdrawing = false);
  }

  /* ================= UTILS ================= */

  void showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String formatAmount(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;
    return formatter.format(amount);
  }

  String formatDate(String raw) {
    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM yyyy • hh:mm a').format(date);
    } catch (e) {
      return raw;
    }
  }

  /* ================= CARD ================= */

  Widget card(String title, dynamic value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              formatAmount(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            )
          ],
        ),
      ),
    );
  }

  /* ================= HEADER ================= */

  Widget header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 25),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "Earnings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /* ================= NEW: DAY/MONTH TOGGLE PILL ================= */

  Widget breakdownToggle() {
    Widget pill(String label, String value) {
      final bool active = breakdownPeriod == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => switchBreakdown(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          pill("Day", "day"),
          pill("Month", "month"),
        ],
      ),
    );
  }

  /* ================= NEW: BREAKDOWN LIST ================= */

  Widget breakdownSection() {
    final bool isDay = breakdownPeriod == "day";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDay ? "Daily Income" : "Monthly Income",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isDay ? "Last 30 days" : "Last 12 months",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),

          const SizedBox(height: 12),
          breakdownToggle(),
          const SizedBox(height: 16),

          if (breakdownLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (breakdownData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  isDay ? "No earnings recorded for any day yet"
                        : "No earnings recorded for any month yet",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            // ✅ Highlight card for the most recent period (today / this month)
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDay ? "Today" : "This Month",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            breakdownData.first["period_label"] ?? "",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        formatAmount(breakdownData.first["total"]),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rest of the periods as a clean list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: breakdownData.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 20,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final item = breakdownData[index];
                    final orderCount = item["order_count"] ?? 0;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item["period_label"] ?? "",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "$orderCount order${orderCount == 1 ? '' : 's'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          formatAmount(item["total"]),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pending =
        double.tryParse(summary["pending"].toString()) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      body: Column(
        children: [

          header(),

          Expanded(
            child: RefreshIndicator(
              onRefresh: loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    // 🚨 WARNING BOX
                    if (!hasPaymentDetails)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Add payment details to enable withdrawal",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentDetailsScreen(
                                      userId: widget.caretakerId,
                                    ),
                                  ),
                                );
                              },
                              child: const Text("ADD"),
                            )
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        card("Total", summary["total"], AppColors.primary),
                        const SizedBox(width: 10),
                        card("Pending", summary["pending"], Colors.orange),
                        const SizedBox(width: 10),
                        card("Paid", summary["paid"], Colors.blue),
                      ],
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (pending <= 0 || withdrawing)
                            ? null
                            : requestWithdraw,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: withdrawing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                pending <= 0
                                    ? "No Amount to Withdraw"
                                    : "Withdraw ${formatAmount(pending)}",
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ✅ NEW: Day / Month income breakdown section
                    breakdownSection(),

                    const SizedBox(height: 24),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Earnings History",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    history.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Text("No earnings yet"),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final e = history[index];

                              final amount = double.tryParse(
                                e["caretaker_amount"].toString()
                              ) ?? 0;

                              final orderLabel = (e["order_code"] != null &&
                                      e["order_code"].toString().isNotEmpty)
                                  ? e["order_code"].toString()
                                  : "#${e["order_id"]}";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Order $orderLabel",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(formatDate(e["created_at"])),
                                      ],
                                    ),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatAmount(amount),
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          e["status"].toUpperCase(),
                                          style: TextStyle(
                                            color: e["status"] == "paid"
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    )

                                  ],
                                ),
                              );
                            },
                          ),

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