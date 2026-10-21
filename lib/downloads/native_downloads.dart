import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'download_task.dart';
import 'story_resource_sources.dart';

typedef ManifestResolver = Future<List<String>> Function(String id);

/// Downloads stay in app support storage, never the OS's disposable cache.
/// A single writer makes pause/delete and shared-file collection deterministic.
class NativeDownloads extends ChangeNotifier {
  NativeDownloads(
    this.root, {
    required this.resolveManifest,
    this.cancelManifest,
    HttpClient? client,
    StorySourceResolver? sourceResolver,
  }) : _client = client ?? HttpClient(),
       _sourceResolver = sourceResolver ?? storyResourceSources;
  final StorySourceResolver _sourceResolver;
  List<Uri> sourcesFor(String url) => _sourceResolver(Uri.parse(url));
  final Directory root;
  final ManifestResolver resolveManifest;
  final VoidCallback? cancelManifest;
  final HttpClient _client;
  final List<ChapterDownload> tasks = [];
  Future<void>? _working;
  Future<void> _commands = Future.value();
  Future<void> _writes = Future.value();
  ChapterDownload? _active;
  HttpClientRequest? _request;
  bool _interrupted = false;
  bool _closed = false;
  int storedBytes = 0;
  String? storageError;
  File get _index => File('${root.path}/chapters.json');
  Directory get assets => Directory('${root.path}/resources');
  File fileFor(String url) =>
      File('${assets.path}/${sha256.convert(utf8.encode(url))}');
  ChapterDownload? taskFor(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> init() async {
    await assets.create(recursive: true);
    if (await _index.exists()) {
      final values = jsonDecode(await _index.readAsString()) as List;
      tasks.addAll(
        values.map(
          (v) => ChapterDownload.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
      for (final task in tasks) {
        if (task.active) task.state = DownloadState.paused;
      }
    }
    await _measure();
    await _save();
  }

  Future<void> _save() async {
    final snapshot = jsonEncode(tasks.map((t) => t.toJson()).toList());
    final write = _writes.catchError((Object _) {}).then((_) async {
      final tmp = File('${_index.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      await tmp.rename(_index.path);
    });
    _writes = write;
    await write;
    notifyListeners();
  }

  Future<void> _measure() async {
    var measuredBytes = 0;
    await for (final file in assets.list()) {
      if (file is File) measuredBytes += await file.length();
    }
    storedBytes = measuredBytes;
  }

  Future<void> _serial(Future<void> Function() operation) {
    final result = _commands.then((_) => operation());
    _commands = result.catchError((Object error) {
      storageError = '$error';
      notifyListeners();
    });
    return result;
  }

  Future<void> start(
    String id,
    String title, {
    List<String>? scripts,
    Map<String, String>? scriptTitles,
  }) => _serial(() async {
    var task = taskFor(id);
    if (task != null && (task.active || task.state == DownloadState.complete)) {
      return;
    }
    task ??= ChapterDownload(
      id: id,
      title: title,
      scripts: scripts,
      scriptTitles: scriptTitles,
    );
    if (scripts != null) {
      // Fold tasks from the earlier per-section UI into this story. Keep their
      // downloaded files and manifests, so this migration loses no progress.
      final legacy = tasks
          .where((t) => t.id != id && scripts.contains(t.id))
          .toList();
      if (legacy.contains(_active)) {
        _closed = true;
        _interrupted = true;
        _request?.abort();
        cancelManifest?.call();
        await _working;
        _closed = false;
      }
      task.urls = {...task.urls, ...legacy.expand((t) => t.urls)}.toList();
      tasks.removeWhere(legacy.contains);
    }
    if (!tasks.contains(task)) tasks.add(task);
    task.state = DownloadState.queued;
    task.error = null;
    await _save();
    _pump();
  });
  Future<void> pause(String id) => _serial(() async {
    final task = taskFor(id);
    if (task == null || !task.active) return;
    task.state = DownloadState.paused;
    if (_active == task) {
      _interrupted = true;
      _request?.abort();
      cancelManifest?.call();
      notifyListeners();
      await _working;
    }
    await _measure();
    await _save();
  });
  Future<void> remove(String id) => _serial(() async {
    final wasActive = _active;
    _closed = true;
    _interrupted = true;
    _request?.abort();
    cancelManifest?.call();
    await _working;
    tasks.removeWhere((t) => t.id == id);
    final keep = tasks
        .expand((t) => t.urls)
        .map((url) => fileFor(url).uri.pathSegments.last)
        .toSet();
    await for (final file in assets.list()) {
      if (file is! File) continue;
      final fullPath = file.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.part$'),
        '',
      );
      // Only individual hashed files inside this store are collected.
      if (!keep.contains(fullPath)) await file.delete();
    }
    if (wasActive != null &&
        wasActive.id != id &&
        wasActive.state != DownloadState.complete) {
      wasActive.state = DownloadState.queued;
    }
    _closed = false;
    await _measure();
    await _save();
    _pump();
  });
  void _pump() {
    if (_working != null || _closed) return;
    final queued = tasks.where((t) => t.state == DownloadState.queued);
    if (queued.isEmpty) return;
    _active = queued.first;
    _interrupted = false;
    _working = _run(_active!)
        .catchError((Object e) {
          storageError = '$e';
          notifyListeners();
        })
        .whenComplete(() {
          _active = null;
          _working = null;
          _pump();
        });
  }

  void _check() {
    if (_interrupted || _closed) throw const _Paused();
  }

  Future<void> _run(ChapterDownload task) async {
    try {
      if (task.manifestDone < task.scripts.length) {
        task.state = DownloadState.preparing;
        await _save();
        for (var i = task.manifestDone; i < task.scripts.length; i++) {
          _check();
          final urls = await resolveManifest(
            task.scripts[i],
          ).timeout(const Duration(seconds: 100));
          _check();
          task.urls = {...task.urls, ...urls}.toList();
          task.manifestDone = i + 1;
          await _save();
        }
        if (task.urls.isEmpty) throw StateError('未找到章节资源');
      }
      _check();
      task.state = DownloadState.downloading;
      task.done = 0;
      task.bytes = 0;
      await _save();
      for (final url in task.urls) {
        _check();
        final file = fileFor(url);
        if (!await file.exists()) await _download(url, file, task);
        _check();
        task.done++;
        task.bytes += await file.length();
        task.currentBytes = 0;
        task.currentTotal = null;
        await _measure();
        await _save();
      }
      task.state = DownloadState.complete;
    } catch (error) {
      task.state = _interrupted || error is _Paused
          ? DownloadState.paused
          : DownloadState.failed;
      task.error = task.state == DownloadState.failed ? '$error' : null;
    } finally {
      _request = null;
      task.currentBytes = 0;
      task.currentTotal = null;
      await _measure();
      await _save();
    }
  }

  Future<void> _download(
    String url,
    File destination,
    ChapterDownload task,
  ) async {
    Object? failure;
    for (final uri in sourcesFor(url)) {
      _check();
      task.currentBytes = 0;
      task.currentTotal = null;
      notifyListeners();
      try {
        await _downloadFrom(uri, destination, task);
        return;
      } catch (error) {
        _request?.abort();
        _check(); // Pause/cancel must not start another source.
        failure = error;
      } finally {
        _request = null;
        final part = File('${destination.path}.part');
        if (await part.exists()) await part.delete();
      }
    }
    throw failure ?? StateError('未找到可用资源来源');
  }

  Future<void> _downloadFrom(
    Uri uri,
    File destination,
    ChapterDownload task,
  ) async {
    if (uri.scheme != 'https' && !uri.isScheme('http')) {
      throw StateError('Unsupported resource URL');
    }
    _request = await _client
        .getUrl(uri)
        .timeout(Duration(seconds: isGitHubRaw(uri) ? 8 : 30));
    if (_interrupted || _closed) {
      _request!.abort();
      throw const _Paused();
    }
    _request!.headers.set(HttpHeaders.refererHeader, 'https://prts.wiki/');
    _request!.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    // Retain whole completed files on pause. An incomplete file is restarted,
    // avoiding corrupt concatenation when a CDN ignores Range or changes ETag.
    final response = await _request!.close().timeout(
      Duration(seconds: isGitHubRaw(uri) ? 12 : 60),
    );
    if (response.statusCode != 200) {
      await response.listen(null).cancel();
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final part = File('${destination.path}.part');
    final sink = part.openWrite();
    var count = 0;
    var report = DateTime.now();
    task.currentTotal = response.contentLength < 0
        ? null
        : response.contentLength;
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        _check();
        sink.add(chunk);
        count += chunk.length;
        if (DateTime.now().difference(report).inMilliseconds >= 200) {
          task.currentBytes = count;
          report = DateTime.now();
          notifyListeners();
        }
      }
      _check();
      await sink.flush();
      if (response.compressionState !=
              HttpClientResponseCompressionState.decompressed &&
          response.contentLength >= 0 &&
          count != response.contentLength) {
        throw StateError('资源未下载完整');
      }
    } finally {
      await sink.close();
    }
    await part.rename(destination.path);
  }

  Future<void> shutdown() async {
    _closed = true;
    _interrupted = true;
    _request?.abort();
    await _working;
    _client.close(force: true);
  }
}

class _Paused implements Exception {
  const _Paused();
}
