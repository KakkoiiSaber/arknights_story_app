import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/downloads/story_resource_sources.dart';

void main() {
  test('equivalent arkdata routes precede the unchanged PRTS identity', () {
    const paths = {
      'avg/background/bg_cher_1.png': 'avg/backgrounds/bg_cher_1.png',
      'avg/images/cgitem_76_i16_3.png': 'avg/images/cgitem_76_i16_3.png',
      'audio/music/test.mp3': 'audio/sound_beta_2/music/test.mp3',
      'audio/sound/test.mp3': 'audio/sound_beta_2/sound/test.mp3',
    };
    for (final entry in paths.entries) {
      final original = Uri.parse(
        'https://torappu.prts.wiki/assets/${entry.key}',
      );
      expect(storyResourceSources(original), [
        Uri.parse(
          'https://raw.githubusercontent.com/akgcc/arkdata/main/assets/torappu/dynamicassets/${entry.value}',
        ),
        original,
      ]);
    }
  });
  test(
    'split portraits, mappings, signed and third-party URLs stay untouched',
    () {
      for (final url in [
        'https://torappu.prts.wiki/assets/avg/characters/amiya/face.png',
        'https://torappu.prts.wiki/assets/avg/character.json',
        'https://torappu.prts.wiki/assets/avg/images/test.png?signature=abc',
        'https://torappu.prts.wiki.example/assets/avg/images/test.png',
        'https://user@torappu.prts.wiki/assets/avg/images/test.png',
        'https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master/story.txt',
      ]) {
        final original = Uri.parse(url);
        expect(storyResourceSources(original), [original]);
      }
    },
  );
  test('asset filename escaping is retained without double encoding', () {
    final urls = storyResourceSources(
      Uri.parse('https://torappu.prts.wiki/assets/avg/images/a%20b%23c.png'),
    );
    expect(urls.first.pathSegments.last, 'a b#c.png');
    expect(urls.first.toString(), endsWith('/a%20b%23c.png'));
  });
}
