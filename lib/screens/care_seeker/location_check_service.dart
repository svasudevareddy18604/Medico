import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api.dart';

class LocationCheckService {
  static Future<bool> checkLocation({
    required String state,
    required String area,
    required String pincode,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("${Api.baseUrl}/location/check"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "state": state,
          "area": area,
          "pincode": pincode,
        }),
      );

      final data = jsonDecode(res.body);

      return data["allowed"] == true;
    } catch (e) {
      return true; // fail-safe allow
    }
  }
}