class InvoiceItem {
  final String serviceName;
  final String category;
  final String slot;
  final double price;

  InvoiceItem({
    required this.serviceName,
    required this.category,
    required this.slot,
    required this.price,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        serviceName: (json["service_name"] ?? "Service").toString(),
        category: (json["category"] ?? "Service").toString(),
        slot: (json["slot"] ?? "-").toString(),
        price: double.tryParse(json["price"].toString()) ?? 0,
      );
}

class InvoiceData {
  final int invoiceId;
  final String invoiceNo;
  final String bookingId;
  final String date;
  final String customerName;
  final String caretakerName;
  final List<InvoiceItem> items;
  final double subtotal;
  final double serviceCharge;
  final double discount;
  final double total;
  final String paymentMethod;
  final String paymentStatus;

  InvoiceData({
    required this.invoiceId,
    required this.invoiceNo,
    required this.bookingId,
    required this.date,
    required this.customerName,
    required this.caretakerName,
    required this.items,
    required this.subtotal,
    required this.serviceCharge,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    final itemsList = (json["items"] as List<dynamic>? ?? [])
        .map((i) => InvoiceItem.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();

    return InvoiceData(
      invoiceId: json["invoice_id"] is int
          ? json["invoice_id"]
          : int.tryParse(json["invoice_id"].toString()) ?? 0,
      invoiceNo: (json["invoice_no"] ?? "").toString(),
      bookingId: (json["booking_id"] ?? "").toString(),
      date: (json["date"] ?? "").toString(),
      customerName: (json["customer_name"] ?? "Customer").toString(),
      caretakerName: (json["caretaker_name"] ?? "Not assigned yet").toString(),
      items: itemsList,
      subtotal: double.tryParse(json["subtotal"].toString()) ?? 0,
      serviceCharge: double.tryParse(json["service_charge"].toString()) ?? 0,
      discount: double.tryParse(json["discount"].toString()) ?? 0,
      total: double.tryParse(json["total"].toString()) ?? 0,
      paymentMethod: (json["payment_method"] ?? "-").toString(),
      paymentStatus: (json["payment_status"] ?? "-").toString(),
    );
  }
}