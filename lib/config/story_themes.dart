import 'dart:convert';

import 'package:flutter/services.dart';

import 'config.dart';
import 'database.dart';

/// Curated exceptions for events whose art is outside the normal mixstory set.
class StoryThemeAssets {
  StoryThemeAssets.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      coverUrl = json['coverUrl'] as String,
      titleUrl = json['titleUrl'] as String,
      backgroundUrls = List<String>.unmodifiable(
        (json['backgroundUrls'] as List).cast<String>(),
      ),
      backgroundAspectRatio =
          (json['backgroundAspectRatio'] as num?)?.toDouble() ?? 16 / 9,
      musicIntroUrl = json['musicIntroUrl'] as String?,
      musicLoopUrl = json['musicLoopUrl'] as String?,
      musicRole = json['musicRole'] as String,
      coverContainsTitle = json['coverContainsTitle'] as bool? ?? false,
      titleIsBanner = json['titleIsBanner'] as bool? ?? false;

  final String name;
  final String coverUrl;
  final String titleUrl;
  final List<String> backgroundUrls;
  final double backgroundAspectRatio;
  final String? musicIntroUrl;
  final String? musicLoopUrl;
  final String musicRole;
  bool get hasReviewMusic =>
      musicRole == 'activity-theme' && musicLoopUrl?.isNotEmpty == true;
  final bool coverContainsTitle;
  final bool titleIsBanner;
}

class StoryThemes {
  static Map<String, StoryThemeAssets> _themes = const {};

  static Future<void> load() async {
    final json =
        jsonDecode(
              await rootBundle.loadString('lib/assets/data/story_themes.json'),
            )
            as Map<String, dynamic>;
    _themes = Map.unmodifiable({
      for (final entry in json.entries)
        entry.key: StoryThemeAssets.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    });
  }

  // These wordmarks are Chinese; other locales retain their existing data.
  static StoryThemeAssets? forStory(String id, {Map? metadata}) {
    if (Config.server != 'zh_CN') return null;
    // The data repository's complement is authoritative once published. The
    // bundled copy keeps previews working before the data branch is published.
    if (metadata?['audio'] is Map && metadata?['kvImageId'] is String) {
      final audio = metadata!['audio'] as Map;
      final backgrounds = metadata['backgroundUrls'] as List?;
      final backgroundId = metadata['backgroundId'] as String?;
      final titleId = metadata['titleImageId'] as String?;
      if (titleId != null &&
          (backgrounds?.isNotEmpty == true || backgroundId != null)) {
        return StoryThemeAssets.fromJson({
          'name': metadata['name'],
          'coverUrl': Database.reviewAssetURL(
            Database.kvImagePath,
            metadata['kvImageId'] as String,
          ),
          'titleUrl': Database.reviewAssetURL(Database.titleImagePath, titleId),
          'backgroundUrls': [
            for (final path in backgrounds ?? [backgroundId])
              Database.reviewAssetURL(Database.backgroundPath, path as String),
          ],
          'backgroundAspectRatio': metadata['backgroundAspectRatio'],
          'musicIntroUrl': audio['intro'],
          'musicLoopUrl': audio['loop'],
          'musicRole': metadata['musicRole'] ?? 'activity-theme',
          'coverContainsTitle': metadata['coverContainsTitle'],
          'titleIsBanner': metadata['titleIsBanner'],
        });
      }
    }
    return _themes[id];
  }
}
