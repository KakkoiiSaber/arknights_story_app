import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/downloads/native_downloads.dart';
import 'package:arknights_story_app/story/native_player_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'online media falls back with Range and HEAD preserved, then reuses canonical cache',
    () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final directory = await Directory.systemTemp.createTemp(
        'arkstory-sources-test-',
      );
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final calls = <String>[];
      final originURL = 'http://127.0.0.1:${origin.port}';
      origin.listen((request) async {
        calls.add('${request.method} ${request.uri.path}');
        if (request.uri.path == '/raw.mp3') {
          request.response.statusCode = 404;
        } else {
          expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=2-5');
          request.response.statusCode = 206;
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.headers.set('content-range', 'bytes 2-5/10');
          request.response.contentLength = 4;
          if (request.method != 'HEAD') request.response.add([2, 3, 4, 5]);
        }
        await request.response.close();
      });
      final store = NativeDownloads(
        directory,
        resolveManifest: (_) async => [],
        sourceResolver: (_) => [
          Uri.parse('$originURL/raw.mp3'),
          Uri.parse('$originURL/prts.mp3'),
        ],
      );
      await store.init();
      final host = NativePlayerHost(store);
      final client = HttpClient();
      const canonical =
          'https://torappu.prts.wiki/assets/audio/music/fixture.mp3';
      try {
        await host.start();
        final url = host.base
            .resolve('resource/file.mp3')
            .replace(queryParameters: {'url': canonical});
        for (final method in ['GET', 'HEAD']) {
          final request = await client.openUrl(method, url);
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=2-5');
          final response = await request.close();
          expect(response.statusCode, 206);
          expect(response.headers.value('content-range'), 'bytes 2-5/10');
          expect(response.contentLength, 4);
          expect(
            await response.expand((chunk) => chunk).toList(),
            method == 'HEAD' ? [] : [2, 3, 4, 5],
          );
        }
        expect(calls, [
          'GET /raw.mp3',
          'GET /prts.mp3',
          'HEAD /raw.mp3',
          'HEAD /prts.mp3',
        ]);
        await store.fileFor(canonical).writeAsBytes([9, 8, 7]);
        final cached = await (await client.getUrl(url)).close();
        expect(await cached.expand((chunk) => chunk).toList(), [9, 8, 7]);
        expect(calls.length, 4);
      } finally {
        client.close(force: true);
        await host.close();
        await store.shutdown();
        await origin.close(force: true);
        await directory.delete(recursive: true);
        HttpOverrides.global = previousOverrides;
      }
    },
  );
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
