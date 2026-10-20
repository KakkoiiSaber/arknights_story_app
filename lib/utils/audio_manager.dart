import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../config/config.dart';
import 'audio_backend_native.dart'
    if (dart.library.js_interop) 'audio_backend_web.dart';

final audio = AudioManager();

class AudioManager {
  final AppAudioPlayer _intro = AppAudioPlayer();
  final AppAudioPlayer _loop = AppAudioPlayer();
  final AppAudioPlayer _sfx = AppAudioPlayer();

  double _masterVolume = 1.0;
  int _musicGeneration = 0;
  final ValueNotifier<bool> soundEnabled = ValueNotifier<bool>(
    Config.isSoundEnabled,
  );

  Future<void> init() async {
    await _intro.setReleaseMode(ReleaseMode.stop);
    await _loop.setReleaseMode(ReleaseMode.loop);
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

  // play only once intro
  Future<void> intro(String? url) async {
    if (!await _setSourceSafely(_intro, url)) return;
    await _resumeSafely(_intro);
  }

  // play looped music
  Future<void> loop(String? url) async {
    final generation = ++_musicGeneration;
    if (!await _setSourceSafely(_loop, url)) return;
    if (generation != _musicGeneration) return;
    await _resumeSafely(_loop);
  }

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

  Future<void> intro2loop(String? introURL, String? loopURL) async {
    final generation = ++_musicGeneration;
    final introReady = await _setSourceSafely(_intro, introURL);
    if (generation != _musicGeneration) return;
    final loopReady = await _setSourceSafely(_loop, loopURL);
    if (generation != _musicGeneration) return;

    // If the loop track fails to load, don't start playback to avoid errors.
    if (!loopReady) return;

    // Play intro, then start loop immediately after completion
    if (introReady) {
      final playedIntro = await _resumeSafely(_intro);
      if (generation != _musicGeneration) return;
      if (!playedIntro) {
        await _resumeSafely(_loop);
        return;
      }
      _intro.onPlayerComplete.first
          .then((_) async {
            if (generation != _musicGeneration) return;
            await _resumeSafely(_loop);
          })
          .catchError((Object e, StackTrace st) {
            log(
              'Audio onPlayerComplete -> loop failed: $e',
              stackTrace: st,
              name: 'AudioManager',
            );
          });
      return;
    }

    // If intro failed, start loop directly.
    await _resumeSafely(_loop);
  }

  Future<void> stop() async {
    _musicGeneration++;
    // Issue every stop before yielding, so a page being disposed cannot later
    // stop the next page's loop after its intro has already started.
    await Future.wait([_intro.stop(), _loop.stop(), _sfx.stop()]);
  }

  Future<void> setVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);
    await _applyVolume();
  }

  Future<void> stopSfx() async {
    await _sfx.stop();
  }

  Future<void> dispose() async {
    await _intro.dispose();
    await _loop.dispose();
    await _sfx.dispose();
  }

  Future<void> _applyVolume() async {
    final effective = Config.isSoundEnabled ? _masterVolume : 0.0;
    await _intro.setVolume(effective);
    await _loop.setVolume(effective);
    await _sfx.setVolume(effective);
  }

  Future<bool> _setSourceSafely(AppAudioPlayer player, String? url) async {
    if (url == null || url.isEmpty) return false;

    try {
      await player.setSource(UrlSource(url));
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
