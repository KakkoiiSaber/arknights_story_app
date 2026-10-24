import 'dart:async';
import 'package:flutter/material.dart';
import '../account/account_service.dart';
import '../account/reading_library.dart';
import '../components/reading_progress.dart';
import '../config/database.dart';
import '../utils/data_retriever.dart';

/// Bulk import for readers who already finished stories outside ArkStory.
class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key, this.loadJson, this.library, this.sync});
  final Future<dynamic> Function(String)? loadJson;
  final ReadingLibrary? library;
  final Future<void> Function()? sync;
  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  ReadingLibrary get _library => widget.library ?? readingLibrary;
  late Future<dynamic> _catalog;
  final _selected = <String>{};
  String _query = '';
  String? _error;
  bool _busy = false;
  int _prepared = 0;
  Future<dynamic> _load(String url) =>
      (widget.loadJson ?? DataRetriever.getJsonFromURL)(url);
  @override
  void initState() {
    super.initState();
    _catalog = _load(Database.storyMetaTablePath);
  }

  Future<void> _mark(bool read) async {
    if (_busy || _selected.isEmpty) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(read ? '批量标记已读？' : '批量标记未读？'),
        content: Text('将更新 ${_selected.length} 个故事的全部章节。实际阅读位置与分支选择会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final scope = _library.scope;
    final ids = _selected.toList();
    setState(() {
      _busy = true;
      _prepared = 0;
      _error = null;
    });
    try {
      final prepared = <String, Map<String, String>>{};
      var next = 0;
      Future<void> worker() async {
        while (next < ids.length) {
          final id = ids[next++];
          final data = await _load('${Database.reviewInfoPath}$id.json');
          final chapters = reviewChapterTitles(data);
          if (chapters.isEmpty) throw StateError('部分故事目录加载失败，请重试；本次尚未修改记录。');
          prepared[id] = chapters;
          if (mounted) setState(() => _prepared++);
        }
      }

      await Future.wait(List.generate(ids.length.clamp(1, 4), (_) => worker()));
      if (!mounted) return;
      if (scope != _library.scope) throw StateError('账号已切换，请重新选择故事。');
      // Prepare every catalog first, so a failed request cannot half-import.
      for (final entry in prepared.entries) {
        _library.registerStory(entry.key, entry.value.keys);
        _library.markChapters(
          entry.key,
          entry.value,
          read,
          chapterCount: entry.value.length,
        );
      }
      await _library.persist();
      unawaited((widget.sync ?? accountService.sync)());
      if (!mounted) return;
      setState(_selected.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已将 ${ids.length} 个故事标记为${read ? '已读' : '未读'}。登录后自动同步。',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : '目录加载失败，请重试；本次尚未修改记录。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('阅读记录管理')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: TextField(
            enabled: !_busy,
            decoration: const InputDecoration(
              hintText: '搜索故事',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text('勾选你已读过的故事进行补录；不会改变实际阅读位置。'),
        ),
        if (_busy) ...[
          LinearProgressIndicator(value: _prepared / _selected.length),
          Text('正在准备目录 $_prepared / ${_selected.length}'),
        ],
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data is! Map) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(
                      () => _catalog = _load(Database.storyMetaTablePath),
                    ),
                    child: const Text('目录加载失败，点击重试'),
                  ),
                );
              }
              final entries = (snapshot.data as Map).entries
                  .where(
                    (e) =>
                        e.value is Map &&
                        '${(e.value as Map)['name']} ${e.key}'
                            .toLowerCase()
                            .contains(_query),
                  )
                  .toList();
              if (entries.isEmpty) return const Center(child: Text('没有匹配的故事'));
              return Column(
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _selected.addAll(
                                  entries.map((e) => e.key.toString()),
                                ),
                              ),
                        child: const Text('选择搜索结果'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(_selected.clear),
                        child: const Text('清空选择'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final id = entry.key.toString();
                        return CheckboxListTile(
                          title: Text(
                            (entry.value as Map)['name']?.toString() ?? id,
                          ),
                          subtitle: StoryReadingProgress(
                            storyId: id,
                            library: _library,
                          ),
                          value: _selected.contains(id),
                          onChanged: _busy
                              ? null
                              : (checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('已选 ${_selected.length} 个故事'),
                OutlinedButton(
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : () => _mark(false),
                  child: const Text('标记未读'),
                ),
                FilledButton(
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : () => _mark(true),
                  child: const Text('标记已读'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Map<String, String> reviewChapterTitles(dynamic review) => {
  if (review is Map && review['infoUnlockDatas'] is List)
    for (final chapter in review['infoUnlockDatas'] as List)
      if (chapter is Map &&
          chapter['storyTxt'] is String &&
          (chapter['storyTxt'] as String).isNotEmpty)
        chapter['storyTxt'] as String: [
          chapter['storyCode'],
          chapter['storyName'],
          chapter['avgTag'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
};
