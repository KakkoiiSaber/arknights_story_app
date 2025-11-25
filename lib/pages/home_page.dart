import 'package:arknights_story_app/components/story_dashboard.dart';
import 'package:arknights_story_app/config/database.dart';
import 'package:flutter/material.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _playHomeMusic(); // do not await here
  }

  Future<void> _playHomeMusic() async {
    final audioTable = await DataRetriever.getJsonFromURL(Database.gameMusicDataPath);
    final homeBgMusicInfo = audioTable["sys.ON_MUSIC.bg_void"];
    final String introPath = homeBgMusicInfo["intro"];
    final String loopPath = homeBgMusicInfo["loop"];
    await audio.intro2loop(Database.gameMusicPath + introPath, Database.gameMusicPath + loopPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: StoryDashboard(storyMetaTableFuture:  DataRetriever.getJsonFromURL(Database.storyMetaTablePath),),
    );
  }
}
