import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/config/story_catalog.dart';

void main() {
  final table = <String, Map>{
    'main_0': {'name': '黑暗时代·上', 'type': 'MAIN_STORY', 'startTime': '1970-01'},
    'main_17': {'name': '相变临界', 'type': 'MAIN_STORY', 'startTime': '1970-01'},
    'ordinary': {
      'name': '普通活动',
      'type': 'ACTIVITY_STORY',
      'startTime': '2026-08',
    },
    'mini': {'name': '故事集', 'type': 'MINI_STORY', 'startTime': '2025-01'},
    for (final id in collaborationStoryIds)
      id: {
        'name': id,
        'type': id == 'act13mini' ? 'MINI_STORY' : 'ACTIVITY_STORY',
        'startTime': '2026-09',
      },
  };

  test(
    'all, activity and mini exclude every collaboration including Luo Xiaohei',
    () {
      expect(storyCatalogIds(table, StoryTypeFilter.all).toSet(), {
        'main_0',
        'main_17',
        'ordinary',
        'mini',
      });
      expect(storyCatalogIds(table, StoryTypeFilter.activity), ['ordinary']);
      expect(storyCatalogIds(table, StoryTypeFilter.mini), ['mini']);
      expect(
        storyCatalogIds(table, StoryTypeFilter.collaboration).toSet(),
        collaborationStoryIds,
      );
    },
  );

  test('search respects category boundaries and trims input', () {
    expect(
      storyCatalogIds(table, StoryTypeFilter.all, query: 'act54side'),
      isEmpty,
    );
    expect(
      storyCatalogIds(
        table,
        StoryTypeFilter.collaboration,
        query: ' ACT54SIDE ',
      ),
      ['act54side'],
    );
    expect(storyCatalogIds(table, StoryTypeFilter.all, query: ' 普通 '), [
      'ordinary',
    ]);
  });

  test('main chapters sort numerically despite placeholder release dates', () {
    expect(storyCatalogIds(table, StoryTypeFilter.main), ['main_17', 'main_0']);
  });

  test(
    'explicit future collab metadata is recognized without a bundled theme',
    () {
      final future = {
        'new': {
          'name': '新联动',
          'isCollaboration': true,
          'type': 'ACTIVITY_STORY',
        },
      };
      expect(storyCatalogIds(future, StoryTypeFilter.all), isEmpty);
      expect(storyCatalogIds(future, StoryTypeFilter.collaboration), ['new']);
    },
  );
}
