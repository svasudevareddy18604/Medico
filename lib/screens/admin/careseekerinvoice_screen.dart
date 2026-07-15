import 'dart:async';
import 'package:flutter/material.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import '../../models/invoice_data.dart';
import '../../services/invoice_api_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../care_seeker/invoice_screen.dart';

// ─────────────────────────────────────────────────────────────────────────
//  AdminInvoicesScreen
//  Lets admin search/filter all invoices, view, and download them.
// ─────────────────────────────────────────────────────────────────────────
class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}

class _AdminInvoicesScreenState extends State<AdminInvoicesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<InvoiceData> _invoices = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = ""; // "" = All

  final List<Map<String, String>> _filters = const [
    {"label": "All", "value": ""},
    {"label": "Paid", "value": "PAID"},
    {"label": "Pending", "value": "PENDING"},
    {"label": "Failed", "value": "FAILED"},
    {"label": "Refunded", "value": "REFUNDED"},
  ];

  bool get _dark => themeNotifier.value == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
    _fetchInvoices();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_rebuild);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchInvoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await InvoiceApiService.fetchAllInvoices(
        search: _searchCtrl.text,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _invoices = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load invoices. Pull down to retry.";
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _fetchInvoices);
  }

  void _onFilterTap(String value) {
    if (_statusFilter == value) return;
    setState(() => _statusFilter = value);
    _fetchInvoices();
  }

  void _viewInvoice(InvoiceData invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceScreen(invoice: invoice)),
    );
  }

  Future<void> _downloadInvoice(InvoiceData invoice) async {
    try {
      await InvoicePdfService.shareInvoice(invoice);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't generate the invoice.")),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "paid":
        return AppColors.success;
      case "pending":
        return Colors.orange.shade700;
      case "failed":
        return Colors.red.shade600;
      case "refunded":
        return Colors.blueGrey.shade600;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF0A1628) : AppColors.lightBg;
    final cardBg = _dark ? const Color(0xFF1A2744) : AppColors.cardBg;
    final textColor = _dark ? Colors.white : const Color(0xFF0F172A);
    final subColor = _dark ? Colors.white54 : AppColors.muted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text("All Invoices",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _searchBar(cardBg, textColor, subColor),
          _filterChips(cardBg, textColor),
          Expanded(child: _body(cardBg, textColor, subColor)),
        ],
      ),
    );
  }

  Widget _searchBar(Color cardBg, Color textColor, Color subColor) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _dark ? Colors.white12 : AppColors.border),
            boxShadow: _dark ? [] : AppColors.cardShadow,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search by Booking ID, Invoice ID, or Customer",
              hintStyle: TextStyle(color: subColor, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 21),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: subColor, size: 19),
                      onPressed: () {
                        _searchCtrl.clear();
                        _fetchInvoices();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            ),
          ),
        ),
      );

  Widget _filterChips(Color cardBg, Color textColor) => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _filters[i];
            final selected = _statusFilter == f["value"];
            return GestureDetector(
              onTap: () => _onFilterTap(f["value"]!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.gradient : null,
                  color: selected ? null : cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : (_dark ? Colors.white12 : AppColors.border),
                  ),
                ),
                child: Text(
                  f["label"]!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : (_dark ? Colors.white70 : AppColors.muted),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _body(Color cardBg, Color textColor, Color subColor) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _fetchInvoices,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 42, color: subColor),
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: TextStyle(color: subColor, fontSize: 13.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_invoices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchInvoices,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 42, color: subColor),
                    const SizedBox(height: 10),
                    Text("No invoices found",
                        style: TextStyle(color: subColor, fontSize: 13.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchInvoices,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) =>
            _invoiceCard(_invoices[i], cardBg, textColor, subColor),
      ),
    );
  }

  Widget _invoiceCard(
      InvoiceData inv, Color cardBg, Color textColor, Color subColor) {
    final statusColor = _statusColor(inv.paymentStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dark ? Colors.white12 : AppColors.border),
        boxShadow: _dark ? [] : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            inv.invoiceNo,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Booking: ${inv.bookingId}",
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  inv.paymentStatus,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
              height: 1, color: _dark ? Colors.white12 : AppColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _labelValue("Customer", inv.customerName, textColor, subColor),
              ),
              Expanded(
                child: _labelValue("Date", inv.date, textColor, subColor),
              ),
              _labelValue("Amount", "₹${inv.total.toStringAsFixed(2)}",
                  textColor, subColor, alignRight: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewInvoice(inv),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text("View", style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadInvoice(inv),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text("Download",
                      style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: subColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                        color: _dark ? Colors.white24 : AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value, Color textColor,
      Color subColor, {bool alignRight = false}) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: subColor)),
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
        ),
      ],
    );
  }
}