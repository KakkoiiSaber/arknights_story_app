import 'package:flutter/material.dart';
import '../account/reading_library.dart';
import '../config/archive_style.dart';

class StoryReadingProgress extends StatelessWidget {
  const StoryReadingProgress({super.key, required this.storyId});
  final String storyId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: readingLibrary,
    builder: (context, _) {
      final total = readingLibrary.totalFor(storyId);
      final done = readingLibrary.completedFor(storyId);
      final started = readingLibrary.resume(storyId) != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (started && total != null && total > 0) ...[
            LinearProgressIndicator(
              value: (done / total).clamp(0, 1),
              minHeight: 2,
              color: ArchiveStyle.accent,
              backgroundColor: ArchiveStyle.line,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            !started
                ? '未读'
                : total == null
                ? '已读 $done 节'
                : '已读 $done / $total 节',
            style: const TextStyle(fontSize: 10, color: ArchiveStyle.muted),
          ),
        ],
      );
    },
  );
}

String chapterProgressLabel(String script) {
  final value = readingLibrary.chapter(script);
  if (value == null) return '未读';
  if (value['completed'] == true) return value['atEnd'] == false ? '重读中' : '已读';
  if (value['skipped'] == true) return '已跳过';
  return '阅读中 ${(((value['furthest'] as num?) ?? 0) * 100).floor().clamp(0, 99)}%';
}
