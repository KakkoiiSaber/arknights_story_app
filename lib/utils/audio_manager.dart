import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';

final audio = AudioManager();

class AudioManager {
  final AudioPlayer _intro = AudioPlayer();
  final AudioPlayer _loop = AudioPlayer();

  Future<void> init() async {
    await _intro.setReleaseMode(ReleaseMode.stop);
    await _loop.setReleaseMode(ReleaseMode.loop);
  }

  // play only once intro
  Future<void> intro(String? url) async {
    if (!await _setSourceSafely(_intro, url)) return;
    await _resumeSafely(_intro);
  }

  // play looped music
  Future<void> loop(String? url) async {
    if (!await _setSourceSafely(_loop, url)) return;
    await _resumeSafely(_loop);
  }

  Future<void> playSound(String? url, {double? volume}) async {
    if (url == null || url.isEmpty) return;
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    if (volume != null) {
      await player.setVolume(volume.clamp(0.0, 1.0));
    }
    try {
      await player.play(UrlSource(url));
    } catch (e, st) {
      log('Audio playSound failed for $url: $e',
          stackTrace: st, name: 'AudioManager');
    } finally {
      player.onPlayerComplete.first.then((_) => player.dispose()).catchError(
        (_) {},
      );
    }
  }

  Future<void> intro2loop(String? introURL, String? loopURL) async {
    final introReady = await _setSourceSafely(_intro, introURL);
    final loopReady = await _setSourceSafely(_loop, loopURL);

    // If the loop track fails to load, don't start playback to avoid errors.
    if (!loopReady) return;

    // Play intro, then start loop immediately after completion
    if (introReady) {
      final playedIntro = await _resumeSafely(_intro);
      if (!playedIntro) {
        await _resumeSafely(_loop);
        return;
      }
      _intro.onPlayerComplete.first.then((_) async {
        await _resumeSafely(_loop);
      }).catchError((Object e, StackTrace st) {
        log('Audio onPlayerComplete -> loop failed: $e',
            stackTrace: st, name: 'AudioManager');
      });
      return;
    }

    // If intro failed, start loop directly.
    await _resumeSafely(_loop);
  }

  Future<void> stop() async {
    await _intro.stop();
    await _loop.stop();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _intro.setVolume(clamped);
    await _loop.setVolume(clamped);
  }

  Future<void> dispose() async {
    await _intro.dispose();
    await _loop.dispose();
  }

  Future<bool> _setSourceSafely(AudioPlayer player, String? url) async {
    if (url == null || url.isEmpty) return false;

    try {
      await player.setSource(UrlSource(url));
      return true;
    } catch (e, st) {
      log('Audio setSource failed for $url: $e', stackTrace: st, name: 'AudioManager');
      return false;
    }
  }

  Future<bool> _resumeSafely(AudioPlayer player) async {
    try {
      await player.resume();
      return true;
    } catch (e, st) {
      log('Audio resume failed: $e', stackTrace: st, name: 'AudioManager');
      return false;
    }
  }
}
