import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import '../../config/api.dart';

/// Bottom sheet used from Order Details to move a booking to a new
/// date/time. Only ever shown while the order is still CONFIRMED
/// (no caretaker has accepted yet) — the caller is responsible for
/// that check.
class RescheduleBottomSheet extends StatefulWidget {
  final int orderId;
  final String currentDate;
  final String currentSlot;
  final VoidCallback onRescheduled;

  const RescheduleBottomSheet({
    super.key,
    required this.orderId,
    required this.currentDate,
    required this.currentSlot,
    required this.onRescheduled,
  });

  @override
  State<RescheduleBottomSheet> createState() => _RescheduleBottomSheetState();
}

class _RescheduleBottomSheetState extends State<RescheduleBottomSheet> {
  bool get _dark => themeNotifier.value == ThemeMode.dark;

  late List<Map<String, String>> _dates;
  String _selectedDate = "";
  String _selectedSlot = "";
  List<String> _slots = [];
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

  // Default hourly slots — adjust to match your real service hours,
  // or wire this up to whatever slot source your booking flow already uses.
  static const List<String> _slotTimes = [
    "08:00", "09:00", "10:00", "11:00", "12:00", "13:00",
    "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00",
  ];

  @override
  void initState() {
    super.initState();
    _dates = _buildDates();
    _selectedDate = _dates.first["value"]!;
    _fetchSlots();
  }

  List<Map<String, String>> _buildDates() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final d = now.add(Duration(days: i));
      final value =
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final label = i == 0 ? "Today" : "${days[d.weekday - 1]} ${d.day}";
      return {"value": value, "label": label};
    });
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _loadingSlots = true;
      _selectedSlot = "";
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(
              "${Api.baseUrl}/orders/${widget.orderId}/available-slots?date=$_selectedDate"))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final booked = List<String>.from(data["booked_slots"] ?? []);
        final now = DateTime.now();
        final d = DateTime.parse(_selectedDate);

        final available = _slotTimes.where((t) {
          if (booked.contains(t)) return false;
          final parts = t.split(":");
          final slotDt = DateTime(
              d.year, d.month, d.day, int.parse(parts[0]), int.parse(parts[1]));
          return slotDt.isAfter(now);
        }).toList();

        setState(() {
          _slots = available;
          _loadingSlots = false;
        });
      } else {
        setState(() {
          _slots = [];
          _loadingSlots = false;
          _error = data["message"]?.toString();
        });
      }
    } catch (_) {
      setState(() {
        _slots = [];
        _loadingSlots = false;
        _error = "Could not load slots. Please try again.";
      });
    }
  }

  String _formatTime(String t) {
    try {
      final p = t.split(":");
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])).format(context);
    } catch (_) {
      return t;
    }
  }

  Future<void> _confirmReschedule() async {
    if (_selectedSlot.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/orders/${widget.orderId}/reschedule"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"date": _selectedDate, "slot": _selectedSlot}),
      );
      final data = jsonDecode(res.body);

      if (mounted) {
        if (data["success"] == true) {
          Navigator.pop(context);
          widget.onRescheduled();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Booking rescheduled successfully!",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.all(16),
            ),
          );
        } else {
          setState(() =>
              _error = data["message"]?.toString() ?? "Could not reschedule booking.");
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Network error. Please try again.");
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = _dark ? Colors.white : Colors.black87;
    final subColor = _dark ? Colors.grey.shade400 : Colors.grey.shade500;
    final chipBg = _dark ? const Color(0xFF0F172A) : Colors.grey[100]!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _dark ? Colors.grey.shade600 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_repeat_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text("Reschedule Booking",
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text("Choose a new date & time slot",
                    style: TextStyle(color: subColor, fontSize: 13)),
              ),
              const SizedBox(height: 20),

              Text("Select Date",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  itemBuilder: (_, i) {
                    final sel = _dates[i]["value"] == _selectedDate;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = _dates[i]["value"]!);
                        _fetchSlots();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : chipBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : (_dark ? Colors.grey.shade700 : Colors.transparent),
                          ),
                        ),
                        child: Text(_dates[i]["label"]!,
                            style: TextStyle(
                              color: sel ? Colors.white : (_dark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              Text("Available Slots",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
              const SizedBox(height: 10),

              if (_loadingSlots)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_slots.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text("No slots available for this date",
                        style: TextStyle(color: subColor)),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _slots.map((t) {
                    final sel = _selectedSlot == t;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSlot = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : chipBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : (_dark ? Colors.grey.shade700 : Colors.grey.shade300),
                          ),
                        ),
                        child: Text(_formatTime(t),
                            style: TextStyle(
                              color: sel ? Colors.white : (_dark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    );
                  }).toList(),
                ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: AppColors.danger, fontSize: 12.5))),
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Text("Cancel",
                        style: TextStyle(color: subColor, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: (_selectedSlot.isEmpty || _submitting) ? null : _confirmReschedule,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient:
                            (_selectedSlot.isNotEmpty && !_submitting) ? AppColors.gradient : null,
                        color: (_selectedSlot.isEmpty || _submitting)
                            ? (_dark ? Colors.grey.shade700 : Colors.grey[300])
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _selectedSlot.isEmpty ? "Select a slot" : "Confirm Reschedule",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedSlot.isEmpty
                                    ? (_dark ? Colors.grey.shade400 : Colors.grey.shade600)
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}