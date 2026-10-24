import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/settings/reader_settings.dart';
import 'package:arknights_story_app/account/reading_library.dart';
import 'package:arknights_story_app/components/story_chapter_entry.dart';
import 'package:arknights_story_app/pages/reading_history_page.dart';

void main() {
  late ReadingLibrary library;
  late ReaderSettings settings;
  setUp(() async {
    settings = ReaderSettings();
    library = ReadingLibrary(
      settings: settings,
      read: () async => null,
      write: (_) async {},
    );
    await library.init();
  });
  tearDown(() {
    library.dispose();
    settings.dispose();
  });
  testWidgets('chapter status menu does not open the player', (tester) async {
    var opened = false;
    bool? marked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryChapterEntry(
            name: '小节',
            description: '',
            onTap: () => opened = true,
            onMarkRead: (read) => marked = read,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('阅读状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记已读'));
    await tester.pumpAndSettle();
    expect(marked, true);
    expect(opened, false);
  });
  testWidgets(
    'bulk import prepares catalogs and updates progress without playback',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await library.switchAccount('manual-ui-test');

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingHistoryPage(
            library: library,
            sync: () async {},
            loadJson: (url) async {
              if (url.endsWith('ui_test.json')) {
                return {
                  'infoUnlockDatas': [
                    {'storyTxt': 'ui_test/a', 'storyName': '第一节'},
                    {'storyTxt': 'ui_test/b', 'storyName': '第二节'},
                  ],
                };
              }
              return {
                'ui_test': {'name': '测试故事'},
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试故事'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标记已读'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(library.completedFor('ui_test'), 2);
      expect(library.resume('ui_test'), isNull);
      expect(find.text('已读 2 / 2 节'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed catalog does not partially import selected stories', (
    tester,
  ) async {
    await library.switchAccount('manual-ui-failure-test');

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingHistoryPage(
          library: library,
          sync: () async {},
          loadJson: (url) async {
            if (url.endsWith('good.json')) {
              return {
                'infoUnlockDatas': [
                  {'storyTxt': 'ui_failure/a', 'storyName': 'A'},
                ],
              };
            }
            if (url.endsWith('bad.json')) return null;
            return {
              'good': {'name': '成功目录'},
              'bad': {'name': '失败目录'},
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择搜索结果'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记已读'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(library.chapter('ui_failure/a'), isNull);
    expect(find.textContaining('本次尚未修改记录'), findsOneWidget);
  });
}
