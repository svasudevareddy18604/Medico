import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medico/services/caretaker_status_monitor.dart';
import '../care_seeker/profile_screen.dart';
import '../care_seeker/about_app_screen.dart';
import '../care_seeker/privacy_screen.dart';
import '../care_seeker/terms_conditions.dart';
import '../care_seeker/helpcenter_screen.dart';
import '../care_seeker/livechat_screen.dart';
import '../care_seeker/careseeker_location.dart';
import '../care_seeker/emergency_contact_screen.dart';
import 'package:medico/config/api.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;
  const SettingsScreen({super.key, required this.userId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;
  bool _loading = true;
  bool _deletingAccount = false;
  bool _dangerZoneExpanded = false;
  Map<String, dynamic>? _userData;

  static const String _appVersion = "1.0.0"; // ✅ NEW: bump manually per release

  @override
  void initState() {
    super.initState();
    _isDarkMode = themeNotifier.value == ThemeMode.dark;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await http.get(Uri.parse("${Api.baseUrl}/users/profile/${widget.userId}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { _userData = data; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("PROFILE ERROR: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDarkMode(bool val) async {
    setState(() => _isDarkMode = val);
    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("dark_mode", val);
  }

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _logout() async {
  CaretakerStatusMonitor().stop(); // 🔥 ADD THIS LINE
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (!mounted) return;
  Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
}

  void _confirmLogout() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Logout"),
      content: const Text("You will be logged out. Continue?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel", style: TextStyle(color: AppColors.muted)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.gradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
            ),
            onPressed: () { Navigator.pop(context); _logout(); },
            child: const Text("Logout"),
          ),
        ),
      ],
    ),
  );

  // ── Delete account ───────────────────────────────────────────────────────

  Future<void> _deleteAccount() async {
    setState(() => _deletingAccount = true);
    try {
      final res = await http.delete(
        Uri.parse("${Api.baseUrl}/users/delete-account/${widget.userId}"),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
  CaretakerStatusMonitor().stop(); // 🔥 ADD THIS LINE
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (!mounted) return;
  Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
} else {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete account. Please try again.")),
        );
      }
    } catch (e) {
      debugPrint("DELETE ACCOUNT ERROR: $e");
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Check your connection.")),
      );
    }
  }

  void _confirmDeleteAccount() {
    final TextEditingController controller = TextEditingController();
    bool canDelete = false;

    showDialog(
      context: context,
      barrierDismissible: !_deletingAccount,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Account"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This will permanently delete your account and all associated data. "
                "This action cannot be undone.",
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                  children: [
                    const TextSpan(text: "Type "),
                    TextSpan(
                      text: "DELETE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const TextSpan(text: " below to confirm."),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                enabled: !_deletingAccount,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  hintText: "DELETE",
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (val) {
                  setDialogState(() => canDelete = val.trim() == "DELETE");
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _deletingAccount ? null : () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(color: AppColors.muted)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: canDelete ? AppColors.danger : AppColors.danger.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  disabledForegroundColor: Colors.white70,
                ),
                onPressed: (_deletingAccount || !canDelete)
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _deleteAccount();
                      },
                child: _deletingAccount
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Delete"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _firstName => (_userData?["first_name"] ?? "Care").toString();
  String get _lastName  => (_userData?["last_name"]  ?? "Seeker").toString();
  String get _email     => (_userData?["email"]      ?? "").toString();

  String get _profileImageUrl {
    final raw = (_userData?["profile_image"] ?? "").toString().trim();
    if (raw.isEmpty) return "";
    if (raw.startsWith("http")) return raw;
    return "${Api.imageBase}/$raw";
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppColors.lightBg,
      body: Column(children: [
        _header(),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            _profileCard(isDark),
            const SizedBox(height: 22),
            _section("ACCOUNT", isDark, [
              _tile(Icons.person_rounded, "My Profile",
                  () => _go(ProfileScreen(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(Icons.location_on_rounded, "Saved Addresses",
                  () => _go(CareSeekerLocation(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(Icons.emergency_rounded, "Emergency Contact",
                  () => _go(EmergencyContactScreen(userId: widget.userId)), isDark),
            ]),
            _section("PREFERENCES", isDark, [
              _toggleTile(Icons.notifications_rounded, "Notifications",
                  _notificationsEnabled,
                  (v) => setState(() => _notificationsEnabled = v), isDark),
              Divider(height: 1, color: AppColors.border),
              _toggleTile(
                  _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  "Dark Mode", _isDarkMode, _toggleDarkMode, isDark),
            ]),
            _section("SUPPORT", isDark, [
              _tile(Icons.support_agent_rounded, "Live Chat Support",
                  () => _go(LiveChatScreen(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(Icons.help_rounded, "Help Center",
                  () => _go(const HelpCenterScreen()), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(Icons.info_rounded, "About App",
                  () => _go(const AboutAppScreen()), isDark),
            ]),
            _section("LEGAL", isDark, [
              _tile(Icons.privacy_tip_rounded, "Privacy Policy",
                  () => _go(const PrivacyScreen()), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(Icons.description_rounded, "Terms & Conditions",
                  () => _go(const TermsConditionsScreen()), isDark),
            ]),
            _logoutCard(isDark),
            const SizedBox(height: 36),
            Row(children: [
              Expanded(child: Divider(color: isDark ? Colors.white12 : AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("ADVANCED",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white24 : AppColors.muted,
                    )),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white12 : AppColors.border)),
            ]),
            const SizedBox(height: 14),
            _dangerZone(isDark),
            const SizedBox(height: 28),
            _versionFooter(isDark), // ✅ NEW
          ],
        )),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() => Container(
    width: double.infinity,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 18,
      left: 20, right: 20, bottom: 30,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
      ),
      const SizedBox(width: 14),
      const Text("Settings",
          style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
    ]),
  );

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _profileCard(bool isDark) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppColors.glowShadow,
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => _go(ProfileScreen(userId: widget.userId)),
        child: Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: ClipOval(child: _buildAvatar()),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _loading
            ? Container(
                height: 18, width: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(8)))
            : Text("$_firstName $_lastName",
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _loading
            ? Container(
                height: 13, width: 160, margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(6)))
            : Text(_email.isNotEmpty ? _email : "Manage your account settings",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis),
      ])),
      GestureDetector(
        onTap: () => _go(ProfileScreen(userId: widget.userId)),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
        ),
      ),
    ]),
  );

  Widget _buildAvatar() {
    if (_loading) {
      return Container(
        color: Colors.white.withOpacity(0.20),
        child: const Center(
          child: SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
      );
    }

    final url = _profileImageUrl;
    if (url.isEmpty) return _avatarFallback();

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              color: Colors.white.withOpacity(0.18),
              child: const Center(
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))),
      errorBuilder: (_, __, ___) => _avatarFallback(),
    );
  }

  Widget _avatarFallback() => Container(
    color: Colors.white.withOpacity(0.18),
    child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
  );

  // ── Section ───────────────────────────────────────────────────────────────

  Widget _section(String label, bool isDark, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      boxShadow: isDark ? [] : AppColors.cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: ShaderMask(
          shaderCallback: (b) => AppColors.gradient.createShader(b),
          child: Text(label,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.4)),
        ),
      ),
      Divider(height: 1, color: isDark ? Colors.white12 : AppColors.border),
      ...children,
    ]),
  );

  // ── Nav tile ──────────────────────────────────────────────────────────────

  Widget _tile(IconData icon, String title, VoidCallback onTap, bool isDark) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: _iconBox(icon),
    title: Text(title,
        style: TextStyle(
          fontWeight: FontWeight.w500, fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        )),
    trailing: Icon(Icons.arrow_forward_ios_rounded,
        size: 14, color: isDark ? Colors.white38 : AppColors.muted),
    onTap: onTap,
  );

  // ── Toggle tile ───────────────────────────────────────────────────────────

  Widget _toggleTile(IconData icon, String title, bool value,
      ValueChanged<bool> onChanged, bool isDark) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: _iconBox(icon),
    title: Text(title,
        style: TextStyle(
          fontWeight: FontWeight.w500, fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        )),
    trailing: Switch(
      value: value,
      activeColor: AppColors.secondary,
      activeTrackColor: AppColors.accent.withOpacity(0.35),
      inactiveThumbColor: AppColors.muted,
      inactiveTrackColor: isDark ? Colors.white12 : AppColors.border,
      onChanged: onChanged,
    ),
  );

  // ── Icon box ──────────────────────────────────────────────────────────────

  Widget _iconBox(IconData icon) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      gradient: AppColors.gradient,
      borderRadius: BorderRadius.circular(12),
      boxShadow: AppColors.glowShadow,
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );

  // ── Logout card ───────────────────────────────────────────────────────────

  Widget _logoutCard(bool isDark) => Container(
    decoration: BoxDecoration(
      color: AppColors.danger.withOpacity(isDark ? 0.10 : 0.06),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.danger.withOpacity(0.18)),
    ),
    child: ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
      ),
      title: Text("Logout",
          style: TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.danger.withOpacity(0.5)),
      onTap: _confirmLogout,
    ),
  );

  // ── Danger zone ───────────────────────────────────────────────────────────

  Widget _dangerZone(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : AppColors.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.danger.withOpacity(0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _dangerZoneExpanded = !_dangerZoneExpanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text("DANGER ZONE",
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  )),
            ),
            Text(_dangerZoneExpanded ? "Hide" : "Show",
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                )),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _dangerZoneExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.danger, size: 20),
            ),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: _dangerZoneExpanded
            ? Column(children: [
                Divider(height: 1, color: AppColors.danger.withOpacity(0.15)),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _deletingAccount
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.danger),
                          )
                        : Icon(Icons.delete_forever_rounded,
                            color: AppColors.danger, size: 20),
                  ),
                  title: Text("Delete Account",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.danger,
                      )),
                  subtitle: Text("Permanently remove your account and data",
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.muted)),
                  onTap: _deletingAccount ? null : _confirmDeleteAccount,
                ),
              ])
            : const SizedBox(width: double.infinity, height: 0),
      ),
    ]),
  );

  // ── Version footer ───────────────────────────────────────────────────────
  // ✅ NEW: simple centered app version, useful for support/debugging.

  Widget _versionFooter(bool isDark) => Center(
    child: Text(
      "Medico  •  v$_appVersion",
      style: TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white24 : AppColors.muted,
      ),
    ),
  );
}

/// Forces the confirmation text field to uppercase as the user types,
/// so "delete" / "Delete" / "DELETE" all resolve consistently.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}