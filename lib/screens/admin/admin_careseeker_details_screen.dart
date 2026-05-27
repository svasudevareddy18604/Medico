import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminCareSeekerDetails extends StatefulWidget {
  final Map user;
  const AdminCareSeekerDetails({super.key, required this.user});

  @override
  State<AdminCareSeekerDetails> createState() => _AdminCareSeekerDetailsState();
}

class _AdminCareSeekerDetailsState extends State<AdminCareSeekerDetails> {
  Map? _stats;
  List _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future _fetch() async {
    try {
      final res = await http.get(Uri.parse(Api.careSeekerDetails(widget.user['id'])));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _stats  = data['stats'];
          _orders = data['orders'];
        });
      }
    } catch (e) {
      debugPrint("DETAIL ERROR: $e");
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final u       = widget.user;
    final blocked = u['is_blocked'] == 1 || u['is_blocked'] == true;
    final initials = (u['first_name'] ?? 'U')[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // ── APP BAR ────────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(gradient: AppColors.gradient),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    backgroundImage: (u['profile_image'] != null && u['profile_image'] != 'NULL')
                                        ? NetworkImage(u['profile_image']) : null,
                                    child: (u['profile_image'] == null || u['profile_image'] == 'NULL')
                                        ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                ),
                                if (blocked)
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: Icon(Icons.block, size: 14, color: Colors.red.shade600),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim(),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: blocked ? Colors.red.shade600 : Colors.green.shade600,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                blocked ? "Blocked" : "Active",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  backgroundColor: AppColors.primary,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text("User Details", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [

                      // ── CONTACT INFO ──────────────────────────────────────
                      _sectionCard("Contact Info", Icons.person_outline, [
                        _infoRow(Icons.phone_outlined,  "Mobile",   u['mobile']  ?? '-'),
                        _infoRow(Icons.email_outlined,  "Email",    u['email']   ?? '-'),
                        _infoRow(Icons.calendar_today,  "Joined",   _formatDate(u['created_at'])),
                        _infoRow(Icons.verified_user,   "Verified", u['verified'] == 1 ? "Yes" : "No"),
                      ]),

                      const SizedBox(height: 14),

                      // ── STATS GRID ────────────────────────────────────────
                      if (_stats != null) ...[
                        _statGrid(),
                        const SizedBox(height: 14),

                        // ── FINANCIAL SUMMARY ─────────────────────────────
                        _sectionCard("Financial Summary", Icons.account_balance_wallet_outlined, [
                          _infoRow(Icons.currency_rupee,    "Total Spent",    "₹${_stats!['total_spent'] ?? 0}"),
                          _infoRow(Icons.currency_rupee,    "Total Refunded", "₹${_stats!['total_refunded'] ?? 0}"),
                          _infoRow(Icons.receipt_long,      "COD Orders",     "${_stats!['cod_orders'] ?? 0}"),
                          _infoRow(Icons.credit_card,       "Online Orders",  "${_stats!['online_orders'] ?? 0}"),
                        ]),
                        const SizedBox(height: 14),
                      ],

                      // ── ORDER HISTORY ─────────────────────────────────────
                      _ordersSection(),

                      const SizedBox(height: 30),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Stats 3x2 grid ────────────────────────────────────────────────────────
  Widget _statGrid() {
    final s = _stats!;
    final items = [
      {"label": "Total Bookings", "value": "${s['total_orders'] ?? 0}",     "icon": Icons.shopping_bag_outlined,  "color": AppColors.primary},
      {"label": "Completed",      "value": "${s['completed'] ?? 0}",         "icon": Icons.check_circle_outline,   "color": Colors.green.shade600},
      {"label": "Cancelled",      "value": "${s['cancelled'] ?? 0}",         "icon": Icons.cancel_outlined,        "color": Colors.red.shade500},
      {"label": "Pending",        "value": "${s['pending'] ?? 0}",           "icon": Icons.hourglass_empty_rounded,"color": Colors.orange.shade600},
      {"label": "Assigned",       "value": "${s['assigned'] ?? 0}",          "icon": Icons.assignment_ind_outlined,"color": Colors.blue.shade600},
      {"label": "Total Revenue",  "value": "₹${s['total_spent'] ?? 0}",     "icon": Icons.currency_rupee,         "color": Colors.teal.shade600},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: items.map((item) {
        final color = item['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(item['icon'] as IconData, size: 20, color: color),
              ),
              const SizedBox(height: 7),
              Text(item['value'] as String,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 3),
              Text(item['label'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Orders list ───────────────────────────────────────────────────────────
  Widget _ordersSection() {
    if (_orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(Icons.receipt_long, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text("No orders yet", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(Icons.history, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text("Order History", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          ]),
        ),
        ..._orders.map((o) => _orderCard(o)),
      ],
    );
  }

  Widget _orderCard(Map o) {
    final status  = o['status'] ?? '';
    final Color sc = _statusColor(status);
    final cancelled = status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cancelled ? Colors.red.shade100 : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(o['order_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sc)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _pill(Icons.medical_services_outlined, o['category'] ?? '-', Colors.blue.shade600),
            const SizedBox(width: 8),
            _pill(Icons.payment, o['payment_method'] ?? '-', Colors.purple.shade600),
            const SizedBox(width: 8),
            _pill(Icons.currency_rupee, "₹${o['total'] ?? 0}", Colors.teal.shade600),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(_formatDate(o['created_at']), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const Spacer(),
            if (o['refund_amount'] != null && double.tryParse(o['refund_amount'].toString())! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                child: Text("Refund: ₹${o['refund_amount']}", style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
              ),
          ]),
          if (cancelled && o['cancel_reason'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 12, color: Colors.red.shade400),
                const SizedBox(width: 4),
                Expanded(child: Text("Reason: ${o['cancel_reason']}", style: TextStyle(fontSize: 11, color: Colors.red.shade600))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _sectionCard(String title, IconData icon, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
        ]),
      );

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED': return Colors.green.shade600;
      case 'CANCELLED': return Colors.red.shade500;
      case 'ASSIGNED':  return Colors.blue.shade600;
      case 'PENDING':   return Colors.orange.shade600;
      default:          return Colors.grey;
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) { return d.toString(); }
  }
}