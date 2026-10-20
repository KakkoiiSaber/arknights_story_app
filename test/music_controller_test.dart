import 'dart:async';

import 'package:arknights_story_app/utils/music_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlayer implements MusicPlayer {
  final events = StreamController<void>.broadcast(sync: true);
  final volumes = <double>[];
  String? url;
  bool looping = false;
  int plays = 0;
  bool disposed = false;
  bool completeOnPlay = false;
  bool failLoad = false;
  Completer<void>? loading;

  @override
  Stream<void> get completed => events.stream;
  @override
  Future<void> load(String url, {required bool loop}) async {
    this.url = url;
    looping = loop;
    if (failLoad) throw StateError('unavailable');
    await loading?.future;
  }

  @override
  Future<void> play() async {
    expect(disposed, isFalse);
    plays++;
    if (completeOnPlay) events.add(null);
  }

  @override
  Future<void> setVolume(double volume) async {
    expect(disposed, isFalse);
    volumes.add(volume);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }
}

Future<void> finishFade() =>
    Future<void>.delayed(const Duration(milliseconds: 240));

void main() {
  late List<FakePlayer> players;
  late MusicController music;

  setUp(() {
    players = [];
    music = MusicController(
      fadeDuration: const Duration(milliseconds: 100),
      createPlayer: () {
        final player = FakePlayer();
        players.add(player);
        return player;
      },
    );
  });

  test('outgoing page disposal cannot stop the restored homepage', () async {
    final home = music.claim();
    final start = home.play(loop: 'home');
    await finishFade();
    await start;
    expect(players[1].volumes.last, 1);

    final story = music.claim();
    final show = story.play(loop: 'story');
    await finishFade();
    await show;
    final homeAgain = music.claim();
    final restore = homeAgain.play(loop: 'home');
    // This occurs after Navigator.push's future completes, during disposal.
    await story.close();
    await home.close();
    await finishFade();
    await restore;
    expect(homeAgain.isCurrent, isTrue);
    expect(players[5].plays, 1);
    expect(players[5].volumes.last, 1);
    expect(players[5].disposed, isFalse);
    expect(players[3].disposed, isTrue);
    expect(players[3].volumes.where((v) => v > 0 && v < 1), isNotEmpty);
    expect(players[3].volumes.last, 0);
    final stop = music.stop();
    await finishFade();
    await stop;
  });

  test(
    'late loads and stale metadata never replace the current track',
    () async {
      final old = music.claim();
      final pending = old.play(loop: 'slow');
      final load = players[1].loading = Completer<void>();
      await Future<void>.delayed(Duration.zero);
      final current = music.claim();
      final start = current.play(loop: 'new');
      await finishFade();
      await start;
      await old.play(loop: 'late metadata');
      load.complete();
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(players.length, 4);
      expect(players[1].plays, 0);
      expect(players[1].disposed, isTrue);
      expect(players[3].plays, 1);
      expect(players[3].volumes.last, 1);
      final stop = music.stop();
      await finishFade();
      await stop;
    },
  );

  test(
    'intro completion is observed even during the initial play call',
    () async {
      final scope = music.claim();
      final start = scope.play(intro: 'intro', loop: 'loop');
      players[0].completeOnPlay = true;
      await finishFade();
      await start;
      expect(players[0].plays, 1);
      expect(players[1].plays, 1);
      expect(players[1].looping, isTrue);
      final replacement = music.claim();
      players[0].events.add(null);
      await finishFade();
      expect(players[1].plays, 1);
      final end = replacement.close();
      await finishFade();
      await end;
    },
  );

  test('mute and master volume remain effective throughout fades', () async {
    final scope = music.claim();
    final start = scope.play(loop: 'music');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await music.setVolume(0);
    final mutedAt = players[1].volumes.length;
    await finishFade();
    await start;
    expect(players[1].volumes.skip(mutedAt).every((v) => v == 0), isTrue);
    await music.setVolume(0.4);
    expect(players[1].volumes.last, 0.4);
    final silence = scope.play();
    await finishFade();
    await silence;
    expect(scope.isCurrent, isTrue);
    expect(players[1].volumes.last, 0);
    expect(players[1].disposed, isTrue);
    await scope.close();
  });

  test('entering a reader does not wait for an old network load', () async {
    final scope = music.claim();
    final pending = scope.play(loop: 'slow');
    final load = players[1].loading = Completer<void>();
    await Future<void>.delayed(Duration.zero);
    var silenced = false;
    final close = scope.close().then((_) => silenced = true);
    await finishFade();
    expect(silenced, isTrue);
    expect(players[1].plays, 0);
    load.complete();
    await pending;
    await close;
    await Future<void>.delayed(Duration.zero);
    expect(players[1].disposed, isTrue);
  });

  test(
    'failed loop is released and can be retried in the same scope',
    () async {
      final scope = music.claim();
      final failed = scope.play(loop: 'music');
      players[1].failLoad = true;
      await finishFade();
      await failed;
      expect(players[1].plays, 0);
      expect(players[1].disposed, isTrue);
      final retry = scope.play(loop: 'music');
      await finishFade();
      await retry;
      expect(players[3].plays, 1);
      final stop = music.stop();
      await finishFade();
      await stop;
    },
  );
}
