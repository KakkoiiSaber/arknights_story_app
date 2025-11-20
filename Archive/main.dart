import 'package:flutter/material.dart';
import 'utils/audio_manager.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioManager().init(
    volume: 0.5,
    crossFade: const Duration(milliseconds: 500),
  );
  runApp(const ArknightsStoryApp());
}



class ArknightsStoryApp extends StatelessWidget {
  const ArknightsStoryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arknights Story',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}
