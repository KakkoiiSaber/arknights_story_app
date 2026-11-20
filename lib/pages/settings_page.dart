import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/archive_style.dart';
import '../downloads/download_service.dart';
import '../downloads/download_task.dart';
import '../story/prts_story_stub.dart'
    if (dart.library.js_interop) '../story/prts_story_web.dart';
import '../utils/audio_manager.dart';
import '../story/story_playlist.dart';
import '../settings/reader_settings_panel.dart';
import '../components/review_download_panel.dart';
import '../config/database.dart';
import '../utils/data_retriever.dart';
import 'account_page.dart';
import 'reading_history_page.dart';

class _StoryDownloadPicker extends StatefulWidget {
  const _StoryDownloadPicker();
  @override
  State<_StoryDownloadPicker> createState() => _StoryDownloadPickerState();
}

class _StoryDownloadPickerState extends State<_StoryDownloadPicker> {
  late Future<dynamic> _catalog = DataRetriever.getJsonFromURL(
    Database.storyMetaTablePath,
  );
  String _query = '';
  String? _preparing;

  Future<void> _download(String id, String title) async {
    if (_preparing != null) return;
    setState(() => _preparing = id);
    try {
      final review = await DataRetriever.getJsonFromURL(Database.detailURL(id));
      if (review is! Map || review['infoUnlockDatas'] is! List) {
        throw StateError('故事目录加载失败，请重试');
      }
      final chapters = StoryPlaylistEntry.fromReview(
        review['infoUnlockDatas'] as List,
      );
      if (chapters.isEmpty) throw StateError('暂无可下载章节');
      await downloadService.startStory(
        'story:${Database.storyContentPath}:$id',
        title,
        {for (final chapter in chapters) chapter.scriptURL: chapter.title},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法开始下载：$error')));
      }
    } finally {
      if (mounted) setState(() => _preparing = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('选择故事下载')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索故事',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<dynamic>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final table = snapshot.data;
              if (table is! Map) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(
                      () => _catalog = DataRetriever.getJsonFromURL(
                        Database.storyMetaTablePath,
                      ),
                    ),
                    child: const Text('目录加载失败，点击重试'),
                  ),
                );
              }
              final stories = table.entries
                  .where(
                    (entry) =>
                        entry.value is Map &&
                        '${(entry.value as Map)['name']} ${entry.key}'
                            .toLowerCase()
                            .contains(_query),
                  )
                  .toList();
              if (stories.isEmpty) return const Center(child: Text('没有匹配的故事'));
              return ListView.builder(
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final entry = stories[index];
                  final id = entry.key.toString();
                  final title = (entry.value as Map)['name']?.toString() ?? id;
                  return ListTile(
                    title: Text(title),
                    trailing: _preparing == id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    enabled: _preparing == null,
                    onTap: () => _download(id, title),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    downloadService.init().catchError((Object _) {});
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  void _openDownloadedStory(ChapterDownload task) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(task.title, style: const TextStyle(fontSize: 20)),
            ),
            for (var i = 0; i < task.scripts.length; i++)
              ListTile(
                title: Text(
                  task.scriptTitles[task.scripts[i]] ?? '第 ${i + 1} 节',
                ),
                trailing: const Icon(Icons.north_east, size: 18),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    archiveRoute(
                      context,
                      (_) => PrtsStoryView(
                        storyId: task.id.split(':').last,
                        scriptURL: task.scripts[i],
                        playlist: [
                          for (final url in task.scripts)
                            StoryPlaylistEntry(
                              scriptURL: url,
                              title: task.scriptTitles[url] ?? task.title,
                            ),
                        ],
                        title: task.scriptTitles[task.scripts[i]] ?? task.title,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  int _section = 0;
  @override
  Widget build(BuildContext context) {
    final labels = ['阅读偏好', '账户与记录', if (!kIsWeb) '首页与主题资源', '故事下载'];
    return Scaffold(
      appBar: AppBar(title: const Text('设置   SETTINGS')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 680;
            final nav = SingleChildScrollView(
              scrollDirection: wide ? Axis.vertical : Axis.horizontal,
              child: Flex(
                direction: wide ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: wide
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        shape: const RoundedRectangleBorder(),
                        foregroundColor: i == _section
                            ? ArchiveStyle.foreground
                            : ArchiveStyle.muted,
                        backgroundColor: i == _section
                            ? const Color(0xff28302f)
                            : Colors.transparent,
                      ),
                      onPressed: () => setState(() => _section = i),
                      child: Text(labels[i]),
                    ),
                ],
              ),
            );
            final content = Expanded(
              child: AnimatedSwitcher(
                duration: ArchiveStyle.motion(context, 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: ListView(
                  key: ValueKey(_section),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  children: switch (labels[_section]) {
                    '阅读偏好' => [const ReaderSettingsPanel()],
                    '首页与主题资源' => [const ReviewDownloadPanel()],
                    '账户与记录' => [
                      const AccountPanel(),
                      ListTile(
                        leading: const Icon(Icons.fact_check_outlined),
                        title: const Text('阅读记录管理'),
                        subtitle: const Text('批量补录已读故事'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          archiveRoute(
                            context,
                            (_) => const ReadingHistoryPage(),
                          ),
                        ),
                      ),
                    ],
                    _ => [
                      ListenableBuilder(
                        listenable: downloadService,
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('故事下载', style: TextStyle(fontSize: 21)),
                            const SizedBox(height: 12),
                            if (!downloadService.supported)
                              const Text(
                                'Web 版使用在线阅读。章节下载仅在 Windows、macOS、iOS 和 Android App 提供。',
                                style: TextStyle(color: ArchiveStyle.muted),
                              )
                            else ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('选择故事下载'),
                                  onPressed: () => Navigator.of(context).push(
                                    archiveRoute(
                                      context,
                                      (_) => const _StoryDownloadPicker(),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '本地占用 ${downloadSize(downloadService.storedBytes)} · ${downloadService.tasks.length} 个故事',
                                style: const TextStyle(
                                  color: ArchiveStyle.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '暂停后保留已完成文件，继续时重新下载未完成文件；关闭 App 后任务暂停。共享资源只保存一份。',
                                style: TextStyle(
                                  color: ArchiveStyle.muted,
                                  fontSize: 12,
                                ),
                              ),
                              if (downloadService.error != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    downloadService.error!,
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              if (downloadService.tasks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Text('暂无下载。点击“选择故事下载”添加离线故事。'),
                                ),
                              for (final task in downloadService.tasks)
                                _task(task),
                            ],
                          ],
                        ),
                      ),
                    ],
                  },
                ),
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 180, child: nav),
                      const VerticalDivider(width: 1),
                      content,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [nav, const Divider(height: 1), content],
                  );
          },
        ),
      ),
    );
  }

  Widget _task(ChapterDownload task) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: ArchiveStyle.line, width: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(task.title, style: const TextStyle(fontSize: 16)),
            ),
            if (task.state == DownloadState.complete)
              IconButton(
                tooltip: '阅读已下载剧情',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () async {
                  await audio.stop();
                  if (!mounted) return;
                  _openDownloadedStory(task);
                },
              ),
            if (task.active)
              IconButton(
                tooltip: '暂停下载',
                onPressed: () => _action(() => downloadService.pause(task.id)),
                icon: const Icon(Icons.pause),
              )
            else if (task.state != DownloadState.complete)
              IconButton(
                tooltip: task.state == DownloadState.failed ? '重试下载' : '继续下载',
                onPressed: () =>
                    _action(() => downloadService.start(task.id, task.title)),
                icon: const Icon(Icons.play_arrow),
              ),
            IconButton(
              tooltip: '删除下载',
              onPressed: () => _action(() => downloadService.remove(task.id)),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Text(
          task.state == DownloadState.preparing
              ? '${task.label} ${task.manifestDone}/${task.scripts.length} 节'
              : '${task.label} · ${task.scripts.length} 节 · ${task.done}/${task.urls.isEmpty ? "—" : task.urls.length} 个资源 · ${downloadSize(task.bytes + task.currentBytes)}',
          style: const TextStyle(color: ArchiveStyle.muted, fontSize: 12),
        ),
        if (task.state != DownloadState.complete) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: task.active ? task.progress : (task.progress ?? 0),
            minHeight: 2,
          ),
        ],
        if (task.currentTotal != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '当前文件 ${downloadSize(task.currentBytes)} / ${downloadSize(task.currentTotal!)}',
              style: const TextStyle(fontSize: 12, color: ArchiveStyle.muted),
            ),
          ),
        if (task.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              task.error!,
              style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          ),
      ],
    ),
  );
}
