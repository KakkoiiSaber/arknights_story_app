import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'utils/audio_manager.dart';
import 'config/story_themes.dart';
import 'config/archive_style.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await audio.init();
  await StoryThemes.load();
  runApp(const ArknightsStoryApp());
}

class ArknightsStoryApp extends StatelessWidget {
  const ArknightsStoryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ArkStory',
      theme: ArchiveStyle.theme,
      home: const HomePage(),
    );
  }
}
