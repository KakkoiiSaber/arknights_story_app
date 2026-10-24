import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/pages/settings_page.dart';
import 'package:arknights_story_app/settings/reader_settings_panel.dart';

void main() {
  testWidgets(
    'settings follow both landscape safe areas and keep the end reachable',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('arkstory-safe-area-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => root.path,
      );
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        root.deleteSync(recursive: true);
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(852, 393);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      for (final left in [59.0, 0.0]) {
        final right = left == 0 ? 59.0 : 0.0;
        tester.view.padding = FakeViewPadding(
          left: left,
          right: right,
          bottom: 21,
        );
        tester.view.viewPadding = FakeViewPadding(
          left: left,
          right: right,
          bottom: 21,
        );
        await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
        await tester.pumpAndSettle();
        final list = find.byType(ListView).first;
        final rect = tester.getRect(list);
        expect(rect.left, greaterThanOrEqualTo(left));
        expect(rect.right, lessThanOrEqualTo(852 - right));
        expect(rect.bottom, lessThanOrEqualTo(393 - 21));
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byType(ReaderSettingsPanel),
          matching: find.byType(TextField),
        );
        await tester.scrollUntilVisible(
          field,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final input = tester.getRect(field);
        expect(input.left, greaterThanOrEqualTo(left + 24));
        expect(input.right, lessThanOrEqualTo(852 - right - 24));
        await tester.drag(list, const Offset(0, -2000));
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(position.pixels, position.maxScrollExtent);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
