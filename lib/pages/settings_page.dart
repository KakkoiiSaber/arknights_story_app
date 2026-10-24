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
import 'account_page.dart';
import 'reading_history_page.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListenableBuilder(
      listenable: downloadService,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          const AccountPanel(),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('阅读记录管理'),
            subtitle: const Text('批量补录已读故事'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(archiveRoute(context, (_) => const ReadingHistoryPage())),
          ),
          const ReaderSettingsPanel(),
          const ReviewDownloadPanel(),
          const Text('故事下载', style: TextStyle(fontSize: 21)),
          const SizedBox(height: 12),
          if (!downloadService.supported)
            const Text(
              'Web 版使用在线阅读。章节下载仅在 Windows、macOS、iOS 和 Android App 提供。',
              style: TextStyle(color: ArchiveStyle.muted),
            )
          else ...[
            Text(
              '本地占用 ${downloadSize(downloadService.storedBytes)} · ${downloadService.tasks.length} 个故事',
              style: const TextStyle(color: ArchiveStyle.muted),
            ),
            const SizedBox(height: 8),
            const Text(
              '暂停后保留已完成文件，继续时重新下载未完成文件；关闭 App 后任务暂停。共享资源只保存一份。',
              style: TextStyle(color: ArchiveStyle.muted, fontSize: 12),
            ),
            if (downloadService.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  downloadService.error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            const SizedBox(height: 20),
            if (downloadService.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('暂无下载。可在故事介绍页下载整个故事。'),
              ),
            for (final task in downloadService.tasks) _task(task),
          ],
        ],
      ),
    ),
  );
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
