import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../config/config.dart';
import '../downloads/review_service.dart';
import 'audio_backend_native.dart'
    if (dart.library.js_interop) 'audio_backend_web.dart';

import 'music_controller.dart';

final audio = AudioManager();

class AudioManager {
  final MusicController _music = MusicController(
    createPlayer: () => _MusicPlayerAdapter(),
    onError: (error, stack) => log(
      'Music playback failed: $error',
      stackTrace: stack,
      name: 'AudioManager',
    ),
  );
  final AppAudioPlayer _sfx = AppAudioPlayer();

  double _masterVolume = 1.0;
  final ValueNotifier<bool> soundEnabled = ValueNotifier<bool>(
    Config.isSoundEnabled,
  );

  Future<void> init() async {
    await _sfx.setReleaseMode(ReleaseMode.stop);
    await _applyVolume();
  }

  bool get isEnabled => soundEnabled.value;
  bool get isMuted => !soundEnabled.value;

  Future<void> setEnabled(bool enabled) async {
    Config.isSoundEnabled = enabled;
    soundEnabled.value = enabled;
    await _applyVolume();
  }

  Future<void> toggleEnabled() async {
    await setEnabled(!soundEnabled.value);
  }

  MusicScope claimMusic() => _music.claim();

  /// Play one-shot SFX on a dedicated channel (replaces previous SFX).
  Future<void> playSoundSingle(String? url, {double? volume}) async {
    if (url == null || url.isEmpty) return;
    final effVolume = Config.isSoundEnabled
        ? (volume ?? _masterVolume).clamp(0.0, 1.0)
        : 0.0;
    await _sfx.setVolume(effVolume);
    await _sfx.stop();
    if (!await _setSourceSafely(_sfx, url)) return;
    await _resumeSafely(_sfx);
  }

  /// Backward-compatible sound API; routes through shared SFX channel so
  /// volume/mute updates apply immediately.
  Future<void> playSound(String? url, {double? volume}) =>
      playSoundSingle(url, volume: volume);

  Future<void> stop() async {
    await Future.wait([_music.stop(), _sfx.stop()]);
  }

  Future<void> setVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);
    await _applyVolume();
  }

  Future<void> stopSfx() async {
    await _sfx.stop();
  }

  Future<void> dispose() async {
    await _music.stop();
    await _sfx.dispose();
  }

  Future<void> _applyVolume() async {
    final effective = Config.isSoundEnabled ? _masterVolume : 0.0;
    await _music.setVolume(effective);
    await _sfx.setVolume(effective);
  }

  Future<bool> _setSourceSafely(
    AppAudioPlayer player,
    String? url, {
    bool Function()? isCurrent,
  }) async {
    if (url == null || url.isEmpty) return false;

    try {
      final localFile = await reviewAssets.localPath(url);
      if (isCurrent != null && !isCurrent()) return false;
      await player.setSource(
        reviewAudioSource(url, null, localFile: localFile),
      );
      return true;
    } catch (e, st) {
      log(
        'Audio setSource failed for $url: $e',
        stackTrace: st,
        name: 'AudioManager',
      );
      return false;
    }
  }

  Future<bool> _resumeSafely(AppAudioPlayer player) async {
    try {
      await player.resume();
      return true;
    } catch (e, st) {
      log('Audio resume failed: $e', stackTrace: st, name: 'AudioManager');
      return false;
    }
  }
}

class _MusicPlayerAdapter implements MusicPlayer {
  final AppAudioPlayer _player = AppAudioPlayer();

  @override
  Stream<void> get completed => _player.onPlayerComplete;

  @override
  Future<void> load(String url, {required bool loop}) async {
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    final localFile = await reviewAssets.localPath(url);
    await _player.setSource(reviewAudioSource(url, null, localFile: localFile));
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}
