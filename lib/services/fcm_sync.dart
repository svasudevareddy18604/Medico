import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/api.dart';

Future<void> syncFcmToken(int userId) async {
  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final res = await http.post(
      Uri.parse("${Api.baseUrl}/update-fcm-token"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_id": userId, "fcm_token": token}),
    );
    debugPrint("FCM sync status: ${res.statusCode} ${res.body}");
  } catch (e) {
    debugPrint("FCM sync failed: $e");
  }
}