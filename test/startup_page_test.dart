import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/pages/startup_page.dart';

void main() {
  testWidgets(
    'paints while initialization is pending and opens archive afterward',
    (tester) async {
      final ready = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPage(
            initialize: (status) async {
              status('正在检查本地资源');
              await ready.future;
            },
            childBuilder: (_) => const Text('故事库'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('正在检查本地资源'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('故事库'), findsNothing);
      ready.complete();
      await tester.pump();
      expect(find.text('故事库'), findsOneWidget);
    },
  );

  testWidgets(
    'shows initialization failure and retries without restarting app',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPage(
            initialize: (status) async {
              status('正在准备故事主题');
              if (++attempts == 1) throw StateError('storage unavailable');
            },
            childBuilder: (_) => const Text('故事库'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('正在准备故事主题失败'), findsOneWidget);
      await tester.tap(find.text('重试启动'));
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('故事库'), findsOneWidget);
    },
  );
}
