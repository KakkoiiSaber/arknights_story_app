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
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'arkstory-download-test-',
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = {};
    fail = false;
    shared = 'http://127.0.0.1:${server.port}/shared.png';
    slow = 'http://127.0.0.1:${server.port}/slow.mp3';
    server.listen((request) async {
      final path = request.uri.path;
      requests.update(path, (n) => n + 1, ifAbsent: () => 1);
      try {
        if (fail) {
          request.response.statusCode = 404;
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
