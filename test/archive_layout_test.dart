import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:arknights_story_app/components/story_entry.dart';
import 'package:arknights_story_app/components/story_chapter_entry.dart';
import 'package:arknights_story_app/components/story_dashboard.dart';
import 'package:arknights_story_app/config/archive_style.dart';

Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets(
    'square and banner retain full source proportions at equal heights',
    (tester) async {
      final square = MemoryImage((await tester.runAsync(() => png(64, 64)))!);
      final banner = MemoryImage((await tester.runAsync(() => png(192, 64)))!);
      await tester.pumpWidget(
        MaterialApp(
          theme: ArchiveStyle.theme,
          home: Scaffold(
            body: Wrap(
              children: [
                StoryEntry(
                  name: 'square',
                  kvImage: square,
                  titleImage: null,
                  onTap: () {},
                  height: 100,
                ),
                StoryEntry(
                  name: 'banner',
                  kvImage: banner,
                  titleImage: null,
                  onTap: () {},
                  height: 100,
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(
        () => Future.wait([
          precacheImage(square, tester.element(find.byType(StoryEntry).first)),
          precacheImage(banner, tester.element(find.byType(StoryEntry).last)),
        ]),
      );
      await tester.pumpAndSettle();
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, 2);
      expect(images.every((image) => image.fit == BoxFit.contain), isTrue);
      final sizes = tester.getSize(find.byType(StoryEntry).first);
      final wide = tester.getSize(find.byType(StoryEntry).last);
      expect(sizes.height, 100);
      expect(wide.height, 100);
      expect(sizes.width, closeTo(100, 0.1));
      expect(wide.width, closeTo(300, 0.1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('catalog fits a 320px portrait viewport without forced columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryDashboard(
            storyMetaTableFuture: Future.value({
              'main_0': {'name': '主线', 'type': 'MAIN_STORY'},
              'event': {'name': '活动', 'type': 'ACTIVITY_STORY'},
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final item in find.byType(StoryEntry).evaluate()) {
      final rect = tester.getRect(find.byWidget(item.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'chapter descriptions remain visible without cards or expansion',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: StoryChapterEntry(
                name: '月落',
                code: 'SR-ST-1',
                tag: '幕间',
                description: '这一章的完整介绍',
                last: true,
                onTap: () => opened = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('这一章的完整介绍'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(Card), findsNothing);
      await tester.tap(find.text('月落'));
      expect(opened, isTrue);
    },
  );
  testWidgets('D group numbers and separators survive category filtering', (
    tester,
  ) async {
    final table = {
      'main_0': {'name': '主线', 'type': 'MAIN_STORY'},
      'event': {'name': '活动', 'type': 'ACTIVITY_STORY'},
      'mini': {'name': '故事集', 'type': 'MINI_STORY'},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryDashboard(storyMetaTableFuture: Future.value(table)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ⅰ'), findsOneWidget);
    expect(find.text('Ⅱ'), findsOneWidget);
    expect(find.text('Ⅲ'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryDashboard(
            storyMetaTableFuture: Future.value(table),
            filter: StoryTypeFilter.activity,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ⅱ'), findsOneWidget);
    expect(find.text('Ⅰ'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
