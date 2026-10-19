import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/story/story_player.dart';
import 'package:arknights_story_app/story/story_player_view.dart';
import 'package:arknights_story_app/story/story_script.dart';

const script = '''
[Background(image="bg_cher_1")]
[Character(name="char_002_amiya_1#5")]
[name="阿米娅"] 博士，我们准备出发。罗德岛的各位正在等你。
[Background(image="bg_next")]
[Character(name="char_130_doberm_ex")]
[name="杜宾"] 各小组，准备行动！
[Decision(options="出发吧。;稍等一下。",values="1;2")]
[Predicate(references="1")]
[name="阿米娅"] 明白了。
[Predicate(references="2")]
[name="阿米娅"] 我会等你的，博士。
[Predicate]
行动开始。
''';

final previewImages = <String, MemoryImage>{};

Widget art(List<String> urls, BoxFit fit) {
  const directory = String.fromEnvironment('PLAYER_ART_DIR');
  if (directory.isNotEmpty && urls.isNotEmpty) {
    final filename = urls.first.contains('/characters/')
        ? 'amiya.png'
        : 'background.png';
    final provider = previewImages.putIfAbsent(
      filename,
      () => MemoryImage(File('$directory/$filename').readAsBytesSync()),
    );
    return Image(
      image: provider,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
    );
  }
  return ColoredBox(
    key: ValueKey(urls.isEmpty ? 'missing-art' : urls.first),
    color: fit == BoxFit.cover ? const Color(0xff31434b) : Colors.transparent,
  );
}

Widget app(StoryPlayer player) => MaterialApp(
  theme: ThemeData(
    brightness: Brightness.dark,
    fontFamily: const String.fromEnvironment('PLAYER_FONT').isEmpty
        ? null
        : 'StoryQA',
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('capture-player'),
      child: StoryPlayerView(
        player: player,
        title: '0-1 · 罗德岛 · 行动前',
        artBuilder: art,
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    const fontPath = String.fromEnvironment('PLAYER_FONT');
    if (fontPath.isNotEmpty) {
      final font = FontLoader('StoryQA')
        ..addFont(
          File(
            fontPath,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
    }
    const iconPath = String.fromEnvironment('PLAYER_ICON_FONT');
    if (iconPath.isNotEmpty) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            iconPath,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await icons.load();
    }
  });
  testWidgets(
    'tap and keyboard advance, choices block, restart resets the scene',
    (tester) async {
      final player = StoryPlayer(const StoryScriptParser().parse(script));
      await tester.pumpWidget(app(player));
      expect(find.text('阿米娅'), findsOneWidget);
      expect(find.byKey(const ValueKey('character-m')), findsOneWidget);
      await tester.tapAt(const Offset(400, 200));
      await tester.pump();
      expect(find.text('杜宾'), findsOneWidget);
      expect(player.background, 'bg_next');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('选择回应'), findsOneWidget);
      await tester.tapAt(const Offset(400, 200));
      await tester.pump();
      expect(find.text('选择回应'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choice-1')));
      await tester.pump();
      expect(find.text('我会等你的，博士。'), findsOneWidget);
      expect(find.text('明白了。'), findsNothing);
      await tester.tapAt(const Offset(400, 200));
      await tester.pump();
      expect(find.text('行动开始。'), findsOneWidget);
      await tester.tapAt(const Offset(400, 200));
      await tester.pump();
      expect(find.text('本节故事结束'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restart-story')));
      await tester.pump();
      expect(player.background, 'bg_cher_1');
      expect(find.text('阿米娅'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(1280, 720),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('fits ${size.width}x${size.height} with readable dialogue', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final player = StoryPlayer(const StoryScriptParser().parse(script));
      await tester.pumpWidget(app(player));
      if (previewImages.isNotEmpty) {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(StoryPlayerView));
          for (final provider in previewImages.values.toList()) {
            await precacheImage(provider, context);
          }
        });
      }
      await tester.pumpAndSettle();
      expect(find.text('点击继续  ▸'), findsOneWidget);
      expect(tester.takeException(), isNull);
      const output = String.fromEnvironment('PLAYER_SCREENSHOT_DIR');
      if (output.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture-player')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/player-${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
