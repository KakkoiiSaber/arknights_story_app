import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arknights_story_app/downloads/native_downloads.dart';
import 'package:arknights_story_app/downloads/download_task.dart';

Future<void> until(bool Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (!check()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Download state timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory directory;
  late HttpServer server;
  late Map<String, int> requests;
  late NativeDownloads downloads;
  late String shared;
  late String slow;
  var fail = false;
  final failures = <String, int>{};
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'arkstory-download-test-',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = {};
    fail = false;
    failures.clear();
    shared = 'http://127.0.0.1:${server.port}/shared.png';
    slow = 'http://127.0.0.1:${server.port}/slow.mp3';
    server.listen((request) async {
      final path = request.uri.path;
      requests.update(path, (n) => n + 1, ifAbsent: () => 1);
      try {
        if (fail || failures.containsKey(path)) {
          request.response.statusCode = failures[path] ?? 404;
          await request.response.close();
          return;
        }
        if (path == '/slow.mp3') {
          request.response.contentLength = 80 * 8192;
          for (var i = 0; i < 80; i++) {
            request.response.add(List.filled(8192, i));
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 8));
          }
        } else {
          request.response.contentLength = 128;
          request.response.add(List.filled(128, 7));
        }
        await request.response.close();
      } catch (_) {
        /* Pause aborts the test HTTP connection. */
      }
    });
    downloads = NativeDownloads(
      directory,
      resolveManifest: (id) async => id == 'large' ? [shared, slow] : [shared],
    );
    await downloads.init();
  });
  tearDown(() async {
    await downloads.shutdown();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });
  test('pausing a preferred source never starts its fallback', () async {
    await downloads.shutdown();
    const original = 'https://torappu.prts.wiki/assets/audio/music/fixture.mp3';
    final base = 'http://127.0.0.1:${server.port}';
    downloads = NativeDownloads(
      directory,
      resolveManifest: (_) async => [original],
      sourceResolver: (_) => [
        Uri.parse('$base/slow.mp3'),
        Uri.parse('$base/prts.mp3'),
      ],
    );
    await downloads.init();
    await downloads.start('pause-source', 'Pause');
    await until(() => requests['/slow.mp3'] != null);
    await downloads.pause('pause-source');
    expect(downloads.taskFor('pause-source')?.state, DownloadState.paused);
    expect(requests['/prts.mp3'], isNull);
    expect(await downloads.fileFor(original).exists(), isFalse);
  });
  test(
    'preferred source success and fallback share one canonical cached file',
    () async {
      await downloads.shutdown();
      const original =
          'https://torappu.prts.wiki/assets/avg/images/fixture.png';
      final base = 'http://127.0.0.1:${server.port}';
      downloads = NativeDownloads(
        directory,
        resolveManifest: (_) async => [original],
        sourceResolver: (_) => [
          Uri.parse('$base/raw.png'),
          Uri.parse('$base/prts.png'),
        ],
      );
      await downloads.init();
      failures['/raw.png'] = 404;
      await downloads.start('fallback', 'Fallback');
      await until(
        () => downloads.taskFor('fallback')?.state == DownloadState.complete,
      );
      expect(requests['/raw.png'], 1);
      expect(requests['/prts.png'], 1);
      expect(await downloads.fileFor(original).length(), 128);
      await downloads.start('reuse', 'Reuse');
      await until(
        () => downloads.taskFor('reuse')?.state == DownloadState.complete,
      );
      expect(requests['/raw.png'], 1);
      expect(requests['/prts.png'], 1);
    },
  );

  test(
    'preferred success never requests fallback; all errors leave no completed file',
    () async {
      await downloads.shutdown();
      const original =
          'https://torappu.prts.wiki/assets/audio/sound/fixture.mp3';
      final base = 'http://127.0.0.1:${server.port}';
      downloads = NativeDownloads(
        directory,
        resolveManifest: (_) async => [original],
        sourceResolver: (_) => [
          Uri.parse('$base/raw.mp3'),
          Uri.parse('$base/prts.mp3'),
        ],
      );
      await downloads.init();
      await downloads.start('success', 'Success');
      await until(
        () => downloads.taskFor('success')?.state == DownloadState.complete,
      );
      expect(requests['/prts.mp3'], isNull);
      await downloads.remove('success');
      failures.addAll({'/raw.mp3': 503, '/prts.mp3': 404});
      await downloads.start('failed', 'Failed');
      await until(
        () => downloads.taskFor('failed')?.state == DownloadState.failed,
      );
      expect(await downloads.fileFor(original).exists(), isFalse);
      expect(
        await File('${downloads.fileFor(original).path}.part').exists(),
        isFalse,
      );
    },
  );
  test(
    'shared resources download once and survive deleting another chapter',
    () async {
      await downloads.start('one', 'First');
      await until(
        () => downloads.taskFor('one')?.state == DownloadState.complete,
      );
      await downloads.start('two', 'Second');
      await until(
        () => downloads.taskFor('two')?.state == DownloadState.complete,
      );
      expect(requests['/shared.png'], 1);
      expect(downloads.storedBytes, 128);
      await downloads.remove('one');
      expect(await downloads.fileFor(shared).exists(), isTrue);
      await downloads.remove('two');
      expect(downloads.storedBytes, 0);
      expect(await downloads.fileFor(shared).exists(), isFalse);
    },
  );
  test(
    'pause resumes missing files without duplicating a completed resource',
    () async {
      await downloads.start('large', 'Large chapter');
      await until(() => (downloads.taskFor('large')?.currentBytes ?? 0) > 0);
      await downloads.pause('large');
      expect(downloads.taskFor('large')!.state, DownloadState.paused);
      expect(await downloads.fileFor(shared).exists(), isTrue);
      expect(await downloads.fileFor(slow).exists(), isFalse);
      await downloads.start('large', 'Large chapter');
      await until(
        () => downloads.taskFor('large')?.state == DownloadState.complete,
      );
      expect(requests['/shared.png'], 1);
      expect(requests['/slow.mp3'], 2);
      expect(await downloads.fileFor(slow).length(), 80 * 8192);
      expect(downloads.taskFor('large')!.bytes, 128 + 80 * 8192);
    },
  );
  test('failed tasks persist across restart and can retry', () async {
    fail = true;
    await downloads.start('one', 'Persisted chapter');
    await until(() => downloads.taskFor('one')?.state == DownloadState.failed);
    expect(downloads.taskFor('one')!.error, contains('404'));
    await downloads.shutdown();
    downloads = NativeDownloads(
      directory,
      resolveManifest: (_) async =>
          throw StateError('Saved manifest should be reused'),
    );
    await downloads.init();
    expect(downloads.taskFor('one')!.title, 'Persisted chapter');
    fail = false;
    await downloads.start('one', 'Persisted chapter');
    await until(
      () => downloads.taskFor('one')?.state == DownloadState.complete,
    );
    expect(downloads.taskFor('one')!.error, isNull);
  });
  test(
    'deleting an active chapter stops its writer before collecting files',
    () async {
      await downloads.start('large', 'Remove while downloading');
      await until(() => (downloads.taskFor('large')?.currentBytes ?? 0) > 0);
      await downloads.remove('large');
      expect(downloads.tasks, isEmpty);
      expect(downloads.storedBytes, 0);
      expect(await downloads.assets.list().isEmpty, isTrue);
    },
  );
  test(
    'a whole story combines every section into one persistent deduplicated task',
    () async {
      await downloads.start('one', 'Legacy per-section download');
      await until(
        () => downloads.taskFor('one')?.state == DownloadState.complete,
      );
      await downloads.start(
        'story:example',
        'Whole story',
        scripts: ['one', 'large'],
        scriptTitles: {'one': 'Opening', 'large': 'Ending'},
      );
      await until(
        () =>
            downloads.taskFor('story:example')?.state == DownloadState.complete,
      );
      expect(downloads.tasks, hasLength(1));
      expect(downloads.tasks.single.scripts, ['one', 'large']);
      expect(downloads.tasks.single.urls, [shared, slow]);
      expect(downloads.tasks.single.manifestDone, 2);
      expect(requests['/shared.png'], 1);
      final restored = ChapterDownload.fromJson(
        downloads.tasks.single.toJson(),
      );
      expect(restored.scriptTitles['large'], 'Ending');
      expect(restored.scripts, ['one', 'large']);
    },
  );
}
