import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'utils/audio_manager.dart';
import 'config/story_themes.dart';
import 'config/archive_style.dart';
import 'downloads/download_service.dart';
import 'settings/reader_settings.dart';
import 'downloads/review_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await readerSettings.init();
  await reviewAssets.init();
  await audio.init();
  await StoryThemes.load();
  runApp(const ArknightsStoryApp());
  reviewAssets.checkForUpdates().catchError((Object _) {});
  downloadService.init().catchError((Object _) {});
}

class ArknightsStoryApp extends StatefulWidget {
  const ArknightsStoryApp({super.key});
  @override
  State<ArknightsStoryApp> createState() => _ArknightsStoryAppState();
}

class _ArknightsStoryAppState extends State<ArknightsStoryApp> {
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        reviewAssets.checkForUpdates().catchError((Object _) {});
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

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
