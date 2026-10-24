import 'package:flutter/material.dart';

import '../config/archive_style.dart';

class StoryChapterEntry extends StatelessWidget {
  const StoryChapterEntry({
    super.key,
    required this.name,
    required this.description,
    required this.onTap,
    this.code,
    this.tag,
    this.last = false,
    this.compact = false,
    this.progressLabel,
    this.isRead = false,
    this.onMarkRead,
  });

  final String name;
  final String description;
  final String? code;
  final String? tag;
  final VoidCallback? onTap;
  final bool last;
  final bool compact;
  final String? progressLabel;
  final bool isRead;
  final ValueChanged<bool>? onMarkRead;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: const BorderSide(color: ArchiveStyle.line, width: 0.5),
        bottom: last
            ? const BorderSide(color: ArchiveStyle.line, width: 0.5)
            : BorderSide.none,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (code?.isNotEmpty == true) ...[
                Text(
                  code!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ArchiveStyle.muted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (tag?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        tag!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ArchiveStyle.muted,
                        ),
                      ),
                    ),
                  const SizedBox(width: 14),
                  if (progressLabel != null) ...[
                    Text(
                      progressLabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ArchiveStyle.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                    Icons.north_east,
                    size: 18,
                    color: onTap == null
                        ? ArchiveStyle.muted
                        : ArchiveStyle.foreground,
                  ),
                  if (onMarkRead != null)
                    PopupMenuButton<bool>(
                      tooltip: '阅读状态',
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: onMarkRead,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: !isRead,
                          child: Text(isRead ? '标记未读' : '标记已读'),
                        ),
                      ],
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    height: 1.75,
                    color: const Color(0xffc7cbd0),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
