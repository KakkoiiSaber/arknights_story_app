import 'package:flutter/material.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class StoryReviewPage extends StatefulWidget {
  final Map<String, dynamic> storyInfo;
  const StoryReviewPage({super.key, required this.storyInfo});

  @override
  State<StoryReviewPage> createState() => _StoryReviewPageState();
}

class _StoryReviewPageState extends State<StoryReviewPage> {
  late final String id   = widget.storyInfo['id'] as String? ?? '';
  late final String name = widget.storyInfo['name'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    // _playThemeOST();
  }

  // Future<void> _playThemeOST() async {
  //   final urlList = await DataRetriever.getAudioURLByName('sys.ON_ACTIVITY_LOADED.' + id);
  //   if (urlList == null) return;
  //   await audio.themeOST(urlList.cast<String>());
  // }

  @override
  void dispose() {
    // Stop page-specific music when leaving (remove if you want continuous music)
    audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$id  $name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $id', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Name: $name', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}