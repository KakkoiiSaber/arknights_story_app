import 'package:flutter/material.dart';
import '../utils/data_retriever.dart';
import 'story_player.dart';
import 'story_player_view.dart';
import 'story_script.dart';

/// Keep Linux's existing Flutter reader until a supported WebView is available.
class BasicStoryReader extends StatefulWidget {
  const BasicStoryReader({
    super.key,
    required this.scriptURL,
    required this.title,
  });
  final String scriptURL;
  final String title;
  @override
  State<BasicStoryReader> createState() => _BasicStoryReaderState();
}

class _BasicStoryReaderState extends State<BasicStoryReader> {
  late Future<StoryPlayer> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StoryPlayer> _load() async {
    final text = await DataRetriever.getTextFromURL(widget.scriptURL);
    if (text == null) throw StateError('无法加载剧情，请检查网络后重试');
    return StoryPlayer(const StoryScriptParser().parse(text));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StoryPlayer>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return StoryPlayerView(player: snapshot.data!, title: widget.title);
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: snapshot.hasError
              ? TextButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('加载失败，点击重试'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
