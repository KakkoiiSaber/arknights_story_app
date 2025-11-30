import 'package:flutter/material.dart';
import '../config/config.dart';
import '../config/database.dart';
import '../story/event_builder.dart';
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
  late Future<List<Map<String, dynamic>>> _storyFuture;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storyName ?? 'Story',
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.storyCode != null && widget.storyCode!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      widget.storyCode!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (widget.storyTag != null && widget.storyTag!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.storyTag!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white),
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

          String? lastSpeaker;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Config.layoutSwitchSize),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (context, _) => const SizedBox(height: 0),
                itemBuilder: (context, index) =>
                    _buildEvent(events[index], () => lastSpeaker, (v) {
                  lastSpeaker = v;
                }),
              ),
            ),
          );
      },
    ),
  );
}

  Widget _buildEvent(
    Map<String, dynamic> event,
    String? Function() getLastSpeaker,
    void Function(String?) setLastSpeaker,
  ) {
    final type = (event['type'] ?? '').toString();
    if (type == "decision"){
      event['speaker'] = "Dr. {@name}";
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
        final showSpeaker =
            nextSpeaker.isNotEmpty && nextSpeaker != getLastSpeaker();
        if (showSpeaker) {
          setLastSpeaker(nextSpeaker);
        }
        return dialogueContainer(
          speaker: showSpeaker ? nextSpeaker : '',
          content: (event['content'] ?? '').toString(),
        );
      case 'decision':
        final nextSpeaker = (event['speaker'] ?? '').toString();
        final showSpeaker =
            nextSpeaker.isNotEmpty && nextSpeaker != getLastSpeaker();
        if (showSpeaker) {
          setLastSpeaker(nextSpeaker);
        }
        return decisionContainer(
          speaker: (event['speaker'] ?? '').toString(),
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
    audio.playSoundSingle('${Database.storyMusicPath}$key', volume: volume);
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
