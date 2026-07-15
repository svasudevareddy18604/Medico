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
import '../care_seeker/my_bookings_screen.dart';
import '../care_seeker/my_complaints_screen.dart';
import 'package:medico/config/api.dart';
import 'package:medico/main.dart';
import 'package:medico/utils/app_colors.dart';
import '../../utils/localization/settings_strings.dart';

// NOTE: Add `screen_protector: ^1.4.0` (or latest) to pubspec.yaml for the
// Screen Security toggle to actually block screenshots/recording.
// If you don't want the dependency yet, you can safely remove the
// ScreenProtector calls in _toggleScreenSecurity() below — the rest of the
// screen will still compile and the toggle will just persist a preference.
import 'package:screen_protector/screen_protector.dart';

/// Supported in-app languages. Extend this list as you add more locales.
/// NOTE: This screen only stores the user's choice (SharedPreferences +
/// `localeNotifier`). To make the whole app actually switch language you
/// need a `ValueNotifier<Locale> localeNotifier` in main.dart (mirroring
/// the existing `themeNotifier` pattern) and a `locale: localeNotifier.value`
/// wired into your MaterialApp with `ValueListenableBuilder`, plus the
/// corresponding .arb / localization delegates.
const Map<String, String> kSupportedLanguages = {
  "en": "English",
  "te": "తెలుగు",
  "hi": "हिन्दी",
  "kn": "ಕನ್ನಡ",
  "ta": "தமிழ்",
};

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

  String _languageCode = "en";
  bool _screenSecurityEnabled = false;
  bool _changingPassword = false;

  static const String _appVersion = "1.0.0";
  static const String _appBuild = "1";

  @override
  void initState() {
    super.initState();
    _isDarkMode = themeNotifier.value == ThemeMode.dark;
    _loadPreferences();
    _loadProfile();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _languageCode = prefs.getString("app_language") ?? "en";
      _screenSecurityEnabled = prefs.getBool("screen_security") ?? false;
    });
    // Re-apply screenshot protection on launch if it was previously enabled.
    if (_screenSecurityEnabled) {
      _applyScreenSecurity(true);
    }
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
    CaretakerStatusMonitor().stop();
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
        CaretakerStatusMonitor().stop();
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

  // ── Language ──────────────────────────────────────────────────────────────

  Future<void> _setLanguage(String code) async {
    setState(() => _languageCode = code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("app_language", code);

    // If you've wired up a localeNotifier in main.dart (see the comment at
    // the top of this file), uncomment the line below:
    // localeNotifier.value = Locale(code);
  }

  void _showLanguageDialog() {
    String tempSelection = _languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Select Language"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: kSupportedLanguages.entries.map((entry) {
                final code = entry.key;
                final label = entry.value;
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: code,
                  groupValue: tempSelection,
                  activeColor: AppColors.secondary,
                  title: Text(code == "en" ? "$label (Default)" : label),
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() => tempSelection = val);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _setLanguage(tempSelection);
                },
                child: const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Screen security (screenshot protection) ─────────────────────────────

  Future<void> _applyScreenSecurity(bool enabled) async {
    try {
      if (enabled) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      debugPrint("SCREEN PROTECTOR ERROR: $e");
    }
  }

  Future<void> _toggleScreenSecurity(bool val) async {
    setState(() => _screenSecurityEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("screen_security", val);
    await _applyScreenSecurity(val);
  }

  // ── Change password ──────────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: !_changingPassword,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Change Password"),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    enabled: !_changingPassword,
                    decoration: InputDecoration(
                      labelText: "Current Password",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    enabled: !_changingPassword,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Required";
                      if (v.length < 6) return "Minimum 6 characters";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    enabled: !_changingPassword,
                    decoration: InputDecoration(
                      labelText: "Confirm New Password",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Required";
                      if (v != newPasswordController.text) return "Passwords do not match";
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _changingPassword ? null : () => Navigator.pop(dialogContext),
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
                onPressed: _changingPassword
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setDialogState(() => _changingPassword = true);
                        final success = await _changePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                        );
                        setDialogState(() => _changingPassword = false);
                        if (success && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Password updated successfully.")),
                            );
                          }
                        }
                      },
                child: _changingPassword
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Update"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calls the backend to change the password.
  /// Adjust the endpoint/payload to match your actual API contract.
  Future<bool> _changePassword(String currentPassword, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/users/change-password/${widget.userId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "current_password": currentPassword,
          "new_password": newPassword,
        }),
      );

      if (res.statusCode == 200) return true;

      String message = "Failed to update password. Please try again.";
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded["message"] != null) {
          message = decoded["message"].toString();
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } catch (e) {
      debugPrint("CHANGE PASSWORD ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Something went wrong. Check your connection.")),
        );
      }
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

 String get _firstName =>
    (_userData?["first_name"] ?? SettingsStrings.care(_languageCode)).toString();

String get _lastName =>
    (_userData?["last_name"] ?? SettingsStrings.seeker(_languageCode)).toString();

String get _email =>
    (_userData?["email"] ?? "").toString();

  String get _profileImageUrl {
    final raw = (_userData?["profile_image"] ?? "").toString().trim();
    if (raw.isEmpty) return "";
    if (raw.startsWith("http")) return raw;
    return "${Api.imageBase}/$raw";
  }

  String get _languageLabel => kSupportedLanguages[_languageCode] ?? "English";

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
            _section(SettingsStrings.account(_languageCode), isDark, [
              _tile(
  Icons.person_rounded,
  SettingsStrings.myProfile(_languageCode),
                  () => _go(ProfileScreen(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.calendar_month_rounded,
  "My Bookings",
                  () => _go(MyBookingsScreen(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.report_problem_rounded,
  "My Complaints",
                  () => _go(MyComplaintsScreen(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.location_on_rounded,
  SettingsStrings.savedAddresses(_languageCode),
                  () => _go(CareSeekerLocation(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.emergency_rounded,
  SettingsStrings.emergencyContact(_languageCode),
                  () => _go(EmergencyContactScreen(userId: widget.userId)), isDark),
            ]),
            _section(
  SettingsStrings.preferences(_languageCode),
  isDark,
  [
              _toggleTile(
  Icons.notifications_rounded,
  SettingsStrings.notifications(_languageCode),
  _notificationsEnabled,
                  (v) => setState(() => _notificationsEnabled = v), isDark),
              Divider(height: 1, color: AppColors.border),
            _toggleTile(
  _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
  SettingsStrings.darkMode(_languageCode),
  _isDarkMode,
  _toggleDarkMode,
  isDark,
),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.language_rounded,
  SettingsStrings.language(_languageCode),
  _showLanguageDialog,
  isDark,
  trailingLabel: _languageLabel,
),
            ]),
            _section(
  SettingsStrings.security(_languageCode),
  isDark,
  [
              _tile(
  Icons.lock_reset_rounded,
  SettingsStrings.changePassword(_languageCode),
  _showChangePasswordDialog,
  isDark,
),
              Divider(height: 1, color: AppColors.border),
             _toggleTile(
  Icons.security_rounded,
  SettingsStrings.screenSecurity(_languageCode),
                  _screenSecurityEnabled, _toggleScreenSecurity, isDark),
            ]),
          _section(SettingsStrings.support(_languageCode), isDark, [
             _tile(
  Icons.support_agent_rounded,
  SettingsStrings.liveChatSupport(_languageCode),
                  () => _go(LiveChatScreen(userId: widget.userId)), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.help_rounded,
  SettingsStrings.helpCenter(_languageCode),
                  () => _go(const HelpCenterScreen()), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.info_rounded,
  SettingsStrings.aboutApp(_languageCode),
                  () => _go(const AboutAppScreen()), isDark),
            ]),
            _section(SettingsStrings.legal(_languageCode), isDark, [
              _tile(
  Icons.privacy_tip_rounded,
  SettingsStrings.privacyPolicy(_languageCode),
                  () => _go(const PrivacyScreen()), isDark),
              Divider(height: 1, color: AppColors.border),
              _tile(
  Icons.description_rounded,
  SettingsStrings.termsConditions(_languageCode),
                  () => _go(const TermsConditionsScreen()), isDark),
            ]),
            _logoutCard(isDark),
            const SizedBox(height: 36),
            Row(children: [
              Expanded(child: Divider(color: isDark ? Colors.white12 : AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
               child: Text(
  SettingsStrings.advanced(_languageCode),
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
            _versionFooter(isDark),
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
      Text(
  SettingsStrings.settings(_languageCode),
  style: const TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.bold,
  ),
),
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

  Widget _tile(IconData icon, String title, VoidCallback onTap, bool isDark,
      {String? trailingLabel}) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: _iconBox(icon),
    title: Text(title,
        style: TextStyle(
          fontWeight: FontWeight.w500, fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        )),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      if (trailingLabel != null) ...[
        Text(trailingLabel,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white38 : AppColors.muted,
            )),
        const SizedBox(width: 6),
      ],
      Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: isDark ? Colors.white38 : AppColors.muted),
    ]),
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
      title: Text(
  SettingsStrings.logout(_languageCode),
  style: const TextStyle(
    color: AppColors.danger,
    fontWeight: FontWeight.bold,
    fontSize: 14,
  ),
),
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
              child: Text(
  SettingsStrings.dangerZone(_languageCode),
  style: const TextStyle(
    color: AppColors.danger,
    fontWeight: FontWeight.bold,
    fontSize: 11,
    letterSpacing: 1.4,
  ),
),
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
                  title: Text(
  SettingsStrings.deleteAccount(_languageCode),
  style: const TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: AppColors.danger,
  ),
),
                  subtitle: Text(
  SettingsStrings.dangerZoneSubtitle(_languageCode),

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

  Widget _versionFooter(bool isDark) => Center(
    child: Column(children: [
      Text(
        "Medico",
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: isDark ? Colors.white38 : AppColors.muted,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        "Version $_appVersion  •  Build $_appBuild",
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.3,
          color: isDark ? Colors.white24 : AppColors.muted,
        ),
      ),
    ]),
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