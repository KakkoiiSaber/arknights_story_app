import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import '../downloads/native_downloads.dart';
import '../downloads/story_resource_sources.dart';

/// Bound only to loopback, with an unguessable per-launch route prefix.
/// Remote assets use a same-origin route so worker/image/audio/video requests
/// all share the native downloader's local files without WebView-specific APIs.
class NativePlayerHost {
  NativePlayerHost(this.downloads);
  final NativeDownloads downloads;
  final _remote = HttpClient();
  // Delivery diagnostics used by the native offline smoke test.
  int remoteRequests = 0;
  int cachedRequests = 0;
  HttpServer? _server;
  late final Map<String, ArchiveFile> _bundle;
  late final String _token;
  late Uri base;
  Future<void> start() async {
    final zip = await rootBundle.load('lib/assets/prts_player.zip');
    final archive = ZipDecoder().decodeBytes(
      zip.buffer.asUint8List(zip.offsetInBytes, zip.lengthInBytes),
    );
    _bundle = {
      for (final entry in archive.files)
        if (entry.isFile) entry.name: entry,
    };
    _token = List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${_server!.port}/$_token/');
    _server!.listen((request) {
      unawaited(_serve(request));
    });
  }

  Uri page(String name, String script, {String? title}) => base
      .resolve(name)
      .replace(
        queryParameters: {
          'native': '1',
          'script': script,
          if (title != null) 'title': title,
        },
      );
  Future<void> _serve(HttpRequest request) async {
    try {
      if (!request.uri.path.startsWith('/$_token/')) {
        request.response.statusCode = 404;
        return;
      }
      final path = request.uri.path.substring(_token.length + 2);
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = 405;
        return;
      }
      if (path.startsWith('resource/')) {
        final raw = request.uri.queryParameters['url'];
        final url = raw == null ? null : Uri.tryParse(raw);
        if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty) {
          request.response.statusCode = 400;
          return;
        }
        final file = downloads.fileFor(raw!);
        if (await file.exists()) {
          cachedRequests++;
          final size = await file.length();
          request.response.headers.contentType = ContentType.parse(
            _mime(url.path),
          );
          request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
          final range = RegExp(
            r'^bytes=(\d+)-(\d*)$',
          ).firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
          var start = 0;
          var end = size - 1;
          if (range != null) {
            start = int.parse(range[1]!);
            if (range[2]!.isNotEmpty) end = min(end, int.parse(range[2]!));
            if (start > end || start >= size) {
              request.response.statusCode = 416;
              request.response.headers.set('content-range', 'bytes */$size');
              return;
            }
            request.response.statusCode = 206;
            request.response.headers.set(
              'content-range',
              'bytes $start-$end/$size',
            );
          }
          request.response.contentLength = end - start + 1;
          if (request.method != 'HEAD') {
            await request.response.addStream(file.openRead(start, end + 1));
          }
        } else {
          remoteRequests++;
          final response = await _resourceResponse(request, raw);
          request.response.statusCode = response.statusCode;
          for (final header in [
            'content-type',
            'content-range',
            'accept-ranges',
          ]) {
            final value = response.headers.value(header);
            if (value != null) request.response.headers.set(header, value);
          }
          if (response.contentLength >= 0 &&
              response.compressionState !=
                  HttpClientResponseCompressionState.decompressed) {
            request.response.contentLength = response.contentLength;
          }
          if (request.method != 'HEAD') {
            await request.response.addStream(response);
          }
        }
      } else {
        final asset = _bundle[path];
        if (asset == null) {
          request.response.statusCode = 404;
          return;
        }
        final bytes = asset.content;
        request.response.headers.contentType = ContentType.parse(_mime(path));
        request.response.contentLength = bytes.length;
        if (request.method != 'HEAD') request.response.add(bytes);
      }
    } catch (_) {
      try {
        request.response.statusCode = 502;
      } catch (_) {}
    } finally {
      await request.response.close();
    }
  }

  Future<HttpClientResponse> _resourceResponse(
    HttpRequest request,
    String url,
  ) async {
    Object? failure;
    for (final source in downloads.sourcesFor(url)) {
      HttpClientRequest? upstream;
      try {
        upstream = await _remote
            .openUrl(request.method, source)
            .timeout(Duration(seconds: isGitHubRaw(source) ? 8 : 30));
        upstream.headers.set(HttpHeaders.refererHeader, 'https://prts.wiki/');
        final range = request.headers.value(HttpHeaders.rangeHeader);
        if (range != null) upstream.headers.set(HttpHeaders.rangeHeader, range);
        final response = await upstream.close().timeout(
          Duration(seconds: isGitHubRaw(source) ? 12 : 60),
        );
        if (response.statusCode == 200 || response.statusCode == 206) {
          return response;
        }
        await response.listen(null).cancel();
        throw HttpException('HTTP ${response.statusCode}', uri: source);
      } catch (error) {
        upstream?.abort();
        failure = error;
      }
    }
    throw failure ?? StateError('未找到可用资源来源');
  }

  static String _mime(String path) =>
      switch (path.split('.').last.toLowerCase()) {
        'html' => 'text/html; charset=utf-8',
        'js' => 'application/javascript',
        'json' => 'application/json',
        'css' => 'text/css',
        'txt' => 'text/plain; charset=utf-8',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'mp3' => 'audio/mpeg',
        'mp4' => 'video/mp4',
        'woff2' => 'font/woff2',
        _ => 'application/octet-stream',
      };
  Future<void> close() async {
    await _server?.close(force: true);
    _remote.close(force: true);
  }
}
