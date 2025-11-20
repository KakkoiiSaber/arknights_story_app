import 'package:arknights_story_app/components/story_dashboard.dart';
import 'package:flutter/material.dart';
// import '../utils/audio_manager.dart';
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
    // _playHomeMusic(); // do not await here
  }

  // Future<void> _playHomeMusic() async {
  //   final urlList = await DataRetriever.getAudioURLByName('sys.ON_SCENE_LOADED.home');
  //   if (urlList == null) return;
  //   await audio.themeOST(urlList.cast<String>());
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: StoryDashboard(storyMetaTableFuture:  DataRetriever.getStoryMetaTable()),
    );
  }
}