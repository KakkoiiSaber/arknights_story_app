import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import '../story/native_player_host.dart';
import 'download_task.dart';
import 'native_downloads.dart';

final downloadService = AppDownloads();

class AppDownloads extends ChangeNotifier {
  Future<void>? _initializing;
  NativeDownloads? _store;
  NativePlayerHost? _host;
  Future<NativePlayerHost>? _hosting;
  Completer<List<String>>? _manifest;
  HeadlessInAppWebView? _manifestView;
  InAppWebViewController? _manifestController;
  String? _manifestScript;
  String? _error;
  bool get supported =>
      Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isIOS ||
      Platform.isAndroid;
  List<ChapterDownload> get tasks => _store?.tasks ?? const [];
  int get storedBytes => _store?.storedBytes ?? 0;
  String? get error => _error ?? _store?.storageError;
  ChapterDownload? taskFor(String id) => _store?.taskFor(id);
  Future<void> init() => _initializing ??= _init();
  Future<void> _init() async {
    try {
      final root = await getApplicationSupportDirectory();
      final store = NativeDownloads(
        Directory('${root.path}/chapter-downloads'),
        resolveManifest: _resolveManifest,
        cancelManifest: () {
          final pending = _manifest;
          if (pending != null && !pending.isCompleted) {
            pending.completeError(StateError('下载已暂停'));
          }
        },
      );
      await store.init();
      _store = store;
      store.addListener(notifyListeners);
      notifyListeners();
    } catch (e) {
      _error = '下载存储初始化失败：$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<NativePlayerHost> playerHost() => _hosting ??= _startHost();
  Future<NativePlayerHost> _startHost() async {
    await init();
    final host = NativePlayerHost(_store!);
    await host.start();
    _host = host;
    return host;
  }

  Future<List<String>> _resolveManifest(String id) async {
    final host = await playerHost();
    final result = Completer<List<String>>();
    _manifest = result;
    _manifestScript = id;
    final pending = result.future.timeout(const Duration(seconds: 95));
    pending.ignore();
    // Reuse the parsing view across sections. Disposing a Windows headless
    // WebView inside its own JS bridge callback can free active native state.
    final view = _manifestView ??= HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(host.page('manifest.html', id).toString()),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
      ),
      shouldOverrideUrlLoading: (_, action) async =>
          action.request.url?.origin == host.base.origin
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL,
      onWebViewCreated: (controller) {
        _manifestController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'chapterManifest',
          callback: (args) {
            final result = _manifest;
            if (result == null ||
                result.isCompleted ||
                args.isEmpty ||
                args.first is! Map) {
              return;
            }
            final value = args.first as Map;
            if (value['script'] != _manifestScript) {
              return;
            }
            if (value['error'] != null) {
              result.completeError(StateError('${value['error']}'));
            } else {
              result.complete(List<String>.from(value['urls'] as List));
            }
          },
        );
      },
    );
    try {
      if (!view.isRunning()) {
        await view.run();
      } else {
        await _manifestController!.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(host.page('manifest.html', id).toString()),
          ),
        );
      }
      return await pending;
    } finally {
      _manifest = null;
      _manifestScript = null;
    }
  }

  Future<void> start(String id, String title) async {
    await init();
    await _store!.start(id, title);
  }

  Future<void> startStory(
    String id,
    String title,
    Map<String, String> chapters,
  ) async {
    await init();
    await _store!.start(
      id,
      title,
      scripts: chapters.keys.toList(),
      scriptTitles: chapters,
    );
  }

  Future<void> pause(String id) async {
    await init();
    await _store!.pause(id);
  }

  Future<void> remove(String id) async {
    await init();
    await _store!.remove(id);
  }

  Future<void> shutdown() async {
    await _store?.shutdown();
    await _host?.close();
  }
}
