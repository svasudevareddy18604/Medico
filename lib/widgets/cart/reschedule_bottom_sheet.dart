import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api.dart';

/// Bottom sheet used from Order Details to move a booking to a new
/// date/time, pulled live from the admin-managed slot pool
/// (service_slots table). Only ever shown while the order is still
/// CONFIRMED (no caretaker has accepted yet) — the caller is
/// responsible for that check.
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

  // Each slot: {"id": "12", "slot_time": "09:00"}
  List<Map<String, String>> _slots = [];
  int? _selectedSlotId;
  String _selectedSlotTime = "";

  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

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

  // ── Fetch live slots from the admin slot pool ──────────────────────
  Future<void> _fetchSlots() async {
    setState(() {
      _loadingSlots = true;
      _selectedSlotId = null;
      _selectedSlotTime = "";
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(
              "${Api.getAvailableSlots(widget.orderId)}?date=$_selectedDate"))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final rawSlots = List<Map<String, dynamic>>.from(data["slots"] ?? []);
        setState(() {
          _slots = rawSlots
              .map((s) => {
                    "id": s["id"].toString(),
                    "slot_time": s["slot_time"].toString(),
                  })
              .toList();
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

  String _formatTime(String hhmm) {
    try {
      final p = hhmm.split(":");
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])).format(context);
    } catch (_) {
      return hhmm;
    }
  }

  Future<void> _confirmReschedule() async {
    if (_selectedSlotId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final prefs  = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      final res = await http.post(
        Uri.parse(Api.rescheduleOrder(widget.orderId)),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "date": _selectedDate,
          "slot_id": _selectedSlotId,
          "user_id": userId,
        }),
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
          // If the slot was taken between load and submit, refresh the list.
          if ((data["message"]?.toString() ?? "").toLowerCase().contains("taken")) {
            _fetchSlots();
          }
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

              Row(children: [
                Text("Available Slots",
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                const Spacer(),
                if (!_loadingSlots)
                  GestureDetector(
                    onTap: _fetchSlots,
                    child: Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                  ),
              ]),
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
                    child: Column(children: [
                      Icon(Icons.event_busy_rounded, color: subColor, size: 28),
                      const SizedBox(height: 8),
                      Text("No slots available for this date",
                          style: TextStyle(color: subColor)),
                    ]),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _slots.map((s) {
                    final id  = int.parse(s["id"]!);
                    final t   = s["slot_time"]!;
                    final sel = _selectedSlotId == id;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedSlotId = id;
                        _selectedSlotTime = t;
                      }),
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
                    onTap: (_selectedSlotId == null || _submitting) ? null : _confirmReschedule,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient:
                            (_selectedSlotId != null && !_submitting) ? AppColors.gradient : null,
                        color: (_selectedSlotId == null || _submitting)
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
                              _selectedSlotId == null ? "Select a slot" : "Confirm Reschedule",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: _selectedSlotId == null
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