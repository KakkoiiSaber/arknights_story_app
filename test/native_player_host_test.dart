import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/downloads/native_downloads.dart';
import 'package:arknights_story_app/story/native_player_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native host serves bundled PRTS and cached media with video range support',
    () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final directory = await Directory.systemTemp.createTemp(
        'arkstory-host-test-',
      );
      final store = NativeDownloads(
        directory,
        resolveManifest: (_) async => [],
      );
      await store.init();
      final host = NativePlayerHost(store);
      final client = HttpClient();
      try {
        await host.start();
        final page = await (await client.getUrl(
          host.base.resolve('index.html'),
        )).close();
        expect(page.headers.contentType?.mimeType, 'text/html');
        final html = await utf8.decoder.bind(page).join();
        expect(html, contains('id="stage"'));
        expect(html, contains('id="hud"'));
        expect(html, isNot(contains('id="fullscreen"')));
        const mediaURL = 'https://torappu.prts.wiki/assets/test.mp4';
        await store.fileFor(mediaURL).writeAsBytes(List.generate(10, (i) => i));
        final url = host.base
            .resolve('resource/file.mp4')
            .replace(queryParameters: {'url': mediaURL});
        final request = await client.getUrl(url);
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=2-5');
        final response = await request.close();
        expect(response.statusCode, 206);
        expect(response.headers.value('content-range'), 'bytes 2-5/10');
        expect(response.headers.contentType?.mimeType, 'video/mp4');
        expect(await response.expand((chunk) => chunk).toList(), [2, 3, 4, 5]);
        final missing = await (await client.getUrl(
          host.base.resolve('../index.html'),
        )).close();
        expect(missing.statusCode, 404);
        await missing.drain<void>();
      } finally {
        client.close(force: true);
        await host.close();
        await store.shutdown();
        await directory.delete(recursive: true);
        HttpOverrides.global = previousOverrides;
      }
    },
  );
}
