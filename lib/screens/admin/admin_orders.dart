import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/config/api.dart';
import 'package:medico/utils/app_colors.dart';
import 'admin_order_details_screen.dart';

class AdminOrders extends StatefulWidget {
  const AdminOrders({super.key});
  @override
  State<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  List allOrders = [];
  List filteredOrders = [];
  bool isLoading = true;
  String selectedFilter = "ALL";

  // ── SEARCH ────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // ── All possible filter tabs ──────────────────────────────────────────────
  final List<String> filters = [
    "ALL",
    "PENDING",
    "CONFIRMED",
    "ACCEPTED",
    "IN_PROGRESS",
    "COMPLETED",
    "CANCELLED",
    "CARETAKER_CANCELLED",
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────
  Future<void> fetchOrders() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(Api.adminOrders));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        allOrders = decoded['data'] ?? [];
        _applyFilters();
      }
    } catch (e) {
      debugPrint("FETCH ORDERS ERROR: $e");
    }
    setState(() => isLoading = false);
  }

  // ── FILTER + SEARCH (combined) ───────────────────────────────────────────
  void _selectFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      _applyFilters();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      _applyFilters();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = "";
      _applyFilters();
    });
  }

  void _applyFilters() {
    Iterable base = selectedFilter == "ALL"
        ? allOrders
        : allOrders.where((o) => _statusOf(o) == selectedFilter);

    if (_searchQuery.isNotEmpty) {
      base = base.where((o) => _searchableText(o).contains(_searchQuery));
    }

    filteredOrders = base.toList();
  }

  /// Flattens every value in the order map (and nested maps/lists) into one
  /// lowercase blob so search can match ANY field — name, id, category,
  /// complaint/remarks/notes text, payment method, status, date, etc —
  /// regardless of what the backend calls the field.
  final Map<Object, String> _searchCache = {};
  String _searchableText(Map o) {
    final cacheKey = o['id'] ?? o;
    if (_searchCache.containsKey(cacheKey)) return _searchCache[cacheKey]!;

    final buffer = StringBuffer();
    void collect(dynamic value) {
      if (value == null) return;
      if (value is Map) {
        for (final v in value.values) {
          collect(v);
        }
      } else if (value is List) {
        for (final v in value) {
          collect(v);
        }
      } else {
        buffer.write(value.toString());
        buffer.write(' ');
      }
    }

    collect(o);
    final text = buffer.toString().toLowerCase();
    _searchCache[cacheKey] = text;
    return text;
  }

  // ── STATUS HELPERS ────────────────────────────────────────────────────────
  String _statusOf(Map o) =>
      (o['status'] ?? "").toString().trim().toUpperCase();

  /// Short label shown in the chip — "CARETAKER_CANCELLED" → "CT CANCEL"
  String _shortStatus(String status) {
    switch (status) {
      case "CARETAKER_CANCELLED": return "CT CANCEL";
      case "IN_PROGRESS":         return "IN PROGRESS";
      default:                    return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "COMPLETED":            return const Color(0xFF1B7F6E);
      case "ACCEPTED":             return const Color(0xFF2979FF);
      case "IN_PROGRESS":          return const Color(0xFF0097A7);
      case "CONFIRMED":            return const Color(0xFF5C6BC0);
      case "PENDING":              return const Color(0xFF7C4DFF);
      case "CANCELLED":            return const Color(0xFFE53935);
      case "CARETAKER_CANCELLED":  return const Color(0xFFFF6D00);
      default:                     return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "COMPLETED":            return Icons.check_circle_rounded;
      case "ACCEPTED":             return Icons.assignment_ind_rounded;
      case "IN_PROGRESS":          return Icons.autorenew_rounded;
      case "CONFIRMED":            return Icons.thumb_up_rounded;
      case "PENDING":              return Icons.hourglass_top_rounded;
      case "CANCELLED":            return Icons.cancel_rounded;
      case "CARETAKER_CANCELLED":  return Icons.person_off_rounded;
      default:                     return Icons.info_rounded;
    }
  }

  // ── COUNT HELPER ──────────────────────────────────────────────────────────
  int _countOf(String filter) => filter == "ALL"
      ? allOrders.length
      : allOrders.where((o) => _statusOf(o) == filter).length;

  // ── WIDGETS ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Text("Booked Services",
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text("${allOrders.length} orders",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSearchBar(),
      ]),
    );
  }

  // ── SEARCH BAR ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2D3142)),
        decoration: InputDecoration(
          isDense: true,
          hintText:
              "Search order ID, name, complaint, category...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.primary, size: 22),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey[500], size: 20),
                ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Filter bar (horizontal scroll under header)
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: filters.map((f) {
            final isActive = selectedFilter == f;
            final count    = _countOf(f);
            final color    = f == "ALL" ? AppColors.primary : _statusColor(f);

            return GestureDetector(
              onTap: () => _selectFilter(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? color : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive ? color : color.withOpacity(0.25), width: 1.2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (f != "ALL") ...[
                    Icon(_statusIcon(f),
                        size: 13,
                        color: isActive ? Colors.white : color),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    f == "ALL" ? "All" : _shortStatus(f),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withOpacity(0.25)
                          : color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("$count",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : color)),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _orderCard(Map o) {
    final status      = _statusOf(o);
    final statusColor = _statusColor(status);
    final shortStatus = _shortStatus(status);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => AdminOrderDetailsScreen(order: o)));
        fetchOrders();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: statusColor.withOpacity(0.10),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(children: [

          // ── TOP ACCENT BAR ───────────────────────────────────────────────
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── ROW 1: Order code + status chip ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: order code + id (flex takes remaining space)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o['order_code'] ?? "#${o['id']}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                                letterSpacing: 0.4)),
                        const SizedBox(height: 2),
                        Text("ID: #${o['id']}",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right: status chip — FIXED width avoids overflow
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withOpacity(0.35), width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon(status), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(shortStatus,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ]),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.grey[100], height: 1),
              const SizedBox(height: 12),

              // ── ROW 2: CareSeeker + Caretaker ────────────────────────────
              Row(children: [
                Expanded(child: _infoTile(
                    Icons.person_rounded, "CareSeeker",
                    "${o['user_first_name'] ?? ''} ${o['user_last_name'] ?? ''}".trim(),
                    AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: _infoTile(
                    Icons.health_and_safety_rounded, "Caretaker",
                    o['caretaker_first_name'] != null
                        ? "${o['caretaker_first_name']} ${o['caretaker_last_name'] ?? ''}".trim()
                        : "Not Assigned",
                    o['caretaker_first_name'] != null
                        ? const Color(0xFF2979FF)
                        : Colors.orange)),
              ]),

              const SizedBox(height: 8),

              // ── ROW 3: Date + Slot + Total ───────────────────────────────
              Row(children: [
                Expanded(child: _infoTile(
                    Icons.calendar_today_rounded, "Date",
                    o['date'] ?? "-", Colors.purple)),
                const SizedBox(width: 8),
                Expanded(child: _infoTile(
                    Icons.access_time_rounded, "Slot",
                    o['slot'] ?? "-", Colors.teal)),
                const SizedBox(width: 8),
                Expanded(child: _infoTile(
                    Icons.currency_rupee_rounded, "Total",
                    "₹${o['total'] ?? 0}", const Color(0xFF1B7F6E))),
              ]),

              const SizedBox(height: 8),

              // ── ROW 4: Category + Payment ─────────────────────────────────
              Row(children: [
                Expanded(child: _infoTile(
                    Icons.category_rounded, "Category",
                    o['category'] ?? "-", Colors.indigo)),
                const SizedBox(width: 8),
                Expanded(child: _infoTile(
                    Icons.payment_rounded, "Payment",
                    o['payment_method'] ?? "-", Colors.brown)),
              ]),

              const SizedBox(height: 12),

              // ── View details ──────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text("View Full Details",
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.primary),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _emptyState() {
    final hasSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(hasSearch ? Icons.search_off_rounded : Icons.receipt_long_rounded,
            size: 64, color: Colors.grey[300]),
        const SizedBox(height: 14),
        Text(
          hasSearch
              ? "No orders match \"${_searchController.text}\""
              : selectedFilter == "ALL"
                  ? "No orders found"
                  : "No ${_shortStatus(selectedFilter)} orders",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey[400],
              fontSize: 15,
              fontWeight: FontWeight.w500),
        ),
        if (hasSearch) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _clearSearch,
            child: Text("Clear search",
                style: TextStyle(color: AppColors.primary)),
          ),
        ] else if (selectedFilter != "ALL") ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _selectFilter("ALL"),
            child: Text("Show all orders",
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ]),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(children: [

        // Fixed header (with search) + filter bar
        _buildHeader(),
        _buildFilterBar(),

        // Divider
        Container(height: 1, color: Colors.grey[200]),

        // Orders list
        Expanded(
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filteredOrders.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 12, bottom: 24),
                        itemCount: filteredOrders.length,
                        itemBuilder: (_, i) => _orderCard(filteredOrders[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}