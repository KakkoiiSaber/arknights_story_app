import 'package:flutter/material.dart';

import '../config/database.dart';
import '../utils/data_retriever.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
      ),
      body: Padding(
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
                : SingleChildScrollView(
                    child: SelectableText(
                      _content ?? '',
                      style: const TextStyle(height: 1.4),
                    ),
                  )),
      ),
    );
  }
}
