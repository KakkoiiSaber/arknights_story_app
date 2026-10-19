import 'package:flutter/material.dart';
import '../config/database.dart';
import '../story/story_player.dart';
import '../story/story_player_view.dart';
import '../story/story_script.dart';
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
  late Future<StoryPlayer> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StoryPlayer> _load() async {
    final url =
        '${Database.storyContentPath}${storyTxtPath(widget.storyTxtPath)}';
    final text = await DataRetriever.getTextFromURL(url);
    if (text == null) throw Exception('无法获取剧情，请检查网络后重试。');
    final events = const StoryScriptParser().parse(text);
    for (final event in events.where((event) => event.issue != null)) {
      debugPrint('AVG line ${event.lineNumber}: ${event.issue}');
    }
    return StoryPlayer(events);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff090d12),
    body: FutureBuilder<StoryPlayer>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return StoryPlayerView(
            player: snapshot.data!,
            title: [
              widget.storyCode,
              widget.storyName ?? 'Story',
              widget.storyTag,
            ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
          );
        }
        return SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: Center(
                  child: snapshot.hasError
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () =>
                                    setState(() => _future = _load()),
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
