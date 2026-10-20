import 'dart:async';

/// Backend-independent music channel, so route races can be tested without audio.
abstract interface class MusicPlayer {
  Stream<void> get completed;
  Future<void> load(String url, {required bool loop});
  Future<void> play();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class MusicController {
  MusicController({
    required this.createPlayer,
    this.fadeDuration = const Duration(milliseconds: 500),
    this.onError,
  });

  final MusicPlayer Function() createPlayer;
  final Duration fadeDuration;
  final void Function(Object, StackTrace)? onError;
  final Set<_Track> _tracks = {};
  MusicScope? _scope;
  _Track? _track;
  double _volume = 1;

  /// Claim before awaiting metadata. An outgoing page cannot reclaim playback
  /// when its old network request eventually completes.
  MusicScope claim() {
    final scope = MusicScope._(this);
    _scope = scope;
    final previous = _track;
    _track = null;
    if (previous != null) unawaited(_retire(previous));
    return scope;
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 1);
    await Future.wait(_tracks.toList().map(_applyVolume));
  }

  Future<void> stop() async {
    _scope = null;
    _track = null;
    await Future.wait(_tracks.toList().map(_retire));
  }

  Future<void> _close(MusicScope scope) async {
    if (!identical(_scope, scope)) return;
    await stop();
  }

  Future<void> _play(MusicScope scope, String? intro, String? loop) async {
    if (!scope.isCurrent) return;
    if (loop == null || loop.isEmpty) {
      final previous = _track;
      _track = null;
      if (previous != null) await _retire(previous);
      return;
    }
    if (_track?.introUrl == intro && _track?.loopUrl == loop) return;
    final previous = _track;
    final track = _Track(createPlayer(), createPlayer(), intro, loop);
    _track = track;
    _tracks.add(track);
    if (previous != null) unawaited(_retire(previous));
    // Each request owns its players. Late loads never change another route's
    // source, gain, or completion listener.
    track.preparing = _prepare(scope, track);
    await track.preparing;
  }

  bool _current(MusicScope scope, _Track track) =>
      scope.isCurrent && identical(_track, track) && track.retiring == null;

  Future<bool> _load(MusicPlayer player, String? url, bool loop) async {
    if (url == null || url.isEmpty) return false;
    try {
      await player.setVolume(0);
      await player.load(url, loop: loop);
      return true;
    } catch (e, st) {
      onError?.call(e, st);
      return false;
    }
  }

  Future<void> _prepare(MusicScope scope, _Track track) async {
    final ready = await Future.wait([
      _load(track.intro, track.introUrl, false),
      _load(track.loop, track.loopUrl, true),
    ]);
    if (!_current(scope, track)) return;
    if (!ready[1]) {
      _track = null;
      // Do not await: retirement waits for this preparation to finish.
      unawaited(_retire(track));
      return;
    }
    try {
      if (ready[0]) {
        // Subscribe before playback, including very short intros.
        track.completion = track.intro.completed.listen((_) {
          if (_current(scope, track)) unawaited(_playLoop(track));
        });
        try {
          await track.intro.play();
        } catch (e, st) {
          onError?.call(e, st);
          await track.completion?.cancel();
          if (_current(scope, track)) await track.loop.play();
        }
      } else {
        await track.loop.play();
      }
      if (_current(scope, track)) await _fade(track, 1);
    } catch (e, st) {
      onError?.call(e, st);
      if (identical(_track, track)) _track = null;
      unawaited(_retire(track));
    }
  }

  Future<void> _playLoop(_Track track) async {
    try {
      await track.loop.play();
    } catch (e, st) {
      onError?.call(e, st);
    }
  }

  Future<void> _applyVolume(_Track track) => Future.wait([
    track.intro.setVolume(_volume * track.gain),
    track.loop.setVolume(_volume * track.gain),
  ]).then((_) {});

  Future<void> _fade(_Track track, double target) async {
    final generation = ++track.fadeGeneration;
    final start = track.gain;
    final steps = fadeDuration.inMilliseconds == 0 ? 1 : 20;
    for (var step = 1; step <= steps; step++) {
      if (steps > 1) await Future<void>.delayed(fadeDuration ~/ steps);
      if (generation != track.fadeGeneration) return;
      final t = step / steps;
      final eased = t * t * (3 - 2 * t);
      track.gain = start + (target - start) * eased;
      await _applyVolume(track);
    }
  }

  Future<void> _retire(_Track track) =>
      track.retiring ??= _finishRetiring(track);

  Future<void> _finishRetiring(_Track track) async {
    try {
      await track.completion?.cancel();
      await _fade(track, 0);
    } catch (e, st) {
      onError?.call(e, st);
    } finally {
      // Entering the reader waits only for silence, never a slow old download.
      unawaited(_disposeAfterPreparation(track));
    }
  }

  Future<void> _disposeAfterPreparation(_Track track) async {
    try {
      await track.preparing;
      await track.completion?.cancel();
      _tracks.remove(track);
      await Future.wait([track.intro.dispose(), track.loop.dispose()]);
    } catch (e, st) {
      _tracks.remove(track);
      onError?.call(e, st);
    }
  }
}

class MusicScope {
  MusicScope._(this._controller);
  final MusicController _controller;
  bool get isCurrent => identical(_controller._scope, this);

  Future<void> play({String? intro, String? loop}) =>
      _controller._play(this, intro, loop);
  Future<void> close() => _controller._close(this);
}

class _Track {
  _Track(this.intro, this.loop, this.introUrl, this.loopUrl);
  final MusicPlayer intro;
  final MusicPlayer loop;
  final String? introUrl;
  final String loopUrl;
  double gain = 0;
  int fadeGeneration = 0;
  StreamSubscription<void>? completion;
  Future<void>? preparing;
  Future<void>? retiring;
}
