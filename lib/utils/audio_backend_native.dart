import 'package:audioplayers/audioplayers.dart';

class AppAudioPlayer extends AudioPlayer {
  AppAudioPlayer() {
    // Our pubspec keys already contain lib/assets; don't prepend assets/.
    audioCache = AudioCache(prefix: '');
  }
}

Source reviewAudioSource(String url, String? asset, {String? localFile}) =>
    localFile != null
    ? DeviceFileSource(localFile)
    : asset == null
    ? UrlSource(url)
    : AssetSource(asset);
