import 'package:flutter/material.dart';
import '../utils/data_retriever.dart';
import 'story_player.dart';
import 'story_player_view.dart';
import 'story_script.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../account/reading_library.dart';

/// Keep Linux's existing Flutter reader until a supported WebView is available.
class BasicStoryReader extends StatefulWidget {
  const BasicStoryReader({
    super.key,
    required this.scriptURL,
    required this.title,
    this.storyId = '',
  });
  final String scriptURL;
  final String title;
  final String storyId;
  @override
  State<BasicStoryReader> createState() => _BasicStoryReaderState();
}

class _BasicStoryReaderState extends State<BasicStoryReader> {
  late Future<StoryPlayer> _future;
  late final String _scope;
  String _hash = '';
  int _total = 0;
  final _choices = <Map<String, int>>[];
  @override
  void initState() {
    super.initState();
    _scope = readingLibrary.scope;
    _future = _load();
  }

  Future<StoryPlayer> _load() async {
    final text = await DataRetriever.getTextFromURL(widget.scriptURL);
    if (text == null) throw StateError('无法加载剧情，请检查网络后重试');
    _hash = sha256
        .convert(utf8.encode(text.replaceAll(RegExp(r'\r\n?'), '\n')))
        .toString();
    final player = StoryPlayer(const StoryScriptParser().parse(text));
    _total = text.replaceAll(RegExp(r'\r\n?'), '\n').split('\n').length;
    final checkpoint = readingLibrary.chapter(widget.scriptURL);
    if (mounted &&
        checkpoint != null &&
        checkpoint['atEnd'] != true &&
        (checkpoint['atEnd'] != null || checkpoint['completed'] != true) &&
        checkpoint['scriptHash'] == _hash &&
        checkpoint['line'] is int) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('继续上次阅读？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('从头阅读'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续阅读'),
            ),
          ],
        ),
      );
      if (resume == true) {
        final selections = {
          for (final c
              in (checkpoint['choices'] as List? ?? []).whereType<Map>())
            c['decisionId']: c['optionIndex'],
        };
        for (var i = 0; i <= player.events.length && !player.ended; i++) {
          if (player.lineNumber == checkpoint['line']) break;
          if (player.choices.isNotEmpty) {
            final option = (selections[player.lineNumber] as int? ?? 0).clamp(
              0,
              player.choices.length - 1,
            );
            _choices.add({
              'decisionId': player.lineNumber,
              'optionIndex': option,
            });
            player.choose(option);
          } else {
            player.advance();
          }
        }
      }
    }
    _save(player);
    return player;
  }

  void _save(StoryPlayer player) {
    if (!mounted || _scope != readingLibrary.scope || widget.storyId.isEmpty) {
      return;
    }
    readingLibrary.recordProgress({
      'storyId': widget.storyId,
      'chapterId': chapterKey(widget.scriptURL),
      'title': widget.title,
      'line': player.lineNumber,
      'total': _total,
      'choices': List.of(_choices),
      'scriptHash': _hash,
      'completed': player.ended,
      'atEnd': player.ended,
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StoryPlayer>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return StoryPlayerView(
          player: snapshot.data!,
          title: widget.title,
          onPositionChanged: () => _save(snapshot.data!),
          onRestart: _choices.clear,
          onChoice: (line, option) =>
              _choices.add({'decisionId': line, 'optionIndex': option}),
        );
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
