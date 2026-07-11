import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medico/utils/app_colors.dart';
import 'package:medico/main.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_check_service.dart';
import 'location_block_screen.dart';
import '../../config/api.dart';

class CareSeekerLocation extends StatefulWidget {
  final int userId;
  const CareSeekerLocation({super.key, required this.userId});
  @override
  State<CareSeekerLocation> createState() => _CareSeekerLocationState();
}

class _CareSeekerLocationState extends State<CareSeekerLocation> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();
  final areaController = TextEditingController();
  final landmarkController = TextEditingController();
  final pincodeController = TextEditingController();
  final stateController = TextEditingController();
  final mapController = MapController();

  LatLng selectedLocation = const LatLng(13.0827, 80.2707);
  bool loadingLocation = false, saving = false;
  List<dynamic> addresses = [];

  // ✅ NEW: tracks which address card is currently being confirmed (shows a
  // small inline spinner on that specific card instead of a separate FAB).
  int? _confirmingAddressId;

  bool get isDark => themeNotifier.value == ThemeMode.dark;
  void _onThemeChange() { if (mounted) setState(() {}); }

  void showToast(String msg, {ToastType type = ToastType.error}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ToastWidget(message: msg, type: type, onDismiss: () => entry.remove()));
    overlay.insert(entry);
  }

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChange);
    _loadAddressesThenAutoDetect();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChange);
    for (final c in [nameController, mobileController, addressController, areaController, landmarkController, pincodeController, stateController]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAddressesThenAutoDetect() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/addresses/${widget.userId}"));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() => addresses = list);
        if (list.isEmpty) { await Future.delayed(const Duration(milliseconds: 500)); if (mounted) await detectLocation(silent: true); }
      }
    } catch (_) {}
  }

  Future<void> fetchAddresses() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/addresses/${widget.userId}"));
      if (res.statusCode == 200) setState(() => addresses = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) { showToast("Please turn on device location/GPS", type: ToastType.warning); return false; }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) { showToast("Location permission denied.", type: ToastType.warning); return false; }
    if (perm == LocationPermission.deniedForever) { showToast("Opening app settings.", type: ToastType.warning); await Geolocator.openAppSettings(); return false; }
    return true;
  }

  Future<void> detectLocation({bool silent = false}) async {
    setState(() => loadingLocation = true);
    final ok = await _ensurePermission();
    if (!ok) { setState(() => loadingLocation = false); return; }
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => selectedLocation = LatLng(pos.latitude, pos.longitude));
      mapController.move(selectedLocation, 17);
      await _fillAddress();
      if (!silent) showToast("Location detected successfully", type: ToastType.success);
    } catch (_) { showToast("Could not detect location.", type: ToastType.error); }
    setState(() => loadingLocation = false);
  }

  Future<void> _fillAddress() async {
    try {
      final marks = await placemarkFromCoordinates(selectedLocation.latitude, selectedLocation.longitude);
      final p = marks.first;
      setState(() {
        addressController.text = p.street ?? p.thoroughfare ?? "";
        areaController.text = p.locality ?? p.subLocality ?? "";
        pincodeController.text = p.postalCode ?? "";
        stateController.text = p.administrativeArea ?? "";
      });
    } catch (_) {}
  }

  Future<void> saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final res = await http.post(Uri.parse("${Api.baseUrl}/addresses/save"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId, "name": nameController.text.trim(), "mobile": mobileController.text.trim(),
          "address_line": addressController.text.trim(), "area": areaController.text.trim(),
          "landmark": landmarkController.text.trim(), "pincode": pincodeController.text.trim(),
          "state": stateController.text.trim(), "latitude": selectedLocation.latitude, "longitude": selectedLocation.longitude,
        }));
    setState(() => saving = false);
    if (res.statusCode == 200 || res.statusCode == 201) {
      showToast("Address saved successfully", type: ToastType.success);
      await fetchAddresses(); _clearForm();
    } else {
      showToast("Failed to save address", type: ToastType.error);
    }
  }

  void _clearForm() {
    for (final c in [nameController, mobileController, addressController, areaController, landmarkController, pincodeController, stateController]) {
      c.clear();
    }
  }

  Future<void> deleteAddress(int id) async {
    await http.delete(Uri.parse("${Api.baseUrl}/addresses/delete/$id"));
    fetchAddresses(); showToast("Address deleted", type: ToastType.info);
  }

  // ✅ NEW IDEA: one tap = select AND confirm. No separate "Confirm Address"
  // button anymore. Tapping a card immediately runs the location-eligibility
  // check, saves it as the active address, and closes the screen — with a
  // small inline spinner on that card so the user sees it's processing.
  Future<void> _selectAddress(dynamic a) async {
    if (_confirmingAddressId != null) return; // prevent double taps mid-flight
    setState(() => _confirmingAddressId = a["id"]);

    try {
      final allowed = await LocationCheckService.checkLocation(
          state: a["state"] ?? "", area: a["area"] ?? "", pincode: a["pincode"] ?? "");

      if (!mounted) return;

      if (!allowed) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LocationBlockScreen(userId: widget.userId)));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await http.post(Uri.parse("${Api.baseUrl}/addresses/set-default"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"user_id": widget.userId, "address_id": a["id"]}));
      await prefs.setInt("selected_address_id_${widget.userId}", a["id"]);
      await prefs.setString("user_location_${widget.userId}", "${a["address_line"]}, ${a["area"]}");
      await prefs.setDouble("user_lat_${widget.userId}", double.tryParse(a["latitude"].toString()) ?? 0.0);
      await prefs.setDouble("user_lng_${widget.userId}", double.tryParse(a["longitude"].toString()) ?? 0.0);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showToast("Could not select this address. Try again.", type: ToastType.error);
        setState(() => _confirmingAddressId = null);
      }
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool required = true, TextInputType? type, String? Function(String?)? validator}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c, keyboardType: type,
        maxLength: type == TextInputType.phone ? 10 : null,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        validator: validator ?? (required ? (v) => v!.trim().isEmpty ? "$label is required" : null : null),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey[600]),
          prefixIcon: Icon(icon, color: isDark ? Colors.grey.shade400 : Colors.grey[600]),
          filled: true, fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          counterText: "",
          suffixIcon: required ? const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.star, color: Colors.red, size: 14)) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    );

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.grey[50]!;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      // ✅ FAB removed — selection now happens directly on tap of an address
      // card, so a separate "Confirm" action would just be a redundant step.
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 24),
          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Select Service Address", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            GestureDetector(onTap: () => Navigator.pop(context),
                child: const CircleAvatar(backgroundColor: Colors.white, radius: 20,
                    child: Icon(Icons.close, color: Colors.black87, size: 22))),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 240,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(initialCenter: selectedLocation, initialZoom: 15,
                    onTap: (_, latlng) { setState(() => selectedLocation = latlng); _fillAddress(); }),
                children: [
                  TileLayer(urlTemplate: "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.yourapp.care'),
                  MarkerLayer(markers: [Marker(point: selectedLocation, width: 50, height: 50,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 50))]),
                ],
              ),
            )),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2400) : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: const Row(children: [
                Icon(Icons.bolt_rounded, color: Color(0xFFF9A825), size: 20), SizedBox(width: 8),
                Expanded(child: Text("⚡ Use Auto Detect for faster & accurate address filling.",
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF7A5900), fontWeight: FontWeight.w500))),
              ]),
            ),

            const SizedBox(height: 12),

            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: loadingLocation ? null : () => detectLocation(),
              icon: loadingLocation
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Icon(Icons.my_location, size: 22),
              label: Text(loadingLocation ? "Detecting Location..." : "Auto Detect My Location",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),

            const SizedBox(height: 28),
            Text("Add New Address", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),

            Form(key: _formKey, child: Column(children: [
              _field(nameController, "Full Name", Icons.person),
              _field(mobileController, "Mobile Number", Icons.phone, type: TextInputType.phone,
                  validator: (v) { if (v == null || v.trim().isEmpty) return "Mobile required"; if (v.trim().length != 10) return "Must be 10 digits"; return null; }),
              _field(addressController, "Street Address", Icons.location_on),
              _field(areaController, "Area / Locality", Icons.place),
              _field(landmarkController, "Landmark", Icons.landscape),
              _field(pincodeController, "Pincode", Icons.pin_drop, type: TextInputType.number),
              _field(stateController, "State", Icons.map),
            ])),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: saving ? null : saveAddress,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: saving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text("Save This Address", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            )),

            const SizedBox(height: 28),
            Text("Saved Addresses", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),

            // ✅ NEW: professional inline info banner explaining the one-tap
            // selection behaviour, replacing the old italic hint line.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Select the booking address you'd like to use by tapping it once. "
                    "It will be applied automatically — no extra confirmation needed.",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: addresses.length,
              itemBuilder: (_, i) {
                final a = addresses[i];
                final bool isConfirming = _confirmingAddressId == a["id"];
                final bool anyConfirming = _confirmingAddressId != null;
                return GestureDetector(
                  onTap: anyConfirming ? null : () => _selectAddress(a),
                  child: Opacity(
                    opacity: (anyConfirming && !isConfirming) ? 0.5 : 1,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isConfirming ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.08) : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isConfirming ? AppColors.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300), width: isConfirming ? 2.5 : 1),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Tap indicator: plain circle normally, spinner while this
                        // specific card is being confirmed.
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: isConfirming
                                ? CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)
                                : Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                          width: 2),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.location_on_rounded, color: isConfirming ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.grey[600]), size: 30),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(a["address_line"] ?? "", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor))),
                            if (isConfirming)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                                child: const Text("SELECTING...", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                              ),
                          ]),
                          const SizedBox(height: 4),
                          Text("${a["area"] ?? ""}, ${a["state"] ?? ""} • ${a["pincode"] ?? ""}",
                              style: TextStyle(color: subColor, fontSize: 14)),
                          if ((a["landmark"] ?? "").toString().isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 6),
                                child: Text("Landmark: ${a["landmark"]}", style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 13))),
                        ])),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: anyConfirming ? null : () => deleteAddress(a["id"]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }
}

// Toast system (same as before)
enum ToastType { success, error, warning, info }

class _ToastWidget extends StatefulWidget {
  final String message; final ToastType type; final VoidCallback onDismiss;
  const _ToastWidget({required this.message, required this.type, required this.onDismiss});
  @override State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async { if (!mounted) return; await _ctrl.reverse(); widget.onDismiss(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  _ToastStyle get _style {
    switch (widget.type) {
      case ToastType.success: return _ToastStyle(const Color(0xFF1B7A4A), const Color(0xFF34C97B), Icons.check_circle_rounded, "Success");
      case ToastType.error:   return _ToastStyle(const Color(0xFFC0392B), const Color(0xFFFF6B6B), Icons.cancel_rounded, "Error");
      case ToastType.warning: return _ToastStyle(const Color(0xFFB7600A), const Color(0xFFFFB347), Icons.warning_amber_rounded, "Warning");
      case ToastType.info:    return _ToastStyle(const Color(0xFF1A6FA8), const Color(0xFF4FC3F7), Icons.info_rounded, "Info");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14, left: 16, right: 16,
      child: SlideTransition(position: _slide, child: FadeTransition(opacity: _fade,
        child: Material(color: Colors.transparent, child: GestureDetector(onTap: _dismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: s.bg.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))]),
            child: Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(s.icon, color: s.accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(s.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(widget.message, style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13, height: 1.3)),
              ])),
              GestureDetector(onTap: _dismiss, child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.6), size: 18)),
            ]),
          ),
        )),
      )),
    );
  }
}

class _ToastStyle {
  final Color bg, accent; final IconData icon; final String label;
  const _ToastStyle(this.bg, this.accent, this.icon, this.label);
}