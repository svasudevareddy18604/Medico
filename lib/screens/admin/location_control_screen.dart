import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';

class LocationControlScreen extends StatefulWidget {
  const LocationControlScreen({super.key});

  @override
  State<LocationControlScreen> createState() =>
      _LocationControlScreenState();
}

class _LocationControlScreenState extends State<LocationControlScreen> {

  String mode = "ALL_INDIA";

  List<String> statesList = [];
  List<String> selectedStates = [];

  List<String> selectedAreas = [];
  List<String> pincodes = [];

  final TextEditingController areaController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  /* ================= FETCH ================= */

  Future<void> fetchData() async {
    try {
      final res =
          await http.get(Uri.parse("${Api.baseUrl}/admin/location"));

      final data = jsonDecode(res.body);

      setState(() {
        mode = data['mode'] ?? "ALL_INDIA";

        statesList = List<String>.from(data['statesList'] ?? []);

        selectedStates =
            List<String>.from(data['states'] ?? []);

        selectedAreas =
            List<String>.from(data['areas'] ?? []);

        pincodes =
            List<String>.from(data['pincodes'] ?? []);

        isLoading = false;
      });
    } catch (e) {
      isLoading = false;
    }
  }

  /* ================= SAVE ================= */

  Future<void> saveSettings() async {
    final body = {
      "mode": mode,
      "states": selectedStates,
      "areas": selectedAreas,
      "pincodes": pincodes,
    };

    final res = await http.post(
      Uri.parse("${Api.baseUrl}/admin/location"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved Successfully")),
      );
    }
  }

  /* ================= ADD AREA ================= */

  void addArea() {
    final text = areaController.text.trim();

    if (text.isNotEmpty && !selectedAreas.contains(text)) {
      setState(() {
        selectedAreas.add(text);
        areaController.clear();
      });
    }
  }

  /* ================= ADD PINCODE ================= */

  void addPincode() {
    final text = pincodeController.text.trim();

    if (text.length == 6 && !pincodes.contains(text)) {
      setState(() {
        pincodes.add(text);
        pincodeController.clear();
      });
    }
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text("Location Control"),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F9D58), Color(0xFF34A853)],
            ),
          ),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 🔥 MODE
                  const Text("Service Mode",
                      style: TextStyle(fontWeight: FontWeight.bold)),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: "ALL_INDIA", child: Text("All India")),
                      DropdownMenuItem(
                          value: "STATE", child: Text("Selected States")),
                      DropdownMenuItem(
                          value: "CUSTOM", child: Text("Custom Areas")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        mode = val!;
                        selectedStates.clear();
                        selectedAreas.clear();
                        pincodes.clear();
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 MULTI STATE SELECT
                  if (mode != "ALL_INDIA") ...[
                    const Text("Select States"),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statesList.map((state) {
                        final isSelected =
                            selectedStates.contains(state);

                        return FilterChip(
                          label: Text(state),
                          selected: isSelected,
                          selectedColor:
                              const Color(0xFF0F9D58).withOpacity(0.2),
                          onSelected: (_) {
                            setState(() {
                              if (isSelected) {
                                selectedStates.remove(state);
                              } else {
                                selectedStates.add(state);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  /// 🔥 CUSTOM AREAS
                  if (mode == "CUSTOM") ...[

                    /// AREA
                    TextField(
                      controller: areaController,
                      decoration: InputDecoration(
                        labelText: "Enter Area (Ongole, Anekal...)",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: addArea,
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      children: selectedAreas.map((area) {
                        return Chip(
                          label: Text(area),
                          onDeleted: () =>
                              setState(() => selectedAreas.remove(area)),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    /// PINCODE
                    TextField(
                      controller: pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Enter Pincode",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: addPincode,
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      children: pincodes.map((p) {
                        return Chip(
                          label: Text(p),
                          onDeleted: () =>
                              setState(() => pincodes.remove(p)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 30),

                  /// SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: saveSettings,
                      child: const Text("Save Settings",
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}