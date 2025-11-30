import 'package:arknights_story_app/components/story_dashboard.dart';
import 'package:arknights_story_app/config/database.dart';
import 'package:flutter/material.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';
import '../config/config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isPlayingHomeMusic = false;
  StoryTypeFilter _filter = StoryTypeFilter.all;
  late final Future<dynamic> _storyMetaFuture;

  @override
  void initState() {
    super.initState();
    _storyMetaFuture =
        DataRetriever.getJsonFromURL(Database.storyMetaTablePath);
    audio.setEnabled(Config.isSoundEnabled);
    _playHomeMusic(); // do not await here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When returning from another page, kick off the home music again.
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && !_isPlayingHomeMusic) {
      _playHomeMusic();
    }
  }

  Future<void> _playHomeMusic() async {
    if (_isPlayingHomeMusic) return;
    _isPlayingHomeMusic = true;
    try {
      await audio.setVolume(1.0);
      final audioTable = await DataRetriever.getJsonFromURL(Database.gameMusicDataPath);
      final homeBgMusicInfo = audioTable["sys.ON_MUSIC.bg_void"];
      final String introPath = homeBgMusicInfo["intro"];
      final String loopPath = homeBgMusicInfo["loop"];
      await audio.intro2loop(Database.gameMusicPath + introPath, Database.gameMusicPath + loopPath);
    } finally {
      _isPlayingHomeMusic = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = const [
      StoryTypeFilter.all,
      StoryTypeFilter.main,
      StoryTypeFilter.activity,
      StoryTypeFilter.mini,
    ];
    final labels = const ['All', 'Main', 'Activity', 'Mini'];
    final selected =
        filters.map((f) => f == _filter).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          ToggleButtons(
            isSelected: selected,
            onPressed: (index) {
              setState(() {
                _filter = filters[index];
              });
            },
            borderRadius: BorderRadius.circular(10),
            selectedColor: Colors.white,
            fillColor: Colors.white24,
            constraints:
                const BoxConstraints(minHeight: 32, minWidth: 70),
            children: [
              for (final label in labels)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(label),
                ),
            ],
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: audio.soundEnabled,
            builder: (context, enabled, _) {
              return IconButton(
                icon: Icon(enabled ? Icons.volume_up : Icons.volume_off),
                tooltip: enabled ? 'Mute' : 'Unmute',
                onPressed: () async {
                  await audio.toggleEnabled();
                  setState(() {});
                },
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StoryDashboard(
        storyMetaTableFuture: _storyMetaFuture,
        filter: _filter,
      ),
    );
  }
}
