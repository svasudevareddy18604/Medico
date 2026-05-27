import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api.dart';
import '../../utils/app_colors.dart';

class AdminTimeSlotScreen extends StatefulWidget {
  const AdminTimeSlotScreen({super.key});

  @override
  State<AdminTimeSlotScreen> createState() => _AdminTimeSlotScreenState();
}

class _AdminTimeSlotScreenState extends State<AdminTimeSlotScreen> {
  final String baseUrl = "${Api.baseUrl}/slots";

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String searchQuery = "";
  bool loading = false;
  Map<String, List> groupedSlots = {};

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  Future<void> loadSlots() async {
    setState(() => loading = true);
    final res = await http.get(Uri.parse("$baseUrl/all"));
    final data = jsonDecode(res.body);
    final List slots = data["slots"] ?? [];
    final Map<String, List> temp = {};
    for (var s in slots) {
      final dt = DateTime.parse(s["slot_date"]).toLocal();
      final date = "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";
      temp.putIfAbsent(date, () => []).add(s);
    }
    setState(() { groupedSlots = temp; loading = false; });
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> createSlot() async {
    if (selectedDate == null || selectedTime == null) {
      _snack("Please select both date & time");
      return;
    }
    final date = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2,'0')}-${selectedDate!.day.toString().padLeft(2,'0')}";
    final time = "${selectedTime!.hour.toString().padLeft(2,'0')}:${selectedTime!.minute.toString().padLeft(2,'0')}:00";
    await http.post(
      Uri.parse("$baseUrl/create"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"slot_date": date, "slot_time": time}),
    );
    setState(() => selectedTime = null);
    loadSlots();
  }

  Future<void> deleteSlot(int id) async {
    final confirm = await _confirmDialog("Delete this slot?");
    if (confirm != true) return;
    await http.delete(Uri.parse("$baseUrl/delete/$id"));
    loadSlots();
  }

  Future<void> editSlot(int id) async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (newTime == null) return;
    final time = "${newTime.hour.toString().padLeft(2,'0')}:${newTime.minute.toString().padLeft(2,'0')}:00";
    await http.put(
      Uri.parse("$baseUrl/update/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"slot_time": time}),
    );
    loadSlots();
  }

  String formatTime(String? time) {
    if (time == null) return "—";
    try {
      final p = time.split(":");
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])).format(context);
    } catch (_) { return time; }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
  );

  Future<bool?> _confirmDialog(String msg) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Confirm"),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  Map<String, List> get filteredSlots {
    if (searchQuery.isEmpty) return groupedSlots;
    return Map.fromEntries(
      groupedSlots.entries.where((e) => e.key.contains(searchQuery)),
    );
  }

  // ── WIDGETS ──────────────────────────────────────────────

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.schedule_rounded, color: Colors.white, size: 26),
        const SizedBox(width: 10),
        const Text("Time Slot Management",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: loadSlots,
        ),
      ]),
    ]),
  );

  Widget _picker({required String label, required IconData icon, required VoidCallback onTap}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(
            color: label.startsWith("Select") ? Colors.grey.shade400 : Colors.black87,
            fontSize: 15,
          ))),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
        ]),
      ),
    );

  Widget _searchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
    ),
    child: Row(children: [
      Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          onChanged: (v) => setState(() => searchQuery = v),
          decoration: InputDecoration.collapsed(
            hintText: "Search by date (e.g. 2025-06-15)",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          style: const TextStyle(fontSize: 15),
        ),
      ),
      if (searchQuery.isNotEmpty)
        GestureDetector(
          onTap: () => setState(() => searchQuery = ""),
          child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
        ),
    ]),
  );

  Widget _slotCard(dynamic slot) => Container(
    margin: const EdgeInsets.symmetric(vertical: 5),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(
        formatTime(slot["slot_time"]),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
      )),
      _iconBtn(Icons.edit_rounded, Colors.blue.shade400, () => editSlot(slot["id"])),
      const SizedBox(width: 4),
      _iconBtn(Icons.delete_outline_rounded, Colors.red.shade400, () => deleteSlot(slot["id"])),
    ]),
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
  );

  Widget _dateGroup(String date, List slots) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          Container(width: 4, height: 16,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("${slots.length} slot${slots.length > 1 ? 's' : ''}",
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      ...slots.map(_slotCard),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final data = filteredSlots;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createSlot,
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Create Slot", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        _header(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Date & Time pickers
              Row(children: [
                Expanded(child: _picker(
                  label: selectedDate == null ? "Select Date"
                    : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2,'0')}-${selectedDate!.day.toString().padLeft(2,'0')}",
                  icon: Icons.calendar_today_rounded, onTap: pickDate,
                )),
                const SizedBox(width: 10),
                Expanded(child: _picker(
                  label: selectedTime == null ? "Select Time" : selectedTime!.format(context),
                  icon: Icons.access_time_rounded, onTap: pickTime,
                )),
              ]),

              const SizedBox(height: 12),
              _searchBar(),
              const SizedBox(height: 20),

              Row(children: [
                const Text("Created Slots", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("${data.values.fold(0, (s, l) => s + l.length)} total",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ]),

              const SizedBox(height: 4),

              if (loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (data.isEmpty)
                Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_busy_rounded, size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text("No slots found", style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                ])))
              else
                Expanded(child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: data.entries.map((e) => _dateGroup(e.key, e.value)).toList(),
                )),
            ]),
          ),
        ),
      ]),
    );
  }
}