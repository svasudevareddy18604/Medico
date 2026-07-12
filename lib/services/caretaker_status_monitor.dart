import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api.dart';
import '../main.dart' show navigatorKey; // 🔥 see Step 3 — add this to main.dart

/// 🔥 Lives for the entire time a caretaker is logged in.
/// Polls /caretaker/status periodically AND on every app-resume.
/// If admin blocks or rejects the caretaker while they're mid-session,
/// this force-logs them out to LoginPage from WHATEVER screen they're on —
/// no need to wrap every individual screen.
class CaretakerStatusMonitor with WidgetsBindingObserver {
  static final CaretakerStatusMonitor _instance = CaretakerStatusMonitor._();
  CaretakerStatusMonitor._();
  factory CaretakerStatusMonitor() => _instance;

  Timer? _timer;
  int? _userId;
  bool _handling = false;

  /// Call once, right after a care_taker's session is confirmed
  /// (splash screen restore, or immediately after login).
  void start(int userId) {
    if (_userId == userId && _timer != null) return; // already running
    stop(); // clear any previous instance first
    _userId = userId;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _check(); // also check immediately
  }

  /// Call on logout, so the monitor doesn't keep polling for a signed-out user.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _userId = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final userId = _userId;
    if (userId == null || _handling) return;

    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/caretaker/status/$userId"))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);

      bool truthy(dynamic v) => v == 1 || v == true || v == "1";

      final blocked = truthy(data["is_blocked"]);
      final deleted = truthy(data["is_deleted"]);
      final status  = (data["approval_status"] ?? "").toString().trim().toLowerCase();
      final allowReupload = truthy(data["allow_reupload"]);

      if (blocked || deleted) {
        await _forceLogout(
          blocked ? "Your account has been blocked by admin." : "Your account is no longer active.",
        );
        return;
      }

      // Only force out on rejection if there's nothing left for them to do here
      // (i.e. admin didn't leave the door open for re-upload).
      if (status == "rejected" && !allowReupload) {
        await _forceLogout("Your application has been rejected by admin.");
      }
    } catch (_) {
      // Network hiccup — ignore, next poll will retry. Never force-logout on a network error.
    }
  }

  Future<void> _forceLogout(String reason) async {
    _handling = true;
    stop();

    final nav = navigatorKey.currentState;
    if (nav == null) {
      _handling = false;
      return;
    }

    final p = await SharedPreferences.getInstance();
    await p.clear();

    nav.pushNamedAndRemoveUntil('/login', (route) => false);
    // If you don't use named routes, replace the line above with:
    // nav.pushAndRemoveUntil(
    //   MaterialPageRoute(builder: (_) => const LoginPage()),
    //   (route) => false,
    // );

    final ctx = nav.overlay?.context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.red.shade600),
      );
    }
    _handling = false;
  }
}