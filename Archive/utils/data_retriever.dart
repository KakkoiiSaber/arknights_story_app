// import '../config/config.dart';
import '../config/data_base.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class DataRetriever {
  static String get audioMapURL => DataBase.audioMapURL;
  static String get storyMapURL => DataBase.storyMapURL;
  static String get storyDataURL => DataBase.storyDataURL;

  static Future<dynamic> getAudioMap() => _getJsonFromURL(audioMapURL);
  static Future<dynamic> getStoryMap() => _getJsonFromURL(storyMapURL);

  static Future<Map<String, dynamic>?> _getJsonFromURL(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        debugPrint("HTTP ${res.statusCode} for $url");
        return null;
      }

      final text = utf8.decode(res.bodyBytes); // UTF-8 safe
      return jsonDecode(text);
    } catch (e) {
      debugPrint("Error fetching $url — $e");
      return null;
    }
  }

  static Future<String?> _getTextFromURL(String url) async {
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

// void main() async {
//   // final url = "https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata/master/cn/gamedata/story/activities/a001/level_a001_01_end.txt";
//   // final text = await DataRetriever._getTextFromURL(url);
//   // debugPrint("Text fetch result:\n$text");
//   final json = await DataRetriever.getStoryMap();

//   if (json == null) {
//     print("❌ Failed to load JSON");
//     return;
//   }

//   // // Get first key in map
//   // final firstKey = json.keys.first;
//   // final firstValue = json[firstKey][0]["intro"];

//   // print("✅ First entry key: $firstKey");
//   // print("✅ First entry value snippet: ${firstValue}");
//   final keys = json.keys;
//   for (var key in keys) {
//     debugPrint("Key: $key; name: ${json[key]["name"]}");
//   }
// }
