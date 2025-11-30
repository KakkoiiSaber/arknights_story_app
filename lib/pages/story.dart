import 'package:flutter/material.dart';
import '../config/config.dart';
import '../config/database.dart';
import '../story/event_builder.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.storyTxtPath});

  final String storyTxtPath;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late Future<List<Map<String, dynamic>>> _storyFuture;
  String? _currentSpeaker;

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

  Future<List<Map<String, dynamic>>> _loadEvents(String storyTxtPath) async {
    final jsonPath = _toJsonPath(storyTxtPath);
    final url = '${Database.storyContentPath}$jsonPath';
    final data = await DataRetriever.getJsonFromURL(url);
    if (data is! List) {
      throw Exception('Unexpected story format');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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

          final events = snapshot.data ?? const <Map<String, dynamic>>[];
          if (events.isEmpty) {
            return const Center(child: Text('No story content available.'));
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Config.layoutSwitchSize),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (context, _) => const SizedBox(height: 0),
                itemBuilder: (context, index) => _buildEvent(events[index]),
              ),
            ),
          );
      },
    ),
  );
}

  Widget _buildEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    if (type == "decision"){
      event['speaker'] = "Dr. {@nickname}";
    }
    switch (type) {
      case 'background':
      // case 'background_tween':
        return storyBackgroundContainer(
          imagePath: event['image']?.toString(),
          fadetime: event['fadetime']?.toString(),
        );
      case 'image':
      // case 'image_tween':
      // case 'character_cutin':
        return storyImageContainer(
          imagePath: event['image']?.toString(),
          fadetime: event['fadetime']?.toString(),
        );
      // case 'character':
      // // case 'charslot':
      //   final name = event['name']?.toString() ?? '';
      //   if (name.isEmpty) return const SizedBox.shrink();
      //   return storyCharacterContainer(name: name);
      case 'dialog':
      case 'narration':
      // case 'subtitle':
        final nextSpeaker = (event['speaker'] ?? '').toString();
        String? displaySpeaker;
        if (nextSpeaker.isNotEmpty && nextSpeaker != _currentSpeaker) {
          _currentSpeaker = nextSpeaker;
          displaySpeaker = nextSpeaker;
        }
        return dialogueContainer(
          speaker: displaySpeaker ?? '',
          content: (event['content'] ?? '').toString(),
        );
      case 'decision':
        final nextSpeaker = (event['speaker'] ?? '').toString();
        if (nextSpeaker.isNotEmpty && nextSpeaker != _currentSpeaker) {
          _currentSpeaker = nextSpeaker;
        }
        return decisionContainer(
          options: event['options']?.toString() ?? '',
          onOptionSelected: (idx) {
            // Handle decision selection here.
          },
        );
      case 'play_music':
        _handlePlayMusic(event);
        return const SizedBox.shrink();
      case 'stop_music':
        _handleStopMusic(event);
        return const SizedBox.shrink();
      case 'play_sound':
        _handlePlaySound(event);
        return const SizedBox.shrink();
      default:
        // return debugContainer(content:  event.toString(),);
        return const SizedBox.shrink();
    }
  }

  void _handlePlayMusic(Map<String, dynamic> event) {
    final intro = event['intro']?.toString();
    final loop = event['key']?.toString();
    final volume = double.tryParse(event['volume']?.toString() ?? '');
    if (volume != null) {
      audio.setVolume(volume);
    }
    if (intro != null && loop != null) {
      audio.intro2loop(
        '${Database.storyMusicPath}$intro',
        '${Database.storyMusicPath}$loop',
      );
    } else if (loop != null) {
      audio.loop('${Database.storyMusicPath}$loop');
    } else if (intro != null) {
      audio.intro('${Database.storyMusicPath}$intro');
    }
  }

  void _handleStopMusic(Map<String, dynamic> event) {
    audio.stop();
  }

  void _handlePlaySound(Map<String, dynamic> event) {
    final key = event['key']?.toString();
    final volume = double.tryParse(event['volume']?.toString() ?? '');
    if (key == null) return;
    audio.playSound('${Database.storyMusicPath}$key', volume: volume);
  }
}

String _toJsonPath(String storyTxtPath) {
  final trimmed = storyTxtPath.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('storyTxtPath cannot be empty');
  }

  final withoutLeadingSlash =
      trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  if (withoutLeadingSlash.endsWith('.json')) return withoutLeadingSlash;
  if (withoutLeadingSlash.endsWith('.txt')) {
    return withoutLeadingSlash.replaceRange(
      withoutLeadingSlash.length - 4,
      withoutLeadingSlash.length,
      '.json',
    );
  }
  return '$withoutLeadingSlash.json';
}
