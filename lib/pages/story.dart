import 'package:flutter/material.dart';

import '../story/event_builder.dart';
import '../story/load_resources.dart';
import '../story/story_models.dart';
import '../utils/audio_manager.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.storyTxtPath});

  final String storyTxtPath;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late Future<List<StoryEvent>> _storyFuture;

  @override
  void initState() {
    super.initState();
    _storyFuture = loadStoryEvents(widget.storyTxtPath);
  }

  @override
  void dispose() {
    // Stop any story-specific playback when leaving this page.
    audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
      ),
      body: FutureBuilder<List<StoryEvent>>(
        future: _storyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load story\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final events = snapshot.data ?? const <StoryEvent>[];
          if (events.isEmpty) {
            return const Center(child: Text('No story content available.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final event = events[index];
              return buildEventWidget(context, event);
            },
          );
        },
      ),
    );
  }
}
