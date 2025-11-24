// import '../config/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class DataRetriever {

  static Future<dynamic> getJsonFromURL(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint("HTTP ${response.statusCode} for $url");
        return null;
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint("Error fetching $url — $e");
      return null;
    }
  }

  static Future<String?> getTextFromURL(String url) async {
    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) return null;

      return utf8.decode(res.bodyBytes);
    } catch (e) {
      debugPrint("Text fetch error: $e");
      return null;
    }
  }
}
