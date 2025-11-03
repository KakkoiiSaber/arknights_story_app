// lib/utils/audio_manager.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _introPlayer = AudioPlayer();
  final AudioPlayer _loopPlayer = AudioPlayer();
  bool _isMuted = false;
  bool _isPreloaded = false;

  final String _introUrl =
      "https://raw.githubusercontent.com/akgcc/arkdata/main/assets/torappu/dynamicassets/audio/sound_beta_2/music/beta1_180603/m_sys_void_intro.mp3";
  final String _loopUrl =
      "https://raw.githubusercontent.com/akgcc/arkdata/main/assets/torappu/dynamicassets/audio/sound_beta_2/music/beta1_180603/m_sys_void_loop.mp3";

  /// Preload both intro and loop audio into memory
  Future<void> preload() async {
    if (_isPreloaded) return;
    await _introPlayer.setSource(UrlSource(_introUrl));
    await _loopPlayer.setSource(UrlSource(_loopUrl));
    await _loopPlayer.setReleaseMode(ReleaseMode.loop);
    _isPreloaded = true;
  }

  /// Initialize playback (assumes preload() done first)
  Future<void> init({
    double volume = 0.5,
    Duration crossFade = const Duration(milliseconds: 400),
  }) async {
    if (!_isPreloaded) await preload();

    await _introPlayer.setVolume(volume);
    await _loopPlayer.setVolume(0);

    // Start intro
    await _introPlayer.resume();

    // Schedule crossfade near intro end
    _introPlayer.onDurationChanged.listen((totalDuration) {
      if (totalDuration.inMilliseconds > 0) {
        final triggerTime = totalDuration - crossFade;
        _introPlayer.onPositionChanged.listen((pos) async {
          if (pos >= triggerTime) {
            _introPlayer.onPositionChanged.drain(); // prevent multiple calls
            await _loopPlayer.resume();
            _startCrossFade(volume, crossFade);
          }
        });
      }
    });

    // Ensure loop continues after intro finishes
    _introPlayer.onPlayerComplete.listen((_) async {
      await _loopPlayer.resume();
      await _loopPlayer.setVolume(_isMuted ? 0.0 : volume);
    });
  }

  Future<void> _startCrossFade(double targetVolume, Duration duration) async {
    const int steps = 20;
    final double stepVol = targetVolume / steps;
    final int stepMs = (duration.inMilliseconds / steps).round();

    for (int i = 0; i <= steps; i++) {
      if (_isMuted) break;
      final fadeOut = targetVolume - (stepVol * i);
      final fadeIn = stepVol * i;
      _introPlayer.setVolume(fadeOut);
      _loopPlayer.setVolume(fadeIn);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    final double volume = _isMuted ? 0.0 : 0.5;
    _introPlayer.setVolume(volume);
    _loopPlayer.setVolume(volume);
  }

  bool get isMuted => _isMuted;

  Future<void> dispose() async {
    await _introPlayer.dispose();
    await _loopPlayer.dispose();
    _isPreloaded = false;
  }
}
