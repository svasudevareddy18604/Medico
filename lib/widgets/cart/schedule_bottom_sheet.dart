import 'package:flutter/material.dart';
import 'package:medico/main.dart';
import '../../screens/care_seeker/payment_screen.dart';
import '../../screens/care_seeker/upload_documents_screen.dart';

class ScheduleBottomSheet extends StatefulWidget {
  final int userId;
  final List cartItems;
  final double total, discount, serviceCharge;
  final String location, couponCode;
  final double? lat, lng;
  final Color primary;
  final Future<List> Function(String) loadSlots;
  final List dates;
  final Future<void> Function() clearCart, reloadCart, reloadSummary;

  const ScheduleBottomSheet({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.total,
    required this.discount,
    this.serviceCharge = 0.0,
    required this.location,
    this.couponCode = "",
    required this.lat,
    required this.lng,
    required this.primary,
    required this.loadSlots,
    required this.dates,
    required this.clearCart,
    required this.reloadCart,
    required this.reloadSummary,
  });

  @override
  State<ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<ScheduleBottomSheet> {
  String selectedDate = "", selectedSlot = "";
  List localSlots = [];
  bool loadingSlots = false;

  bool get isDark => themeNotifier.value == ThemeMode.dark;

  // ── Step 2: requiresDocuments getter (placed before finalTotal) ──
  bool get requiresDocuments {
    return widget.cartItems.any(
      (item) =>
          item["requires_documents"] == true ||
          item["requires_documents"] == 1,
    );
  }

  double get finalTotal =>
      (widget.total + widget.serviceCharge - widget.discount)
          .clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    if (widget.dates.isNotEmpty) {
      selectedDate = widget.dates[0]["value"];
      _fetchSlots();
    }
  }

  Future<void> _fetchSlots() async {
    setState(() {
      loadingSlots = true;
      selectedSlot = "";
    });
    final result = await widget.loadSlots(selectedDate);
    setState(() {
      localSlots = result;
      loadingSlots = false;
    });
  }

  String _formatTime(String time) {
    try {
      final p = time.split(":");
      return TimeOfDay(
        hour: int.parse(p[0]),
        minute: int.parse(p[1]),
      ).format(context);
    } catch (_) {
      return time;
    }
  }

  List _filteredSlots() {
    final now = DateTime.now();
    return localSlots.where((s) {
      try {
        final p = s["slot_time"].split(":");
        final d = DateTime.parse(selectedDate);
        return DateTime(
          d.year, d.month, d.day,
          int.parse(p[0]), int.parse(p[1]),
        ).isAfter(now);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // ── Step 3: Full _goToPayment() with document check ──
  void _goToPayment() {
    Navigator.pop(context);

    if (requiresDocuments) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadDocumentsScreen(
            userId: widget.userId,
            cartItems: widget.cartItems,
            subtotal: widget.total,
            serviceCharge: widget.serviceCharge,
            discount: widget.discount,
            couponCode: widget.couponCode,
            slot: selectedSlot,
            date: selectedDate,
            location: widget.location,
            latitude: widget.lat,
            longitude: widget.lng,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            userId: widget.userId,
            cartItems: widget.cartItems,
            subtotal: widget.total,
            serviceCharge: widget.serviceCharge,
            discount: widget.discount,
            couponCode: widget.couponCode,
            slot: selectedSlot,
            date: selectedDate,
            location: widget.location,
            latitude: widget.lat,
            longitude: widget.lng,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg        = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final chipBg    = isDark ? const Color(0xFF0F172A) : Colors.grey[100]!;
    final filtered  = _filteredSlots();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Drag Handle ──
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            Text(
              "Schedule Your Service",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Choose preferred date & time slot",
              style: TextStyle(color: subColor, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ── Date Selector ──
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.dates.length,
                itemBuilder: (_, i) {
                  final sel = widget.dates[i]["value"] == selectedDate;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedDate = widget.dates[i]["value"]);
                      _fetchSlots();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? widget.primary : chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? widget.primary
                              : (isDark
                                  ? Colors.grey.shade700
                                  : Colors.transparent),
                        ),
                      ),
                      child: Text(
                        widget.dates[i]["label"],
                        style: TextStyle(
                          color: sel
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Slots ──
            Text(
              "Available Slots",
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 10),

            if (loadingSlots)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "No slots available for this date",
                    style: TextStyle(color: subColor),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: filtered.map<Widget>((slot) {
                  final t   = _formatTime(slot["slot_time"]);
                  final sel = selectedSlot == t;
                  return GestureDetector(
                    onTap: () => setState(() => selectedSlot = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? widget.primary : chipBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? widget.primary
                              : (isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: sel
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // ── Confirm Button ──
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: selectedSlot.isEmpty ? null : _goToPayment,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: selectedSlot.isNotEmpty
                        ? LinearGradient(colors: [
                            widget.primary,
                            widget.primary.withOpacity(0.8),
                          ])
                        : null,
                    color: selectedSlot.isEmpty
                        ? (isDark
                            ? Colors.grey.shade700
                            : Colors.grey[300])
                        : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    selectedSlot.isEmpty
                        ? "Select a time slot"
                        : "Confirm & Pay ₹${finalTotal.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selectedSlot.isEmpty
                          ? (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}