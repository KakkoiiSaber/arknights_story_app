import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/story/story_playlist.dart';

void main() {
  test(
    'review playlist preserves before/after order and skips unreadable rows',
    () {
      final playlist = StoryPlaylistEntry.fromReview([
        {
          'storyTxt': 'obt/guide/beg/0_welcome_to_guide.txt',
          'storyName': '序章·上',
          'avgTag': '幕间',
        },
        {'storyTxt': null, 'storyName': '未开放'},
        {'storyTxt': '  '},
        {
          'storyTxt': 'obt/main/level_01_beg',
          'storyCode': '0-1',
          'storyName': '坍塌',
          'avgTag': '行动前',
        },
        {
          'storyTxt': 'obt/main/level_01_end',
          'storyCode': '0-1',
          'storyName': '坍塌',
          'avgTag': '行动后',
        },
      ]);
      expect(playlist.length, 3);
      expect(playlist[0].title, '序章·上 · 幕间');
      expect(playlist[1].title, '0-1 · 坍塌 · 行动前');
      expect(playlist[2].scriptURL, endsWith('/obt/main/level_01_end.txt'));
      expect(playlist[1].toJson(), {
        'script': playlist[1].scriptURL,
        'title': playlist[1].title,
      });
    },
  );
  test('player receives archive name and synopsis for skip confirmation', () {
    final playlist = StoryPlaylistEntry.fromReview([
      {
        'storyTxt': 'obt/main/level_01_beg',
        'storyCode': '0-1',
        'storyName': '坍塌',
        'storyDesc': '章节简介',
      },
    ], archiveName: '序章');
    expect(playlist.single.toJson()['summary'], '章节简介');
    expect(playlist.single.toJson()['storyName'], '序章');
  });
}
