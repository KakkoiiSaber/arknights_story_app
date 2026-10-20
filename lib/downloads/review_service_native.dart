import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../config/database.dart';
import 'review_cache.dart';

final reviewAssets = ReviewAssetService();

class ReviewAssetService extends ChangeNotifier {
  ReviewCache? _cache;
  Future<void>? _initializing;
  String? _error;
  bool get supported => true;
  String? get revision => _cache?.revision;
  String? get error => _error ?? _cache?.downloadError ?? _cache?.updateError;
  bool get checking => _cache?.checking ?? false;
  bool get running => _cache?.running ?? false;
  bool get clearing => _cache?.clearing ?? false;
  String get state => _cache?.state ?? 'idle';
  String? get selection => _cache?.selection;
  int get storedBytes => _cache?.storedBytes ?? 0;
  int get totalBytes => _cache?.totalBytes ?? 0;
  int get selectedBytes => _cache?.selectedBytes ?? 0;
  int get downloadedBytes => _cache?.downloadedBytes ?? 0;
  int get completeCount => _cache?.completeCount ?? 0;
  int get totalCount => _cache?.selected.length ?? 0;
  int get activeBytes => _cache?.activeBytes ?? 0;
  int get activeTotalBytes => _cache?.activeTotalBytes ?? 0;
  double get progress => _cache?.progress ?? 0;
  Future<void> init() => _initializing ??= _init();
  Future<void> _init() async {
    try {
      final root = await getApplicationSupportDirectory();
      _cache = ReviewCache(
        Directory('${root.path}/review-resources'),
        Uri.parse(Database.reviewManifestURL),
      );
      await _cache!.init();
      _cache!.addListener(notifyListeners);
    } catch (e) {
      _error = '资源存储初始化失败：$e';
    }
    notifyListeners();
  }

  Future<void> checkForUpdates() async {
    await init();
    _error = null;
    await _cache?.checkForUpdates();
  }

  Future<void> _ready() async {
    await init();
    if (_cache?.revision == null) await checkForUpdates();
  }

  Future<dynamic> json(String url) async {
    await _ready();
    if (_cache?.resources.containsKey(url) != true) return null;
    final file = await _cache!.ensure(url);
    return jsonDecode(await file.readAsString());
  }

  Future<String?> localPath(String url) async {
    await _ready();
    if (_cache?.resources.containsKey(url) != true) return null;
    return (await _cache!.ensure(url)).path;
  }

  ImageProvider image(String url) {
    final resource = _cache?.resources[url];
    if (resource == null) return NetworkImage(url);
    return _ReviewImage(_cache!, url, resource.hash);
  }

  Future<void> start(String scope) async {
    await _ready();
    await _cache?.start(scope);
  }

  Future<void> pause() async => _cache?.pause();
  Future<void> clear() async => _cache?.clear();
}

class _ReviewImage extends ImageProvider<_ReviewImage> {
  const _ReviewImage(this.cache, this.url, this.hash);
  final ReviewCache cache;
  final String url, hash;
  @override
  Future<_ReviewImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _ReviewImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: url,
  );
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      final file = await cache.ensure(url);
      return decode(
        await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes()),
      );
    } catch (_) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _ReviewImage && other.url == url && other.hash == hash;
  @override
  int get hashCode => Object.hash(url, hash);
}
