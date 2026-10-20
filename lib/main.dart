import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'utils/audio_manager.dart';
import 'config/story_themes.dart';
import 'config/archive_style.dart';
import 'downloads/download_service.dart';
import 'settings/reader_settings.dart';
import 'downloads/review_service.dart';
import 'pages/startup_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArknightsStoryApp());
}

Future<void> initializeApp(ValueChanged<String> status) async {
  status('正在读取阅读设置');
  await readerSettings.init().timeout(const Duration(seconds: 10));
  status('正在检查本地资源');
  await reviewAssets.init().timeout(const Duration(seconds: 20));
  status('正在准备故事主题');
  await StoryThemes.load().timeout(const Duration(seconds: 10));
  status('正在初始化音频');
  // Audio availability must not prevent the archive from opening.
  try {
    await audio.init().timeout(const Duration(seconds: 8));
  } catch (error) {
    debugPrint('Audio startup unavailable: $error');
  }
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
      home: StartupPage(
        initialize: initializeApp,
        childBuilder: (_) => const HomePage(),
      ),
    );
  }
}
