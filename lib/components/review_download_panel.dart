import 'package:flutter/material.dart';
import '../downloads/review_service.dart';
import '../downloads/download_task.dart' show downloadSize;
import '../utils/audio_manager.dart';

class ReviewDownloadPanel extends StatelessWidget {
  const ReviewDownloadPanel({super.key, this.compact = false, this.onRetry});
  final bool compact;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    if (!reviewAssets.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: reviewAssets,
      builder: (context, _) {
        final service = reviewAssets;
        if (compact) {
          if (!service.checking && !service.running && service.error == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.error != null
                            ? '资源更新暂未完成，可在设置中重试'
                            : service.checking
                            ? service.catalogProgress == null
                                  ? '正在获取故事资源清单…'
                                  : '正在下载故事目录 ${(service.catalogProgress! * 100).round()}% · ${downloadSize(service.catalogDownloadedBytes)} / ${downloadSize(service.catalogTotalBytes)}'
                            : '正在下载${service.selection == 'all' ? '主题资源' : '首页素材'} ${(service.progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    if (service.running)
                      IconButton(
                        iconSize: 18,
                        tooltip: '暂停资源下载',
                        onPressed: service.pause,
                        icon: const Icon(Icons.pause),
                      ),
                    if (service.error != null)
                      TextButton(
                        onPressed: service.checking || service.running
                            ? null
                            : () async {
                                await service.checkForUpdates();
                                onRetry?.call();
                                if (!service.running &&
                                    service.revision != null) {
                                  await service.start(
                                    service.selection ?? 'home',
                                  );
                                }
                              },
                        child: const Text('重试'),
                      ),
                  ],
                ),
                if (service.checking || service.running) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: service.checking
                        ? service.catalogProgress
                        : service.progress,
                    minHeight: 2,
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          );
        }
        final labels = {
          'idle': '待下载',
          'downloading': '下载中',
          'paused': '已暂停',
          'failed': '下载失败',
          'complete': '已完成',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('首页与主题资源', style: TextStyle(fontSize: 21)),
            const SizedBox(height: 12),
            Text(
              '本地占用 ${downloadSize(service.storedBytes)} · 全部资源 ${downloadSize(service.totalBytes)}',
            ),
            const SizedBox(height: 8),
            const Text(
              '首次下载目录与封面，背景和音乐按需保存。每次启动检查数据更新，只下载变更文件；关闭 App 后批量任务暂停。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (service.revision != null)
              Text(
                '数据版本 ${service.revision!.substring(0, service.revision!.length.clamp(0, 12))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Text(
              '${service.selection == 'all' ? '全部主题资源' : '首页素材'} · ${labels[service.state] ?? service.state} · ${service.completeCount}/${service.totalCount}',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: service.progress),
            const SizedBox(height: 8),
            Text(
              '${downloadSize(service.downloadedBytes)} / ${downloadSize(service.selectedBytes)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (service.activeTotalBytes > 0)
              Text(
                '正在获取资源 ${downloadSize(service.activeBytes)} / ${downloadSize(service.activeTotalBytes)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (service.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  service.error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: service.checking || service.clearing
                      ? null
                      : service.checkForUpdates,
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(service.checking ? '检查中…' : '检查更新'),
                ),
                if (service.running)
                  TextButton.icon(
                    onPressed: service.pause,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('暂停'),
                  )
                else ...[
                  TextButton(
                    onPressed: service.revision == null || service.clearing
                        ? null
                        : () => service.start('home'),
                    child: const Text('下载首页素材'),
                  ),
                  TextButton(
                    onPressed: service.revision == null || service.clearing
                        ? null
                        : () => service.start('all'),
                    child: Text(
                      service.selection == 'all' && service.state == 'paused'
                          ? '继续全部下载'
                          : '下载全部主题资源',
                    ),
                  ),
                ],
                TextButton.icon(
                  onPressed: service.clearing || service.checking
                      ? null
                      : () async {
                          await audio.stop();
                          try {
                            await service.clear();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('清理失败：$e')),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(service.clearing ? '清理中…' : '清理主题资源'),
                ),
              ],
            ),
            const Divider(height: 36),
          ],
        );
      },
    );
  }
}
