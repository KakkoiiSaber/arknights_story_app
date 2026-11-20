import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../downloads/review_service.dart';

import '../config/database.dart';
import '../config/story_themes.dart';

class DataRetriever {
  static final _pending = <String, Future<dynamic>>{};
  static Future<dynamic> _shared(String url) => _pending.putIfAbsent(
    url,
    () => _raw(url).whenComplete(() {
      _pending.remove(url);
    }),
  );

  static Map? _media;
  static String? _mediaRevision;

  static Future<Map?> _mediaResources({required bool refresh}) async {
    final revision = reviewAssets.revision;
    if (!refresh && _media != null && _mediaRevision == revision) return _media;
    final document = await _shared(Database.reviewManifestURL);
    final resources = document?['resources'];
    if (resources is! Map) return null;
    _mediaRevision = revision;
    return _media = resources;
  }

  static Future<dynamic> getJsonFromURL(String url) async {
    final index =
        url == Database.storyMetaTablePath || url == Database.gameMusicDataPath;
    if (!index && !url.startsWith(Database.reviewInfoPath)) return _raw(url);
    final documents = await Future.wait([
      _shared(index ? Database.storyMetaTablePath : url),
      _mediaResources(refresh: index),
    ]);
    final data = documents[0], media = documents[1];
    if (data is! Map || media is! Map) return null;
    String? asset(dynamic key) {
      final path = media[key]?['path'];
      return path is String
          ? Uri.parse(Database.reviewDataURL).resolve(path).toString()
          : null;
    }

    Map? track(dynamic audio) => audio is Map
        ? {
            ...audio,
            'intro': asset(audio['intro']),
            'loop': asset(audio['loop']),
          }
        : null;
    if (url == Database.gameMusicDataPath)
      return {'sys.ON_MUSIC.bg_void': track(data['homeMusic'])};
    Map normalize(Map item) => {
      ...item,
      'arkstoryData': true,
      for (final field in ['kvImageId', 'titleImageId', 'backgroundId'])
        field: asset(item[field]),
      if (item['backgroundUrls'] is List)
        'backgroundUrls': (item['backgroundUrls'] as List)
            .map(asset)
            .whereType<String>()
            .toList(),
      'audio': track(item['audio']),
    };
    if (!index) return normalize(data);
    final table = <String, Map>{};
    for (final card in data['stories'] as List) {
      final id = card['id'] as String;
      Database.detailPaths['$url:$id'] = Uri.parse(
        url,
      ).resolve(card['detail'] as String).toString();
      final cover = card['kvImageId'];
      table[id] = normalize({
        ...card,
        if (card['coverContainsTitle'] == null && cover is String)
          'coverContainsTitle': StoryThemes.isBrandedCover(id, cover),
        if (card['titleImageId'] == null &&
            cover is String &&
            cover.startsWith('kv_'))
          'titleImageId': 'title_${cover.substring(3)}',
      });
    }
    return table;
  }

  static Future<dynamic> _raw(String url) async {
    try {
      final bundled = await reviewAssets.json(url);
      if (bundled != null) return bundled;
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 25));
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
