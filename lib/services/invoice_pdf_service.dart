import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/invoice_data.dart';

class InvoicePdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF0B8FAC);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);

  static Future<Uint8List> _buildPdf(InvoiceData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _pdfHeader(data),
            pw.SizedBox(height: 24),
            _pdfMetaRow(data),
            pw.SizedBox(height: 20),
            _pdfDivider(),
            pw.SizedBox(height: 16),
            _pdfPartyBlock(data),
            pw.SizedBox(height: 22),
            _pdfItemsTable(data),
            pw.SizedBox(height: 18),
            _pdfTotals(data),
            pw.SizedBox(height: 24),
            _pdfDivider(),
            pw.SizedBox(height: 12),
            _pdfPaymentInfo(data),
            pw.Spacer(),
            _pdfFooter(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfHeader(InvoiceData data) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("MEDICO",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold, color: _primary)),
              pw.SizedBox(height: 2),
              pw.Text("Healthcare Services",
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text("INVOICE",
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.SizedBox(height: 2),
              pw.Text(data.invoiceNo,
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ],
      );

  static pw.Widget _pdfMetaRow(InvoiceData data) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _metaItem("Booking ID", data.bookingId),
          _metaItem("Date", data.date),
          _metaItem("Payment Status", data.paymentStatus),
        ],
      );

  static pw.Widget _metaItem(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      );

  static pw.Widget _pdfPartyBlock(InvoiceData data) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Customer", style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.SizedBox(height: 3),
                pw.Text(data.customerName,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Caretaker", style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.SizedBox(height: 3),
                pw.Text(data.caretakerName,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      );

  static pw.Widget _pdfItemsTable(InvoiceData data) => pw.Table(
        border: null,
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1.4),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1))),
            children: [
              _tableHeaderCell("Service"),
              _tableHeaderCell("Slot"),
              _tableHeaderCell("Amount", alignRight: true),
            ],
          ),
          ...data.items.map((item) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.6))),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.serviceName,
                            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(item.category,
                            style: const pw.TextStyle(fontSize: 9, color: _muted)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Text(item.slot, style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Text("Rs. ${item.price.toStringAsFixed(2)}",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              )),
        ],
      );

  static pw.Widget _tableHeaderCell(String text, {bool alignRight = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
      );

  static pw.Widget _pdfTotals(InvoiceData data) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 240,
          child: pw.Column(
            children: [
              _totalRow("Subtotal", data.subtotal),
              if (data.serviceCharge > 0) _totalRow("Service Charge", data.serviceCharge),
              if (data.discount > 0) _totalRow("Discount", -data.discount),
              pw.SizedBox(height: 6),
              pw.Container(height: 1, color: _border),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Total Paid",
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs. ${data.total.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold, color: _primary)),
                ],
              ),
            ],
          ),
        ),
      );

  static pw.Widget _totalRow(String label, double value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: _muted)),
            pw.Text(
                "${value < 0 ? '-' : ''}Rs. ${value.abs().toStringAsFixed(2)}",
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

  static pw.Widget _pdfPaymentInfo(InvoiceData data) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _metaItem("Payment Method", data.paymentMethod),
          _metaItem("Payment Status", data.paymentStatus),
        ],
      );

  static pw.Widget _pdfDivider() => pw.Container(height: 1, color: _border);

  static pw.Widget _pdfFooter() => pw.Center(
        child: pw.Text(
          "This is a system-generated invoice from Medico Healthcare Services.",
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      );

  /// Opens the native share/save sheet with the generated invoice PDF.
  static Future<void> shareInvoice(InvoiceData data) async {
    final bytes = await _buildPdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: "${data.invoiceNo}.pdf",
    );
  }

  /// Opens the OS print/preview dialog (also allows "Save as PDF" on most platforms).
  static Future<void> printInvoice(InvoiceData data) async {
    final bytes = await _buildPdf(data);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: "${data.invoiceNo}.pdf",
    );
  }
}