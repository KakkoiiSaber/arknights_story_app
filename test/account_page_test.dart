import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/pages/account_page.dart';
import 'package:arknights_story_app/config/archive_style.dart';

void main() {
  setUpAll(() async {
    final sans = FontLoader('Archive Sans')
      ..addFont(rootBundle.load('lib/assets/fonts/NotoSansSC.ttf'));
    final condensed = FontLoader('Archive Condensed')
      ..addFont(rootBundle.load('lib/assets/fonts/BarlowCondensed-Medium.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([sans.load(), condensed.load(), icons.load()]);
  });
  for (final size in [
    const Size(844, 390),
    const Size(1280, 720),
    const Size(390, 844),
  ]) {
    testWidgets('account form fits $size and can switch register/reset', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ArchiveStyle.theme,
          home: RepaintBoundary(key: key, child: const AccountPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('同步阅读设置与进度'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width == 1280) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/account-login-preview.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final scroller = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('创建账户'),
        100,
        scrollable: scroller,
      );
      await tester.tap(find.text('创建账户'));
      await tester.pumpAndSettle();
      expect(find.text('确认密码'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('已有账户，返回登录'),
        100,
        scrollable: scroller,
      );
      await tester.tap(find.text('已有账户，返回登录'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('忘记密码'),
        100,
        scrollable: scroller,
      );
      await tester.tap(find.text('忘记密码'));
      await tester.pumpAndSettle();
      expect(find.text('密码'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
