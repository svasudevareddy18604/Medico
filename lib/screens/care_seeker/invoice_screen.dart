import 'package:flutter/material.dart';
import 'package:medico/utils/app_colors.dart';
import '../../models/invoice_data.dart';
import '../../services/invoice_pdf_service.dart';

class InvoiceScreen extends StatefulWidget {
  final InvoiceData invoice;
  const InvoiceScreen({super.key, required this.invoice});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await InvoicePdfService.shareInvoice(widget.invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't generate the invoice. Please try again.")),
        );
      }
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = widget.invoice;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg;
    final sub = isDark ? Colors.white54 : AppColors.muted;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
            child: Column(children: [
              // ── Invoice card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
                  boxShadow: isDark ? [] : AppColors.cardShadow,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Brand row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => AppColors.gradient.createShader(bounds),
                            child: const Text("MEDICO",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 2),
                          Text("Healthcare Services",
                              style: TextStyle(fontSize: 11, color: sub)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("INVOICE",
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 2),
                          Text(inv.invoiceNo, style: TextStyle(fontSize: 10.5, color: sub)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _divider(isDark),
                  const SizedBox(height: 16),

                  // Meta row
                  Row(children: [
                    Expanded(child: _metaItem("Booking ID", inv.bookingId, textColor, sub)),
                    Expanded(child: _metaItem("Date", inv.date, textColor, sub)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _metaItem("Customer", inv.customerName, textColor, sub)),
                    Expanded(child: _metaItem("Caretaker", inv.caretakerName, textColor, sub)),
                  ]),

                  const SizedBox(height: 20),
                  _divider(isDark),
                  const SizedBox(height: 16),

                  Text("Services",
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),

                  ...inv.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.serviceName,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textColor)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(item.category,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.access_time_rounded, size: 12, color: sub),
                                    const SizedBox(width: 3),
                                    Text(item.slot, style: TextStyle(fontSize: 11, color: sub)),
                                  ]),
                                ],
                              ),
                            ),
                            Text("₹${item.price.toStringAsFixed(2)}",
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                          ],
                        ),
                      )),

                  const SizedBox(height: 8),
                  _divider(isDark),
                  const SizedBox(height: 14),

                  _billRow("Subtotal", "₹${inv.subtotal.toStringAsFixed(2)}", sub, textColor),
                  if (inv.serviceCharge > 0) ...[
                    const SizedBox(height: 8),
                    _billRow("Service Charge", "+₹${inv.serviceCharge.toStringAsFixed(2)}",
                        sub, Colors.orange.shade700),
                  ],
                  if (inv.discount > 0) ...[
                    const SizedBox(height: 8),
                    _billRow("Discount", "−₹${inv.discount.toStringAsFixed(2)}",
                        sub, AppColors.success),
                  ],
                  const SizedBox(height: 12),
                  _divider(isDark),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text("Total Paid",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("₹${inv.total.toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _divider(isDark),
                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                        child: _metaItem("Payment Method", inv.paymentMethod, textColor, sub)),
                    Expanded(
                        child: _statusPill(inv.paymentStatus)),
                  ]),
                ]),
              ),

              const SizedBox(height: 22),
              Text(
                "This is a system-generated invoice from Medico Healthcare Services.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: sub, height: 1.4),
              ),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _downloading ? null : _download,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text("Share",
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.glowShadow,
              ),
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                label: Text(_downloading ? "Preparing..." : "Download PDF",
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 14,
          left: 8, right: 20, bottom: 22,
        ),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
        ),
        child: Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 4),
          const Text("Invoice",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _divider(bool isDark) =>
      Container(height: 1, color: isDark ? Colors.white12 : AppColors.border);

  Widget _metaItem(String label, String value, Color textColor, Color sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: sub)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        ],
      );

  Widget _billRow(String label, String value, Color sub, Color valueColor) => Row(children: [
        Text(label, style: TextStyle(fontSize: 13, color: sub)),
        const Spacer(),
        Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
      ]);

  Widget _statusPill(String status) {
    final ok = status.toLowerCase() == "paid";
    final color = ok ? AppColors.success : Colors.orange.shade700;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              size: 13, color: color),
          const SizedBox(width: 5),
          Text(status,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}