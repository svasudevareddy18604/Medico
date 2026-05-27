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

    } catch (e) {
      showSnack("Failed to load data");
    }

    setState(() => loading = false);
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

                              // ✅ Use order_code from JOIN, fallback to order_id
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
                                          // ✅ CHANGED: show order_code instead of order_id
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