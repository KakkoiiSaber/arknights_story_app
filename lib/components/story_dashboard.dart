import 'package:flutter/material.dart';

import '../config/archive_style.dart';
import '../config/database.dart';
import '../config/story_catalog.dart';
import '../config/story_themes.dart';
import '../downloads/review_service.dart';
import '../pages/story_review.dart';
import 'story_entry.dart';
import 'reading_progress.dart';

export '../config/story_catalog.dart' show StoryTypeFilter;

class StoryDashboard extends StatefulWidget {
  const StoryDashboard({
    super.key,
    required this.storyMetaTableFuture,
    this.filter = StoryTypeFilter.all,
    this.query = '',
    this.onStoryClosed,
    this.onRetry,
  });
  final Future<dynamic> storyMetaTableFuture;
  final StoryTypeFilter filter;
  final String query;
  final VoidCallback? onStoryClosed;
  final VoidCallback? onRetry;

  @override
  State<StoryDashboard> createState() => _StoryDashboardState();
}

class _StoryDashboardState extends State<StoryDashboard> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(StoryDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter || oldWidget.query != widget.query) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _entry(
    BuildContext context,
    String id,
    Map story,
    double height,
    double maxWidth,
  ) {
    final theme = StoryThemes.forStory(id, metadata: story);
    final kv = story['kvImageId'] as String?;
    final title = story['titleImageId'] as String?;
    final coverUrl =
        theme?.coverUrl ??
        (kv == null ? null : Database.reviewAssetURL(Database.kvImagePath, kv));
    final main = story['type'] == 'MAIN_STORY';
    final branded =
        theme?.coverContainsTitle ?? story['coverContainsTitle'] == true;
    final titleUrl = main || branded
        ? null
        : theme?.titleUrl ??
              (title == null
                  ? null
                  : Database.reviewAssetURL(Database.titleImagePath, title));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoryEntry(
          key: ValueKey(id),
          framed: main,
          name: story['name'] as String? ?? id,
          kvImage: coverUrl == null ? null : reviewAssets.image(coverUrl),
          titleImage: titleUrl == null ? null : reviewAssets.image(titleUrl),
          height: height,
          maxWidth: maxWidth,
          aspectRatio:
              (story['coverAspectRatio'] as num?)?.toDouble() ??
              (main
                  ? 1
                  : branded
                  ? 2
                  : 632 / 456),
          onTap: () async {
            await Navigator.of(context).push(
              archiveRoute(
                context,
                (_) => StoryReviewPage(
                  storyId: id,
                  titleImageId: title,
                  storyDate: story['startTime']?.toString(),
                  storyType: story['type']?.toString(),
                ),
              ),
            );
            if (mounted) widget.onStoryClosed?.call();
          },
        ),
        const SizedBox(height: 8),
        StoryReadingProgress(storyId: id),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: widget.storyMetaTableFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 16),
              Text('正在加载故事目录…', style: TextStyle(color: ArchiveStyle.muted)),
            ],
          ),
        );
      }
      final table = snapshot.data;
      if (table is! Map) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('故事目录加载失败，请检查网络后重试'),
              if (widget.onRetry != null)
                TextButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试加载'),
                ),
            ],
          ),
        );
      }
      final ids = storyCatalogIds(table, widget.filter, query: widget.query);
      if (ids.isEmpty) {
        return const Center(
          child: Text('没有匹配的故事', style: TextStyle(color: ArchiveStyle.muted)),
        );
      }
      final groups = <String, List<String>>{};
      for (final id in ids) {
        final type = (table[id] as Map)['type']?.toString() ?? 'OTHER';
        groups.putIfAbsent(type, () => []).add(id);
      }
      const headings = {
        'MAIN_STORY': ('主线记录', 'MAIN THEME'),
        'ACTIVITY_STORY': ('活动故事', 'SIDE STORIES'),
        'MINI_STORY': ('故事集', 'STORY COLLECTIONS'),
        'OTHER': ('其他档案', 'OTHER RECORDS'),
      };
      final types = groups.keys.toList()
        ..sort((a, b) {
          int rank(String type) =>
              !['MAIN_STORY', 'ACTIVITY_STORY', 'MINI_STORY'].contains(type)
              ? 3
              : ['MAIN_STORY', 'ACTIVITY_STORY', 'MINI_STORY'].indexOf(type);
          return rank(a).compareTo(rank(b));
        });
      return LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth > 1500
              ? 60.0
              : constraints.maxWidth <= 750
              ? 18.0
              : constraints.maxWidth <= 1050
              ? 24.0
              : 42.0;
          final available = constraints.maxWidth - padding * 2;
          return TweenAnimationBuilder<double>(
            key: ValueKey('${widget.filter}:${widget.query}'),
            tween: Tween(begin: 0, end: 1),
            duration: ArchiveStyle.motion(context, 280),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 10),
                child: child,
              ),
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(padding, 6, padding, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final type in types) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 35,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Color(0x33ffffff)),
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                switch (type) {
                                  'MAIN_STORY' => 'Ⅰ',
                                  'ACTIVITY_STORY' => 'Ⅱ',
                                  'MINI_STORY' => 'Ⅲ',
                                  _ => 'Ⅳ',
                                },
                                style: const TextStyle(
                                  fontFamily: 'Archive Condensed',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xff8a9496),
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Wrap(
                                spacing: 14,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    headings[type]?.$1 ?? '其他档案',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      fontVariations: [
                                        FontVariation('wght', 500),
                                      ],
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  Text(
                                    headings[type]?.$2 ?? 'OTHER RECORDS',
                                    style: const TextStyle(
                                      fontFamily: 'Archive Condensed',
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      color: ArchiveStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${groups[type]!.length.toString().padLeft(2, '0')} ARCHIVES  /  +',
                              style: const TextStyle(
                                fontFamily: 'Archive Condensed',
                                fontSize: 10,
                                letterSpacing: 1,
                                color: ArchiveStyle.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final main = type == 'MAIN_STORY';
                          final columns = constraints.maxWidth <= 750
                              ? (main ? 3 : 2)
                              : main
                              ? 6
                              : constraints.maxWidth >= 1500
                              ? 4
                              : 3;
                          final gap = constraints.maxWidth <= 750
                              ? (main ? 14.0 : 12.0)
                              : main
                              ? (constraints.maxWidth >= 1500
                                    ? 30.0
                                    : constraints.maxWidth <= 1050
                                    ? 15.0
                                    : 22.0)
                              : 24.0;
                          final width =
                              (available - gap * (columns - 1)) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: 24,
                            children: [
                              for (final id in groups[type]!)
                                SizedBox(
                                  width: width,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          main
                                              ? 'EP / ${id.replaceFirst('main_', '').padLeft(2, '0')}'
                                              : '${table[id]['startTime'] ?? ''}'
                                                    .replaceAll('-', ' / '),
                                          style: const TextStyle(
                                            fontFamily: 'Archive Condensed',
                                            fontSize: 9,
                                            letterSpacing: 1.08,
                                            color: ArchiveStyle.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 9),
                                        Align(
                                          alignment: Alignment.center,
                                          child: _entry(
                                            context,
                                            id,
                                            table[id] as Map,
                                            main
                                                ? width - 8
                                                : (width - 8) * 456 / 632,
                                            width - 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
