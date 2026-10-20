import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/config/config.dart';
import 'package:arknights_story_app/config/database.dart';
import 'package:arknights_story_app/config/story_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Config.server = 'zh_CN';
    await StoryThemes.load();
  });

  test(
    'all eight collaboration entries have usable theme data and provenance',
    () async {
      final raw =
          jsonDecode(
                await rootBundle.loadString(
                  'lib/assets/data/story_themes.json',
                ),
              )
              as Map;
      expect(raw.keys.toSet(), {
        'act17d0',
        'act24side',
        'act32side',
        'act36side',
        'act45side',
        'act13mini',
        'act50side',
        'act54side',
      });
      for (final id in raw.keys.cast<String>()) {
        final theme = StoryThemes.forStory(id)!;
        expect(theme.name, isNotEmpty);
        expect(theme.backgroundUrls, isNotEmpty);
        expect(raw[id]['sources'], isNotEmpty);
        for (final url in [
          theme.coverUrl,
          theme.titleUrl,
          ...theme.backgroundUrls,
          if (theme.musicIntroUrl != null) theme.musicIntroUrl!,
          if (theme.musicLoopUrl != null) theme.musicLoopUrl!,
        ]) {
          final uri = Uri.parse(url);
          expect(uri.scheme, 'https', reason: id);
          expect(uri.host, isNotEmpty, reason: id);
          // '#' in game filenames must reach the host, never become a fragment.
          expect(uri.fragment, isEmpty, reason: id);
        }
        expect(theme.coverContainsTitle, isTrue);
      }
    },
  );

  test(
    'special sources are explicitly described, not mistaken for original menu music',
    () {
      expect(StoryThemes.forStory('act13mini')!.musicRole, 'none');
      expect(StoryThemes.forStory('act13mini')!.musicLoopUrl, isNull);
      expect(StoryThemes.forStory('act13mini')!.hasReviewMusic, isFalse);
      final hunter = StoryThemes.forStory('act24side')!;
      expect(hunter.backgroundUrls.length, 2);
      expect(hunter.backgroundAspectRatio, closeTo(1560 / 960, 0.001));
      expect(
        StoryThemes.forStory('act32side')!.musicLoopUrl,
        startsWith('https://torappu.prts.wiki/'),
      );
    },
  );

  test('ordinary stories and other locales retain their existing metadata', () {
    expect(StoryThemes.forStory('main_0'), isNull);
    Config.server = 'en_US';
    expect(StoryThemes.forStory('act17d0'), isNull);
  });

  test(
    'silent themes retain their artwork and legacy story music is rejected',
    () {
      final theme = StoryThemes.forStory(
        'act13mini',
        metadata: {
          'name': '好久不见',
          'kvImageId': 'https://example.com/card.png',
          'titleImageId': 'https://example.com/title.png',
          'backgroundId': 'https://example.com/bg.png',
          'audio': {'intro': null, 'loop': null},
          'musicRole': 'none',
        },
      )!;
      expect(theme.coverUrl, 'https://example.com/card.png');
      expect(theme.backgroundUrls.single, 'https://example.com/bg.png');
      expect(theme.hasReviewMusic, isFalse);
      final legacy = StoryThemes.forStory(
        'act13mini',
        metadata: {
          'name': '好久不见',
          'kvImageId': 'https://example.com/card.png',
          'titleImageId': 'https://example.com/title.png',
          'backgroundId': 'https://example.com/bg.png',
          'audio': {
            'intro': null,
            'loop': 'https://example.com/first-story.mp3',
          },
          'musicRole': 'opening-story',
        },
      )!;
      expect(legacy.hasReviewMusic, isFalse);
    },
  );

  test(
    'published complement metadata takes precedence over bundled fallback',
    () {
      final theme = StoryThemes.forStory(
        'act45side',
        metadata: {
          'name': '无忧梦呓',
          'kvImageId': 'https://example.com/official-card.png',
          'titleImageId': 'https://example.com/logo.png',
          'backgroundId': 'storybg_ave_mujica.png',
          'audio': {'intro': null, 'loop': 'https://example.com/music.mp3'},
          'coverContainsTitle': true,
        },
      )!;
      expect(theme.coverUrl, 'https://example.com/official-card.png');
      expect(
        theme.backgroundUrls.single,
        '${Database.backgroundPath}storybg_ave_mujica.png',
      );
      expect(theme.musicLoopUrl, 'https://example.com/music.mp3');
      expect(
        StoryThemes.forStory('act45side', metadata: {'kvImageId': null}),
        isNotNull,
      );
    },
  );

  test(
    'legacy filenames and complete URLs both resolve without duplicate prefixes',
    () {
      expect(
        Database.reviewAssetURL(Database.kvImagePath, 'kv_example.png'),
        '${Database.kvImagePath}kv_example.png',
      );
      const full =
          'https://raw.githubusercontent.com/example/repo/main/title%231.png';
      expect(Database.reviewAssetURL(Database.titleImagePath, full), full);
    },
  );
}
