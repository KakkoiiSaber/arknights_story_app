import 'package:flutter/material.dart';
import '../config/config.dart';
import '../config/database.dart';
import '../story/event_builder.dart';
import '../story/story_script.dart';
import '../story/story_preview.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({
    super.key,
    required this.storyTxtPath,
    this.storyName,
    this.storyCode,
    this.storyTag,
  });

  final String storyTxtPath;
  final String? storyName;
  final String? storyCode;
  final String? storyTag;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late Future<List<StoryEvent>> _storyFuture;

  @override
  void initState() {
    super.initState();
    _storyFuture = _loadEvents(widget.storyTxtPath);
  }

  @override
  void dispose() {
    // Stop any story-specific playback when leaving this page.
    audio.stop();
    super.dispose();
  }

  Future<List<StoryEvent>> _loadEvents(String path) async {
    final url = '${Database.storyContentPath}${storyTxtPath(path)}';
    final text = await DataRetriever.getTextFromURL(url);
    if (text == null) {
      throw Exception('Failed to fetch story TXT: $url');
    }
    final events = const StoryScriptParser().parse(text);
    for (final event in events.where((event) => event.issue != null)) {
      debugPrint('AVG line ${event.lineNumber}: ${event.issue}');
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.storyName ?? 'Story', overflow: TextOverflow.ellipsis),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.storyCode != null && widget.storyCode!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      widget.storyCode!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (widget.storyTag != null && widget.storyTag!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.storyTag!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
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
        ],
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

          final sourceEvents = snapshot.data ?? const <StoryEvent>[];
          final events = sourceEvents
              .map(storyPreviewEvent)
              .where((event) => event['type'] != 'unsupported')
              .toList();
          if (events.isEmpty) {
            return const Center(child: Text('No story content available.'));
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Config.layoutSwitchSize),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length + 1,
                separatorBuilder: (context, _) => const SizedBox(height: 0),
                itemBuilder: (context, index) => index == 0
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text('基础文本预览：展示所有分支，暂不播放演出和音频。'),
                      )
                    : _buildEvent(events[index - 1]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'background':
        return storyBackgroundContainer(imagePath: event['image']?.toString());
      case 'image':
        return storyImageContainer(imagePath: event['image']?.toString());
      case 'dialog':
      case 'narration':
        return dialogueContainer(
          speaker: (event['speaker'] ?? '').toString(),
          content: (event['content'] ?? '').toString(),
        );
      case 'decision':
        return dialogueContainer(
          speaker: 'Dr. {@nickname}',
          content: (event['options']?.toString() ?? '')
              .split(';')
              .asMap()
              .entries
              .map((entry) => '${entry.key + 1}. ${entry.value}')
              .join('\n'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
