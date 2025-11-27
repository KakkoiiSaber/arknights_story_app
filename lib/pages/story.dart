import 'package:flutter/material.dart';

import '../config/database.dart';
import '../utils/data_retriever.dart';
import '../story/story_models.dart';
import '../story/story_parser.dart';

class StoryPage extends StatefulWidget {
  final String storyTxt;
  const StoryPage({super.key, required this.storyTxt});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  bool _loading = true;
  String? _error;
  String? _content;
  StoryParseResult? _parsed;
  String? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  String _resolveStoryUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final withExt = trimmed.endsWith('.txt') ? trimmed : '$trimmed.txt';
    return '${Database.storyContentPath}$withExt';
  }

  Future<void> _loadStory() async {
    final url = _resolveStoryUrl(widget.storyTxt);
    try {
      final text = await DataRetriever.getTextFromURL(url);
      if (text == null) throw Exception('Failed to load story text');
      if (!mounted) return;
      setState(() {
        _content = text;
        _parsed = StoryParser.parse(text);
        _backgroundImage = _firstBackground(_parsed);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _content = null;
        _loading = false;
        _error = 'Failed to load story';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundImage;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (bg != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('${Database.backgroundPath}$bg'),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: _buildParsedContent(),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedContent() {
    final parsed = _parsed;
    if (parsed == null || parsed.lines.isEmpty) {
      return SingleChildScrollView(
        child: SelectableText(
          _content ?? '',
          style: const TextStyle(height: 1.4),
        ),
      );
    }

    return ListView.separated(
      itemCount: parsed.lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final line = parsed.lines[index];
        switch (line.type) {
          case StoryLineType.dialogue:
            return _DialogueLine(
              speaker: line.speaker ?? '',
              text: line.text,
            );
          case StoryLineType.directive:
            return _DirectiveLine(text: line.text);
          case StoryLineType.narration:
            return _NarrationLine(text: line.text);
        }
      },
    );
  }

  String? _firstBackground(StoryParseResult? parsed) {
    if (parsed == null) return null;
    for (final action in parsed.actions) {
      if (action.type == StoryActionType.background) {
        final img = action.payload['image']?.toString();
        if (img != null && img.isNotEmpty) return img;
      }
    }
    return null;
  }
}

class _DialogueLine extends StatelessWidget {
  const _DialogueLine({required this.speaker, required this.text});
  final String speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            '$speaker:',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 8,
          child: SelectableText(
            text,
            style: const TextStyle(height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _NarrationLine extends StatelessWidget {
  const _NarrationLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: const TextStyle(height: 1.35),
    );
  }
}

class _DirectiveLine extends StatelessWidget {
  const _DirectiveLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      '[$text]',
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
        fontSize: 12,
      ),
    );
  }
}
