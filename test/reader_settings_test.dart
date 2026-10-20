import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/settings/reader_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty and invalid preferences keep readable bounded values', () {
    final settings = ReaderSettings();
    settings.apply({
      'doctorName': '  ',
      'fontScale': double.nan,
      'typingIntervalMs': 'fast',
    });
    expect(settings.toJson(), {
      'doctorName': '博士',
      'fontScale': 1.0,
      'typingIntervalMs': 40,
    });
    settings.apply({
      'doctorName': '  凯尔希  ',
      'fontScale': 30,
      'typingIntervalMs': -1,
    });
    expect(settings.doctorName, '凯尔希');
    expect(settings.fontScale, 1.4);
    expect(settings.typingIntervalMs, 0);
    settings.apply({'doctorName': List.filled(40, '😀').join()});
    expect(settings.doctorName.runes.length, 32);
  });

  test(
    'rapid edits persist the latest global values across restarts',
    () async {
      final root = await Directory.systemTemp.createTemp('arkstory-settings-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => root.path);
      try {
        final settings = ReaderSettings();
        await settings.init();
        await Future.wait([
          settings.update(name: '测试博士'),
          settings.update(scale: 1.3),
          settings.update(interval: 0),
        ]);
        final restored = ReaderSettings();
        await restored.init();
        expect(restored.toJson(), settings.toJson());
        expect(restored.doctorName, '测试博士');
        expect(restored.fontScale, 1.3);
        expect(restored.typingIntervalMs, 0);
        expect(settings.saveError, isNull);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await root.delete(recursive: true);
      }
    },
  );
}
