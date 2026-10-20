import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:arknights_story_app/downloads/native_service.dart';
import 'package:arknights_story_app/downloads/download_task.dart';

final resultFile = File('.dart_tool/native-smoke-result.json');
const script =
    'https://raw.githubusercontent.com/Kengxxiao/ArknightsGameData/master/zh_CN/gamedata/story/obt/guide/beg/0_welcome_to_guide.txt';
void report(Map<String, dynamic> value) =>
    resultFile.writeAsStringSync(jsonEncode(value));
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Native download smoke test'))),
    ),
  );
  try {
    await downloadService.init();
    await downloadService.startStory('smoke:welcome', '黑暗时代·上 · 下载验证', {
      script: '序章·上',
    });
    for (var i = 0; i < 300; i++) {
      final task = downloadService.taskFor('smoke:welcome')!;
      report({
        'phase': 'download',
        'state': task.state.name,
        'files': task.done,
        'total': task.urls.length,
        'bytes': task.bytes,
        'error': task.error,
      });
      if (task.state == DownloadState.failed) throw StateError(task.error!);
      if (task.state == DownloadState.complete) break;
      if (i == 299) throw StateError('Download timed out');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final host = await downloadService.playerHost();
    final beforeNetwork = host.remoteRequests;
    final loaded = Completer<bool>();
    InAppWebViewController? testController;
    runApp(
      MaterialApp(
        home: Scaffold(
          body: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(
                host
                    .page('index.html', script, title: 'Native smoke')
                    .toString(),
              ),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
            ),
            onLoadStop: (controller, _) async {
              testController = controller;
              if (loaded.isCompleted) return;
              for (var i = 0; i < 100; i++) {
                await Future<void>.delayed(const Duration(milliseconds: 500));
                final state = await controller.evaluateJavascript(
                  source:
                      "JSON.stringify({canvas:!!document.querySelector('canvas'),state:document.querySelector('#stage')?.dataset.state,heading:document.querySelector('#heading')?.textContent,status:document.querySelector('#status')?.textContent})",
                );
                report({'phase': 'player', 'result': state});
                if (state is String &&
                    state.contains('"canvas":true') &&
                    (state.contains('waiting_input') ||
                        state.contains('running') ||
                        state.contains('waiting_timer'))) {
                  loaded.complete(true);
                  return;
                }
                if (state is String && state.contains('剧情加载失败')) {
                  loaded.completeError(StateError(state));
                  return;
                }
              }
              loaded.completeError(StateError('Player timed out'));
            },
          ),
        ),
      ),
    );
    await loaded.future.timeout(const Duration(seconds: 90));
    if (host.remoteRequests != beforeNetwork) {
      throw StateError('Playback fetched uncached remote resources');
    }
    final screenshot = await testController?.takeScreenshot();
    if (screenshot != null) {
      await File('.dart_tool/native-player-smoke.png').writeAsBytes(screenshot);
    }
    report({
      'success': true,
      'offlinePlayback': true,
      'cachedRequests': host.cachedRequests,
      'files': downloadService.taskFor('smoke:welcome')!.done,
      'bytes': downloadService.taskFor('smoke:welcome')!.bytes,
    });
    await downloadService.shutdown();
    exit(0);
  } catch (e, st) {
    report({'success': false, 'error': '$e', 'stack': '$st'});
    exit(1);
  }
}
