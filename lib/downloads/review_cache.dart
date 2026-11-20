import '../config/config.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class ReviewResource {
  ReviewResource(this.url, Map data)
    : hash = data['sha256'] as String,
      bytes = (data['bytes'] as num).toInt(),
      extension = data['extension'] as String,
      sources = List<String>.from(data['sources'] as List),
      roles = List<String>.from(data['roles'] as List),
      stories = List<String>.from(data['stories'] as List),
      sirenSongId = data['sirenSongId'] as String? {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        bytes <= 0 ||
        !RegExp(
          r'^\.(json|png|webp|jpe?g|mp3|wav|ogg|m4a)$',
        ).hasMatch(extension) ||
        sources.isEmpty ||
        sources.any((s) => !['http', 'https'].contains(Uri.parse(s).scheme))) {
      throw const FormatException('Invalid review resource');
    }
  }
  final String url, hash, extension;
  final int bytes;
  final List<String> sources, roles, stories;
  final String? sirenSongId;
  String get key => '$hash$extension';
  bool get home => roles.any((r) => ['metadata', 'cover', 'logo'].contains(r));
}

class ReviewCache extends ChangeNotifier {
  ReviewCache(this.root, this.manifestURL, {HttpClient? client})
    : _client = client ?? HttpClient();
  final Directory root;
  final Uri manifestURL;
  final HttpClient _client;
  Map<String, ReviewResource> resources = {};
  String? revision, updateError, downloadError;
  bool checking = false, running = false, clearing = false;
  String? selection;
  String state = 'idle';
  int storedBytes = 0;
  final Set<String> _cached = {}, _verified = {};
  final Map<String, _ReviewJob> _jobs = {};
  final List<_ReviewJob> _queue = [];
  int _active = 0, _batchGeneration = 0;
  bool _closed = false;
  Future<void>? _updating;
  Map<String, ReviewResource> _catalogDownloads = {};
  int get catalogTotalBytes =>
      _catalogDownloads.values.fold(0, (sum, r) => sum + r.bytes);
  int get catalogDownloadedBytes => _catalogDownloads.values.fold(
    0,
    (sum, r) =>
        sum + (_cached.contains(r.key) ? r.bytes : (_jobs[r.key]?.loaded ?? 0)),
  );
  double? get catalogProgress => catalogTotalBytes == 0
      ? null
      : (catalogDownloadedBytes / catalogTotalBytes).clamp(0, 1);
  Future<void> _writes = Future.value();
  Directory get files => Directory('${root.path}/files');
  File get _manifestFile => File('${root.path}/manifest.json');
  File get _stateFile => File('${root.path}/state.json');
  File fileFor(ReviewResource resource) =>
      File('${files.path}/${resource.key}');
  Iterable<ReviewResource> get unique =>
      {for (final r in resources.values) r.key: r}.values;
  Iterable<ReviewResource> get selected =>
      unique.where((r) => selection == 'all' || r.home);
  int get totalBytes => unique.fold(0, (sum, r) => sum + r.bytes);
  int get selectedBytes => selected.fold(0, (sum, r) => sum + r.bytes);
  int get downloadedBytes => selected
      .where((r) => _cached.contains(r.key))
      .fold(0, (s, r) => s + r.bytes);
  int get completeCount =>
      selected.where((r) => _cached.contains(r.key)).length;
  int get currentBytes => _jobs.values
      .where((j) => selection == 'all' || j.resource.home)
      .fold(0, (s, j) => s + j.loaded);
  int get activeBytes => _jobs.values.fold(0, (sum, j) => sum + j.loaded);
  int get activeTotalBytes =>
      _jobs.values.fold(0, (sum, j) => sum + j.resource.bytes);
  double get progress => selectedBytes == 0
      ? 0
      : ((downloadedBytes + currentBytes) / selectedBytes).clamp(0, 1);

  Future<void> init() async {
    await files.create(recursive: true);
    try {
      _install(jsonDecode(await _manifestFile.readAsString()) as Map);
    } catch (_) {
      /* first launch */
    }
    try {
      final saved = jsonDecode(await _stateFile.readAsString()) as Map;
      selection = saved['selection'] as String?;
      state = saved['state'] == 'downloading'
          ? 'paused'
          : saved['state'] as String? ?? 'idle';
    } catch (_) {
      /* first launch */
    }
    // Startup runs before readers/downloads exist. Clean only generated files.
    final live = unique.map((r) => r.key).toSet();
    await for (final file in files.list()) {
      if (file is! File || file.parent.absolute.path != files.absolute.path) {
        continue;
      }
      final name = file.uri.pathSegments.last;
      if (RegExp(r'^[a-f0-9]{64}\.[a-z0-9]+\.part$').hasMatch(name) ||
          (revision != null &&
              RegExp(r'^[a-f0-9]{64}\.[a-z0-9]+$').hasMatch(name) &&
              !live.contains(name))) {
        await file.delete();
      }
    }
    await _scan();
  }

  Map<String, ReviewResource> _parse(Map data) {
    if (data['version'] != 1 ||
        data['revision'] is! String ||
        data['resources'] is! Map) {
      throw const FormatException('Unsupported review manifest');
    }
    return {
      for (final entry in (data['resources'] as Map).entries)
        entry.key as String: ReviewResource(
          entry.key as String,
          entry.value as Map,
        ),
    };
  }

  void _install(Map data) {
    resources = _parse(data);
    revision = data['revision'] as String;
  }

  Future<void> _scan() async {
    storedBytes = 0;
    _cached.clear();
    final expected = {for (final r in unique) r.key: r};
    await for (final file in files.list()) {
      if (file is! File) continue;
      final key = file.uri.pathSegments.last;
      final size = await file.length();
      storedBytes += size;
      if (expected[key]?.bytes == size) _cached.add(key);
    }
  }

  Future<void> checkForUpdates() =>
      _updating ??= _refresh().whenComplete(() => _updating = null);
  // Build the offline snapshot only on an explicit settings download/update.
  Future<Map> _archiveManifest(List<int> bytes, Map media) async {
    final records = <String, Map>{};
    final root = manifestURL.resolve('../');
    for (final record in (media['resources'] as Map).values) {
      final path = record['path'] as String;
      final url = root.resolve(path).toString();
      final name = path.split('/').last;
      records[url] = {
        ...record,
        'extension': name.substring(name.lastIndexOf('.')),
        'sources': [url],
        'stories': [],
        'roles': [
          name.startsWith('cover.')
              ? 'cover'
              : name.startsWith('title.')
              ? 'logo'
              : path.startsWith('media/home/')
              ? 'cover'
              : 'theme',
        ],
      };
    }
    Future<Map> saveJson(Uri uri, List<int> body) async {
      final doc = jsonDecode(utf8.decode(body)) as Map;
      final hash = sha256.convert(body).toString();
      final resource = {
        'sha256': hash,
        'bytes': body.length,
        'extension': '.json',
        'sources': [uri.toString()],
        'roles': ['metadata'],
        'stories': [],
      };
      final file = fileFor(ReviewResource(uri.toString(), resource));
      if (!await file.exists()) await _write(file, utf8.decode(body));
      records[uri.toString()] = resource;
      return doc;
    }

    Future<Map> fetchJson(Uri uri) async {
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('目录 HTTP ${response.statusCode}', uri: uri);
      }
      final body = await response
          .fold<List<int>>([], (list, chunk) => list..addAll(chunk))
          .timeout(const Duration(seconds: 30));
      return saveJson(uri, body);
    }

    await saveJson(manifestURL, bytes);
    final indexUri = manifestURL.resolve('${Config.server}/index.json');
    final index = await fetchJson(indexUri);
    final paths = (index['stories'] as List)
        .map((item) => indexUri.resolve(item['detail'] as String))
        .toList();
    var next = 0;
    Future<void> worker() async {
      while (next < paths.length) {
        await fetchJson(paths[next++]);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    final sorted = records.keys.toList()..sort();
    final revision = sha256.convert(
      utf8.encode(
        jsonEncode([
          for (final key in sorted) [key, records[key]!['sha256']],
        ]),
      ),
    );
    return {
      'version': 1,
      'revision': revision.toString(),
      'resources': records,
    };
  }

  Future<void> _refresh() async {
    checking = true;
    updateError = null;
    notifyListeners();
    try {
      final request = await _client
          .getUrl(manifestURL)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw HttpException('资源清单 HTTP ${response.statusCode}');
      }
      final bytes = await response
          .fold<List<int>>([], (all, chunk) {
            if (all.length + chunk.length > 12 * 1024 * 1024) {
              throw const FormatException('Manifest too large');
            }
            return all..addAll(chunk);
          })
          .timeout(const Duration(seconds: 25));
      final document = jsonDecode(utf8.decode(bytes)) as Map;
      final data = document.containsKey('bundles')
          ? await _archiveManifest(bytes, document)
          : document;
      final incoming = _parse(data);
      if (data['revision'] != revision) {
        // Stage the new catalog first; a failed update leaves the prior
        // manifest and its metadata usable together offline.
        _catalogDownloads = {
          for (final r in incoming.values.where(
            (r) => r.roles.contains('metadata'),
          ))
            r.key: r,
        };
        notifyListeners();
        await Future.wait(
          _catalogDownloads.values.map((r) => _ensureResource(r)),
        );
        final resume = running ? selection : null;
        await pause();
        await _write(_manifestFile, jsonEncode(data));
        _install(data);
        _verified.clear();
        await _scan();
        notifyListeners();
        // Only continue a batch the user already started in Settings.
        if (resume != null) unawaited(start(resume));
      }
    } catch (e) {
      updateError = '检查资源更新失败：$e';
    } finally {
      checking = false;
      _catalogDownloads = {};
      notifyListeners();
    }
  }

  Future<void> _write(File file, String value) async {
    final writing = _writes.catchError((Object _) {}).then((_) async {
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(value, flush: true);
      await temporary.rename(file.path);
    });
    _writes = writing;
    await writing;
  }

  Future<void> _saveState() async {
    try {
      await _write(
        _stateFile,
        jsonEncode({'selection': selection, 'state': state}),
      );
    } catch (e) {
      downloadError = '保存下载状态失败：$e';
    }
  }

  Future<File> ensure(String url, {bool interactive = true}) async {
    final resource = resources[url];
    if (resource == null) throw StateError('资源不在清单中：$url');
    return _ensureResource(resource, interactive: interactive);
  }

  Future<File> _ensureResource(
    ReviewResource resource, {
    bool interactive = true,
  }) async {
    if (_closed || clearing) throw const ReviewPaused();
    final file = fileFor(resource);
    // Also recover matching files when a previous manifest was lost or the
    // prior update staged a file before its catalog could be committed.
    if (!_cached.contains(resource.key) &&
        await file.exists() &&
        await file.length() == resource.bytes) {
      _cached.add(resource.key);
    }
    if (_cached.contains(resource.key)) {
      if (_verified.contains(resource.key)) return file;
      try {
        final digest = await sha256.bind(file.openRead()).first;
        if (digest.toString() == resource.hash) {
          if (_closed || clearing) throw const ReviewPaused();
          _verified.add(resource.key);
          return file;
        }
      } catch (_) {
        /* removed externally or corrupt */
      }
      _cached.remove(resource.key);
    }
    final existing = _jobs[resource.key];
    if (existing != null) {
      if (interactive) {
        existing.interactive = true;
        if (_queue.remove(existing)) _queue.insert(0, existing);
      }
      return existing.result.future;
    }
    if (_closed || clearing) throw const ReviewPaused();
    final job = _ReviewJob(resource, interactive);
    _jobs[resource.key] = job;
    if (interactive) {
      _queue.insert(0, job);
    } else {
      _queue.add(job);
    }
    _pump();
    return job.result.future;
  }

  void _pump() {
    while (!_closed && !clearing && _active < 3 && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _active++;
      unawaited(
        _download(job)
            .then<void>(
              (file) {
                job.result.complete(file);
              },
              onError: (Object e, StackTrace stack) {
                job.result.completeError(e, stack);
              },
            )
            .whenComplete(() {
              _jobs.remove(job.resource.key);
              _active--;
              _pump();
              notifyListeners();
            }),
      );
    }
  }

  Future<File> _download(_ReviewJob job) async {
    final resource = job.resource;
    final destination = fileFor(resource);
    final part = File('${destination.path}.part');
    Object? failure;
    final sources = [...resource.sources];
    if (resource.sirenSongId != null &&
        RegExp(r'^\d+$').hasMatch(resource.sirenSongId!)) {
      try {
        job.request = await _client
            .getUrl(
              Uri.https(
                'monster-siren.hypergryph.com',
                '/api/song/${resource.sirenSongId}',
              ),
            )
            .timeout(const Duration(seconds: 15));
        final response = await job.request!.close().timeout(
          const Duration(seconds: 15),
        );
        final song =
            jsonDecode(
                  await utf8.decoder
                      .bind(response)
                      .join()
                      .timeout(const Duration(seconds: 15)),
                )
                as Map;
        final fresh = (song['data'] as Map?)?['sourceUrl'];
        if (fresh is String && Uri.parse(fresh).scheme == 'https') {
          sources.insert(0, fresh);
        }
      } catch (_) {
        /* Fallback to the last verified CDN URL. */
      }
    }
    for (final url in sources) {
      if (job.cancelled) throw const ReviewPaused();
      IOSink? sink;
      try {
        job.loaded = 0;
        job.request = await _client
            .getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 20));
        if (job.cancelled) {
          job.request!.abort();
          throw const ReviewPaused();
        }
        job.request!.headers.set(
          HttpHeaders.refererHeader,
          'https://prts.wiki/',
        );
        job.request!.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        final response = await job.request!.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200) {
          throw HttpException(
            'HTTP ${response.statusCode}',
            uri: Uri.parse(url),
          );
        }
        sink = part.openWrite();
        var notified = DateTime.fromMillisecondsSinceEpoch(0);
        job.iterator = StreamIterator(
          response.timeout(const Duration(seconds: 30)),
        );
        while (await job.iterator!.moveNext()) {
          if (job.cancelled) throw const ReviewPaused();
          final chunk = job.iterator!.current;
          job.loaded += chunk.length;
          if (job.loaded > resource.bytes) {
            throw const FormatException('Resource size mismatch');
          }
          sink.add(chunk);
          if (DateTime.now().difference(notified).inMilliseconds > 150) {
            notified = DateTime.now();
            notifyListeners();
          }
        }
        if (job.cancelled) throw const ReviewPaused();
        await sink.flush();
        await sink.close();
        sink = null;
        if (job.loaded != resource.bytes ||
            (await sha256.bind(part.openRead()).first).toString() !=
                resource.hash) {
          throw const FormatException('资源校验失败');
        }
        if (job.cancelled) throw const ReviewPaused();
        final oldSize = await destination.exists()
            ? await destination.length()
            : 0;
        await part.rename(destination.path);
        storedBytes += resource.bytes - oldSize;
        _cached.add(resource.key);
        _verified.add(resource.key);
        job.loaded = 0;
        return destination;
      } catch (e) {
        failure = e;
        if (job.cancelled) throw const ReviewPaused();
      } finally {
        await job.iterator?.cancel();
        job.iterator = null;
        await sink?.close();
        if (await part.exists()) await part.delete();
        job.loaded = 0;
        job.request = null;
      }
    }
    throw failure ?? StateError('无法下载资源');
  }

  Future<void> start(String scope) async {
    if (!['home', 'all'].contains(scope) ||
        revision == null ||
        clearing ||
        _closed) {
      return;
    }
    await pause();
    final generation = ++_batchGeneration;
    selection = scope;
    running = true;
    state = 'downloading';
    downloadError = null;
    await _saveState();
    notifyListeners();
    try {
      final urls = selected.map((r) => r.url).toList();
      // Leave two connections available for the currently visible story art/audio.
      for (final url in urls) {
        if (generation != _batchGeneration) return;
        await ensure(url, interactive: false);
      }
      if (generation == _batchGeneration) state = 'complete';
    } catch (e) {
      if (generation == _batchGeneration && e is! ReviewPaused) {
        state = 'failed';
        downloadError = '$e';
      }
    } finally {
      if (generation == _batchGeneration) {
        running = false;
        await _saveState();
        notifyListeners();
      }
    }
  }

  Future<void> pause() async {
    final wasRunning = running;
    running = false;
    _batchGeneration++;
    if (wasRunning) state = 'paused';
    final cancelled = <Future<File>>[];
    for (final job in _jobs.values.toList()) {
      if (job.interactive) continue;
      cancelled.add(job.result.future);
      job.cancelled = true;
      job.request?.abort();
      unawaited(job.iterator?.cancel());
      if (_queue.remove(job)) {
        _jobs.remove(job.resource.key);
        job.result.completeError(const ReviewPaused());
      }
    }
    await Future.wait(
      cancelled.map((f) => f.then<void>((_) {}, onError: (Object _) {})),
    );
    if (wasRunning) await _saveState();
    notifyListeners();
  }

  Future<void> clear() async {
    clearing = true;
    notifyListeners();
    try {
      await pause();
      final pending = _jobs.values.toList();
      for (final job in pending) {
        job.cancelled = true;
        job.request?.abort();
        unawaited(job.iterator?.cancel());
        if (_queue.remove(job)) {
          _jobs.remove(job.resource.key);
          job.result.completeError(const ReviewPaused());
        }
      }
      await Future.wait(
        pending.map(
          (j) => j.result.future.then<void>((_) {}, onError: (Object _) {}),
        ),
      );
      final catalog = unique
          .where((r) => r.roles.contains('metadata'))
          .map((r) => r.key)
          .toSet();
      // Preserve the offline catalog and independent AVG story downloads.
      await for (final file in files.list()) {
        if (file is File &&
            file.parent.absolute.path == files.absolute.path &&
            RegExp(
              r'^[a-f0-9]{64}\.[a-z0-9]+(?:\.part)?$',
            ).hasMatch(file.uri.pathSegments.last) &&
            !catalog.contains(file.uri.pathSegments.last)) {
          await file.delete();
        }
      }
      _cached.retainAll(catalog);
      _verified.retainAll(catalog);
      await _scan();
      state = 'paused';
      selection ??= 'home';
      downloadError = null;
      await _saveState();
    } finally {
      clearing = false;
      notifyListeners();
    }
  }

  Future<void> close() async {
    await pause();
    _closed = true;
    final pending = _jobs.values.toList();
    for (final job in pending) {
      job.cancelled = true;
      job.request?.abort();
      unawaited(job.iterator?.cancel());
      if (_queue.remove(job)) {
        _jobs.remove(job.resource.key);
        job.result.completeError(const ReviewPaused());
      }
    }
    _client.close(force: true);
    await Future.wait(
      pending.map(
        (j) => j.result.future.then<void>((_) {}, onError: (Object _) {}),
      ),
    );
    await _writes;
  }
}

class _ReviewJob {
  _ReviewJob(this.resource, this.interactive);
  final ReviewResource resource;
  final Completer<File> result = Completer<File>();
  bool interactive, cancelled = false;
  int loaded = 0;
  HttpClientRequest? request;
  StreamIterator<List<int>>? iterator;
}

class ReviewPaused implements Exception {
  const ReviewPaused();
}
