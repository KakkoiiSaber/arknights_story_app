import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/downloads/review_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late Directory root;
  late HttpServer server;
  late ReviewCache cache;
  late Map<String, dynamic> manifest;
  late Map<String, List<int>> bodies;
  late Map<String, int> hits;
  const catalog = 'https://example.com/catalog.json';
  const cover = 'https://example.com/cover.png';
  const background = 'https://example.com/background.png';
  late String base;
  bool failMetadata = false, slow = false, slowMetadata = false;
  Completer<void>? gate;

  Map<String, dynamic> resource(String path, String role) => {
    'sha256': sha256.convert(bodies[path]!).toString(),
    'bytes': bodies[path]!.length,
    'extension': role == 'metadata' ? '.json' : '.png',
    'sources': ['$base$path'],
    'roles': [role],
    'stories': ['fixture'],
  };
  Future<void> settled() async {
    for (var i = 0; i < 300; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (!cache.running) return;
    }
    fail('download did not settle');
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('arkstory-review-test-');
    hits = {};
    bodies = {
      '/meta': utf8.encode('{"name":"故事一"}'),
      '/cover': utf8.encode('original-cover'),
      '/background': utf8.encode('background'),
    };
    failMetadata = false;
    slow = false;
    slowMetadata = false;
    gate = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    manifest = {
      'version': 1,
      'revision': 'version-one',
      'resources': {
        catalog: resource('/meta', 'metadata'),
        cover: resource('/cover', 'cover'),
        background: resource('/background', 'background'),
      },
    };
    server.listen((request) async {
      final path = request.uri.path;
      hits[path] = (hits[path] ?? 0) + 1;
      try {
        if (path == '/manifest' || path == '/data/media.json') {
          request.response.write(jsonEncode(manifest));
        } else if (failMetadata && path == '/meta2') {
          request.response.statusCode = 503;
        } else if (path == '/bad') {
          request.response.add(utf8.encode('bad'));
        } else {
          final bytes = bodies[path]!;
          if ((slow && path == '/background') ||
              (slowMetadata && path == '/meta')) {
            request.response.bufferOutput = false;
            request.response.add(bytes.take(3).toList());
            await request.response.flush();
            await gate!.future;
            request.response.add(bytes.skip(3).toList());
          } else {
            request.response.add(bytes);
          }
        }
        await request.response.close();
      } catch (_) {
        /* Client cancellation is expected during pause/clear. */
      }
    });
    cache = ReviewCache(root, Uri.parse('$base/manifest'));
    await cache.init();
  });
  tearDown(() async {
    gate?.complete();
    await cache.close();
    await server.close(force: true);
    expect(
      root.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      true,
    );
    await root.delete(recursive: true);
  });

  test(
    'arkstory_data snapshots preserve relative detail paths and verify media',
    () async {
      await cache.close();
      cache = ReviewCache(root, Uri.parse('$base/data/media.json'));
      await cache.init();
      const index = '/data/zh_CN/index.json';
      const detail = '/data/zh_CN/stories/demo.json';
      const art = '/media/demo/cover.png';
      bodies[index] = utf8.encode(
        '{"stories":[{"detail":"stories/demo.json"}]}',
      );
      bodies[detail] = utf8.encode('{"kvImageId":"old-key"}');
      bodies[art] = [1, 2, 3];
      manifest = {
        'version': 1,
        'bundles': {},
        'resources': {
          'old-key': {
            'path': art.substring(1),
            'sha256': sha256.convert(bodies[art]!).toString(),
            'bytes': 3,
          },
        },
      };
      await cache.checkForUpdates();
      expect(cache.updateError, isNull);
      expect(hits[art], isNull);
      expect(
        await (await cache.ensure('$base$detail')).readAsBytes(),
        bodies[detail],
      );
      await cache.start('home');
      await settled();
      expect(
        await (await cache.ensure('$base$art')).readAsBytes(),
        bodies[art],
      );
      expect(hits[art], 1);
    },
  );

  test(
    'first catalog download reports bytes before catalog is installed',
    () async {
      slowMetadata = true;
      gate = Completer<void>();
      final update = cache.checkForUpdates();
      for (var i = 0; i < 100 && cache.catalogDownloadedBytes == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(cache.revision, isNull);
      expect(cache.checking, isTrue);
      expect(cache.catalogTotalBytes, bodies['/meta']!.length);
      expect(cache.catalogDownloadedBytes, 3);
      expect(cache.catalogProgress, greaterThan(0));
      expect(cache.catalogProgress, lessThan(1));
      gate!.complete();
      gate = null;
      await update;
      expect(cache.revision, 'version-one');
      expect(cache.checking, isFalse);
      await settled();
    },
  );

  test(
    'checking updates does not start a media batch; downloads require selection',
    () async {
      await cache.checkForUpdates();
      await settled();
      expect(cache.revision, 'version-one');
      expect(hits['/meta'], 1);
      expect(hits['/cover'], isNull);
      expect(hits['/background'], isNull);
      expect(cache.running, isFalse);
      await cache.start('home');
      expect(hits['/cover'], 1);
      await Future.wait([cache.ensure(background), cache.ensure(background)]);
      expect(hits['/background'], 1);
      expect(
        await (await cache.ensure(catalog)).readAsString(),
        contains('故事一'),
      );
    },
  );

  test(
    'same version reuses files and a new version downloads only changed resources',
    () async {
      await cache.checkForUpdates();
      await settled();
      await cache.start('home');
      await cache.checkForUpdates();
      await settled();
      expect(hits['/cover'], 1);
      bodies['/new-cover'] = utf8.encode('changed-cover');
      manifest['revision'] = 'version-two';
      (manifest['resources'] as Map)[cover] = resource('/new-cover', 'cover');
      await cache.checkForUpdates();
      await settled();
      expect(cache.revision, 'version-two');
      expect(hits['/meta'], 1);
      expect(hits['/cover'], 1);
      expect(hits['/new-cover'], isNull);
      await cache.start('home');
      expect(hits['/new-cover'], 1);
      expect(hits['/background'], isNull);
    },
  );

  test(
    'a failed catalog update preserves the old offline snapshot across restart',
    () async {
      await cache.checkForUpdates();
      await settled();
      bodies['/meta2'] = utf8.encode('{"name":"故事二"}');
      manifest['revision'] = 'version-two';
      (manifest['resources'] as Map)[catalog] = resource('/meta2', 'metadata');
      failMetadata = true;
      await cache.checkForUpdates();
      expect(cache.revision, 'version-one');
      expect(cache.updateError, isNotNull);
      await cache.close();
      cache = ReviewCache(root, Uri.parse('$base/offline'));
      await cache.init();
      expect(cache.revision, 'version-one');
      expect(
        await (await cache.ensure(catalog)).readAsString(),
        contains('故事一'),
      );
      expect(hits['/meta'], 1);
    },
  );

  test(
    'pause retains complete files and resume restarts incomplete files safely',
    () async {
      await cache.checkForUpdates();
      await settled();
      slow = true;
      gate = Completer<void>();
      final batch = cache.start('all');
      for (var i = 0; i < 200 && hits['/background'] == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await cache.pause();
      await batch;
      expect(cache.state, 'paused');
      slow = false;
      gate!.complete();
      gate = null;
      await cache.start('all');
      expect(cache.state, 'complete');
      expect(hits['/cover'], 1);
      expect(hits['/background'], 2);
      expect(
        await (await cache.ensure(background)).readAsBytes(),
        bodies['/background'],
      );
    },
  );

  test(
    'checksum failures never replace valid files and fallback sources are verified',
    () async {
      final bg = (manifest['resources'] as Map)[background] as Map;
      bg['sources'] = ['$base/bad', '$base/background'];
      await cache.checkForUpdates();
      await settled();
      final file = await cache.ensure(background);
      expect(await file.readAsBytes(), bodies['/background']);
      expect(hits['/bad'], 1);
      await cache.close();
      await file.writeAsBytes(List.filled(bodies['/background']!.length, 0));
      cache = ReviewCache(root, Uri.parse('$base/manifest'));
      await cache.init();
      expect(
        await (await cache.ensure(background)).readAsBytes(),
        bodies['/background'],
      );
      expect(hits['/background'], 2);
    },
  );

  test(
    'clear removes media but preserves the catalog and unrelated story downloads',
    () async {
      await cache.checkForUpdates();
      await settled();
      await cache.ensure(background);
      final sentinel = File('${root.path}/story-sentinel');
      await sentinel.writeAsString('keep');
      await cache.clear();
      expect(await cache.fileFor(cache.resources[cover]!).exists(), false);
      expect(await cache.fileFor(cache.resources[background]!).exists(), false);
      expect(
        await (await cache.ensure(catalog)).readAsString(),
        contains('故事一'),
      );
      expect(await sentinel.readAsString(), 'keep');
      expect(cache.state, 'paused');
    },
  );
  test(
    'restart removes incomplete and obsolete files while retaining current media',
    () async {
      await cache.checkForUpdates();
      await settled();
      await cache.start('home');
      final original = cache.fileFor(cache.resources[cover]!);
      await cache.close();
      final orphan = File(
        '${cache.files.path}/${List.filled(64, 'a').join()}.png',
      );
      final part = File(
        '${cache.fileFor(cache.resources[background]!).path}.part',
      );
      await orphan.writeAsString('old');
      await part.writeAsString('unfinished');
      cache = ReviewCache(root, Uri.parse('$base/manifest'));
      await cache.init();
      expect(await orphan.exists(), false);
      expect(await part.exists(), false);
      expect(await original.exists(), true);
      expect(
        cache.storedBytes,
        bodies['/meta']!.length + bodies['/cover']!.length,
      );
    },
  );
}
