import 'package:flutter/material.dart';
import '../config/archive_style.dart';
import '../downloads/download_service.dart';
import '../downloads/download_task.dart';
import '../pages/settings_page.dart';

class ChapterDownloadButton extends StatelessWidget {
  const ChapterDownloadButton({
    super.key,
    required this.storyId,
    required this.chapters,
    required this.title,
  });
  final String storyId;
  final Map<String, String> chapters;
  final String title;
  @override
  Widget build(BuildContext context) {
    if (!downloadService.supported || chapters.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: downloadService,
      builder: (context, _) {
        final task = downloadService.taskFor(storyId);
        final done = task?.state == DownloadState.complete;
        return TextButton.icon(
          onPressed: () async {
            if (done || task?.active == true) {
              Navigator.of(
                context,
              ).push(archiveRoute(context, (_) => const SettingsPage()));
              return;
            }
            try {
              await downloadService.startStory(storyId, title, chapters);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已加入下载，可在设置中管理')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('无法开始下载：$e')));
              }
            }
          },
          icon: task?.active == true
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: task?.progress,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  done ? Icons.download_done : Icons.download_outlined,
                  size: 20,
                ),
          label: Text(
            done
                ? '已下载'
                : task?.active == true
                ? '下载中'
                : task?.state == DownloadState.paused
                ? '继续下载故事'
                : '下载整个故事',
          ),
        );
      },
    );
  }
}
