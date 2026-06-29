import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../config/api.dart';
import 'order_details_screen.dart';

class AvailableOrdersScreen extends StatefulWidget {
  final int userId;
  final String category;
  const AvailableOrdersScreen({super.key, required this.userId, required this.category});
  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen>
    with SingleTickerProviderStateMixin {

  static const _primary  = Color(0xFF1B7F6E);
  static const _gradient = LinearGradient(
      colors: [Color(0xFF1B7F6E), Color(0xFF25A98F)],
      begin: Alignment.topLeft, end: Alignment.bottomRight);

  List   _orders  = [];
  bool   _loading = true;
  Timer? _timer;
  late AnimationController _anim;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() { _timer?.cancel(); _anim.dispose(); super.dispose(); }

  Future<void> _load({bool silent = false}) async {
    try {
      if (!silent && mounted) setState(() => _loading = true);
      // Calls GET /caretaker/orders/:category — backend filters CONFIRMED + caretaker_id IS NULL
      final res  = await http.get(Uri.parse("${Api.baseUrl}/caretaker/orders/${widget.category}"));
      final data = jsonDecode(res.body);
      final newOrders = List.from(data["orders"] ?? []);
      if (mounted) {
        setState(() { _orders = newOrders; _loading = false; });
        if (!silent) _anim.forward(from: 0);
      }
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(dynamic d) {
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${dt.day.toString().padLeft(2,'0')} ${mo[dt.month-1]} ${dt.year}";
    } catch (_) { return d?.toString() ?? ""; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5));
    if (_orders.isEmpty) return _empty();
    return RefreshIndicator(
      onRefresh: _load, color: _primary,
      child: FadeTransition(
        opacity: _fade,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: _orders.length,
          itemBuilder: (_, i) => _card(_orders[i]),
        ),
      ),
    );
  }

  Widget _card(Map order) {
    final code     = (order["order_code"] ?? "").toString();
    final services = (order["services"]   ?? "").toString();
    final category = (order["category"]   ?? "").toString();
    final location = (order["location"]   ?? "").toString();
    final slot     = (order["slot"]       ?? "").toString();
    final total    = (order["total"]      ?? 0).toString();
    final payMethod= (order["payment_method"] ?? "COD").toString();
    final date     = _fmtDate(order["date"]);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(order: order, userId: widget.userId))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0,3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top gradient bar
          Container(height: 5, decoration: BoxDecoration(gradient: _gradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Row: booking code + amount
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (code.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tag_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(code, style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8)),
                    ]),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(gradient: _gradient, borderRadius: BorderRadius.circular(20)),
                  child: Text("₹$total", style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 12),

              // Service name
              Text(services.isNotEmpty ? services : category,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),

              // Category badge
              if (category.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(category, style: const TextStyle(
                      color: _primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),

              // Info rows
              _infoRow(Icons.location_on_rounded, location),
              const SizedBox(height: 6),
              _infoRow(Icons.calendar_today_rounded, date),
              const SizedBox(height: 6),
              _infoRow(Icons.access_time_rounded, slot),
              const SizedBox(height: 14),

              // Bottom row: payment + available chip + tap hint
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _chip(payMethod, _primary),
                _chip("AVAILABLE", const Color(0xFF1565C0)),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const Icon(Icons.touch_app_rounded, size: 14, color: _primary),
                const SizedBox(width: 4),
                const Text("Tap to view & accept",
                    style: TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 16, color: _primary),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
  ]);

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
  );

  Widget _empty() => FadeTransition(
    opacity: _fade,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: _primary.withOpacity(0.08)),
        child: const Icon(Icons.inbox_rounded, size: 48, color: _primary)),
      const SizedBox(height: 22),
      const Text("No Services Available",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text("No ${widget.category} Bookings right now.\nCheck back soon!",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text("Refresh"),
        style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
      ),
    ])),
  );
}