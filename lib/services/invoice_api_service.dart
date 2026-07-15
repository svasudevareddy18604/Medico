import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/invoice_data.dart';
import '../config/api.dart';

class InvoiceApiService {
  static Future<InvoiceData> fetchInvoice(int orderId) async {
    final uri = Uri.parse(Api.getInvoice(orderId));
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception("Failed to load invoice (${res.statusCode})");
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body["success"] != true) {
      throw Exception(body["message"] ?? "Failed to load invoice");
    }
    return InvoiceData.fromJson(Map<String, dynamic>.from(body["invoice"] as Map));
  }
  static Future<List<InvoiceData>> fetchAllInvoices({
    String search = "",
    String status = "",
  }) async {
    final uri = Uri.parse(Api.adminInvoices).replace(queryParameters: {
      if (search.trim().isNotEmpty) "search": search.trim(),
      if (status.trim().isNotEmpty) "status": status.trim(),
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("Failed to load invoices (${res.statusCode})");
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body["success"] != true) {
      throw Exception(body["message"] ?? "Failed to load invoices");
    }
    final list = (body["invoices"] as List<dynamic>? ?? []);
    return list
        .map((i) => InvoiceData.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();
  }
}