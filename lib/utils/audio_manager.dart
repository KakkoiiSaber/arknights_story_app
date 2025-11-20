import 'package:audioplayers/audioplayers.dart';

final audio = AudioManager();

class AudioManager {
  final AudioPlayer _intro = AudioPlayer();
  final AudioPlayer _loop = AudioPlayer();

  Future<void> init() async {
    await _intro.setReleaseMode(ReleaseMode.stop);
    await _loop.setReleaseMode(ReleaseMode.loop);
  }

  // urls = [introURL, loopURL]
  Future<void> themeOST(List<String> urls) async {
    final introURL = urls[0];
    final loopURL = urls[1];

    // Pre-set sources (kicks off buffering)
    await Future.wait([
      _intro.setSource(UrlSource(introURL)),
      _loop.setSource(UrlSource(loopURL)),
    ]);

    // Play intro, then start loop immediately after completion
    await _intro.resume();
    _intro.onPlayerComplete.first.then((_) async {
      await _loop.resume();
    });
  }

  Future<void> stop() async {
    await _intro.stop();
    await _loop.stop();
  }

  Future<void> dispose() async {
    await _intro.dispose();
    await _loop.dispose();
  }
}