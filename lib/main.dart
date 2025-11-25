import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'utils/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await audio.init();
  runApp(const ArknightsStoryApp());
}

class ArknightsStoryApp extends StatelessWidget {
  const ArknightsStoryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ArkStory',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}