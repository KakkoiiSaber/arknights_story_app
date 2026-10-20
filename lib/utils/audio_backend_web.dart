import 'dart:async';
import 'dart:js_interop';

import 'package:audioplayers/audioplayers.dart' show ReleaseMode, UrlSource;
import 'package:web/web.dart' as web;

/// A shared context keeps homepage and activity music unlocked across routes.
/// Sources may be scheduled while suspended; time only advances after a real
/// user gesture resumes the context. No silent playback or synthetic click.
class _BrowserAudio {
  final context = web.AudioContext();

  _BrowserAudio() {
    void syncState() {
      web.document.documentElement?.setAttribute(
        'data-music-state',
        context.state,
      );
    }

    final unlock = ((web.Event event) {
      if (!event.isTrusted || context.state != 'suspended') return;
      // Call synchronously inside the gesture, before any fetch/await.
      unawaited(context.resume().toDart.then<void>((_) {}, onError: (Object _) {}));
    }).toJS;
    web.document.addEventListener('click', unlock, true.toJS);
    web.document.addEventListener('touchend', unlock, true.toJS);
    web.document.addEventListener('keydown', unlock, true.toJS);
    context.addEventListener(
      'statechange',
      ((web.Event _) => syncState()).toJS,
    );
    syncState();
  }
}

final _browserAudio = _BrowserAudio();

/// The small subset of AudioPlayer used by AudioManager. Web Audio avoids
/// creating fresh, suspended contexts for each track in audioplayers_web.
class AppAudioPlayer {
  final _completed = StreamController<void>.broadcast();
  late final _gain = _browserAudio.context.createGain()
    ..connect(_browserAudio.context.destination);
  web.AudioBuffer? _buffer;
  web.AudioBufferSourceNode? _source;
  String? _url;
  int _loadGeneration = 0;
  bool _loop = false;
  bool _disposed = false;

  Stream<void> get onPlayerComplete => _completed.stream;

  Future<void> setReleaseMode(ReleaseMode mode) async {
    _loop = mode == ReleaseMode.loop;
    _source?.loop = _loop;
  }

  Future<void> setVolume(double volume) async => _gain.gain.value = volume;

  Future<void> setSource(UrlSource source) async {
    if (_url == source.url && _buffer != null) return;
    final generation = ++_loadGeneration;
    _stopSource();
    _buffer = null;
    _url = null;
    final response = await web.window.fetch(source.url.toJS).toDart;
    if (!response.ok) throw StateError('Audio HTTP ${response.status}');
    final bytes = await response.arrayBuffer().toDart;
    if (_disposed || generation != _loadGeneration) return;
    final buffer = await _browserAudio.context.decodeAudioData(bytes).toDart;
    if (_disposed || generation != _loadGeneration) return;
    _buffer = buffer;
    _url = source.url;
  }

  Future<void> resume() async {
    if (_disposed || _buffer == null || _source != null) return;
    final node = _browserAudio.context.createBufferSource()
      ..buffer = _buffer
      ..loop = _loop
      ..connect(_gain);
    _source = node;
    node.onended = ((web.Event _) {
      if (!identical(_source, node)) return;
      _source = null;
      node.disconnect();
      if (!_disposed) _completed.add(null);
    }).toJS;
    node.start();
  }

  void _stopSource() {
    final node = _source;
    _source = null;
    if (node == null) return;
    node.onended = null;
    node.stop();
    node.disconnect();
  }

  Future<void> stop() async {
    _loadGeneration++;
    _stopSource();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    _buffer = null;
    _gain.disconnect();
    await _completed.close();
  }
}
