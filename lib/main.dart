import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:ui';
import 'dart:convert';

import 'login_page.dart';
import 'register_page.dart';
import 'splash_screen.dart';

/* ===============================
   🌗 THEME
================================ */
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));
final navigatorKey = GlobalKey<NavigatorState>(); // 🔥 ADD THIS LINE

/* ===============================
   🔔 NOTIFICATION INSTANCE
================================ */
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/* ===============================
   🔥 BACKGROUND HANDLER
================================ */
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔙 BACKGROUND: ${message.notification?.title}");
}

/* ===============================
   🚀 MAIN
================================ */
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await setupNotifications();

  final prefs = await SharedPreferences.getInstance();
  bool isDark = prefs.getBool("dark_mode") ?? false;

  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  String languageCode = prefs.getString("language_code") ?? "en";
  localeNotifier.value = Locale(languageCode);

  runApp(const MyApp());
}

/* ===============================
   🖼️ DOWNLOAD IMAGE FOR NOTIFICATION
================================ */
Future<String> _downloadAndSaveFile(String url, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();

  final filePath = '${directory.path}/$fileName';

  final response = await http.get(Uri.parse(url));

  final file = File(filePath);

  await file.writeAsBytes(response.bodyBytes);

  return filePath;
}

/* ===============================
   🔔 SETUP NOTIFICATIONS
================================ */
Future<void> setupNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ✅ Permission
  await messaging.requestPermission();

  // ✅ Get token (IMPORTANT DEBUG)
  String? token = await messaging.getToken();
  print("🔥 DEVICE TOKEN: $token");

  // ✅ Local notification init
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
  );

  // ✅ Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'medico_channel',
    'Medico Notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // ✅ FOREGROUND FIX (CRITICAL) — now with image support
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 FOREGROUND RECEIVED: ${message.notification?.title}");

    final notification = message.notification;

    if (notification == null) return;

    String? imageUrl;

    if (message.data["image"] != null &&
        message.data["image"].toString().isNotEmpty) {
      imageUrl = message.data["image"];
    } else {
      imageUrl = notification.android?.imageUrl;
    }

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final imagePath =
            await _downloadAndSaveFile(imageUrl, "notification.jpg");

        final bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          largeIcon: FilePathAndroidBitmap(imagePath),
          contentTitle: notification.title,
          summaryText: notification.body,
        );

        androidDetails = AndroidNotificationDetails(
          'medico_channel',
          'Medico Notifications',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigPictureStyle,
        );
      } catch (e) {
        print("❌ Image download failed: $e");

        androidDetails = const AndroidNotificationDetails(
          'medico_channel',
          'Medico Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'medico_channel',
        'Medico Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
    }

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails),
    );
  });

  // ✅ CLICK HANDLER
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("📲 Notification clicked");
  });
}

/* ===============================
   👤 USER TOKEN SETUP
================================ */
Future<void> setupFCMWithUser(int userId) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  String? token = await messaging.getToken();

  print("USER TOKEN: $token");

  if (token != null) {
    await sendTokenToBackend(userId, token);
  }

  messaging.onTokenRefresh.listen((newToken) async {
    print("🔄 REFRESH TOKEN: $newToken");
    await sendTokenToBackend(userId, newToken);
  });
}

/* ===============================
   🌐 SEND TOKEN TO BACKEND (FIXED)
================================ */
Future<void> sendTokenToBackend(int userId, String token) async {
  try {
    final url = Uri.parse("https://medico-3vyh.onrender.com/api/update-fcm-token");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "fcm_token": token,
      }),
    );

    print("✅ Token API response: ${res.statusCode}");
  } catch (e) {
    print("❌ Token send error: $e");
  }
}

/* ===============================
   🎨 THEMES
================================ */
ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
);

ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
);

/* ===============================
   APP
================================ */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode mode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, Locale locale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,

              locale: locale,

              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: mode,

              home: const SplashScreen(),

              routes: {
                '/login': (context) => const LoginPage(),
                '/register': (context) => const RegisterPage(),
              },
            );
          },
        );
      },
    );
  }
}