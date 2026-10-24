import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import '../config/database.dart';
import '../story/story_script.dart' as script;
import '../story/basic_story_reader.dart';
import '../story/story_playlist.dart';
import '../story/prts_story_stub.dart'
    if (dart.library.js_interop) '../story/prts_story_web.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({
    super.key,
    required this.storyTxtPath,
    this.storyName,
    this.storyCode,
    this.storyTag,
    this.playlist = const [],
    this.storyId = '',
  });
  final String storyTxtPath;
  final String? storyName;
  final String? storyCode;
  final String? storyTag;
  final List<StoryPlaylistEntry> playlist;
  final String storyId;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff090d12),
    body: !kIsWeb && defaultTargetPlatform == TargetPlatform.linux
        ? BasicStoryReader(
            storyId: storyId,
            scriptURL:
                '${Database.storyContentPath}${script.storyTxtPath(storyTxtPath)}',
            title: [
              storyCode,
              storyName ?? 'Story',
              storyTag,
            ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
          )
        : PrtsStoryView(
            storyId: storyId,
            playlist: playlist,
            scriptURL:
                '${Database.storyContentPath}${script.storyTxtPath(storyTxtPath)}',
            title: [
              storyCode,
              storyName ?? 'Story',
              storyTag,
            ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
          ),
  );
}
