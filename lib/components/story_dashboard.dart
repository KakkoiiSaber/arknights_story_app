import 'package:flutter/material.dart';

import '../config/archive_style.dart';
import '../config/database.dart';
import '../config/story_catalog.dart';
import '../config/story_themes.dart';
import '../pages/story_review.dart';
import 'story_entry.dart';

export '../config/story_catalog.dart' show StoryTypeFilter;

class StoryDashboard extends StatefulWidget {
  const StoryDashboard({
    super.key,
    required this.storyMetaTableFuture,
    this.filter = StoryTypeFilter.all,
    this.query = '',
    this.onStoryClosed,
  });
  final Future<dynamic> storyMetaTableFuture;
  final StoryTypeFilter filter;
  final String query;
  final VoidCallback? onStoryClosed;

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
    return StoryEntry(
      key: ValueKey(id),
      name: story['name'] as String? ?? id,
      kvImage: coverUrl == null ? null : NetworkImage(coverUrl),
      titleImage: titleUrl == null ? null : NetworkImage(titleUrl),
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
            (_) => StoryReviewPage(storyId: id, titleImageId: title),
          ),
        );
        if (mounted) widget.onStoryClosed?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: widget.storyMetaTableFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      final table = snapshot.data;
      if (table is! Map) return const Center(child: Text('故事加载失败，请稍后重试'));
      final ids = storyCatalogIds(table, widget.filter, query: widget.query);
      if (ids.isEmpty) {
        return const Center(
          child: Text('没有匹配的故事', style: TextStyle(color: ArchiveStyle.muted)),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final padding = compact ? 18.0 : 28.0;
          final height = compact
              ? 144.0
              : (constraints.maxWidth * 0.17).clamp(180.0, 260.0);
          return Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 28),
              child: Align(
                alignment: Alignment.topLeft,
                child: Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 14 : 16,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    for (final id in ids)
                      _entry(
                        context,
                        id,
                        table[id] as Map,
                        height,
                        constraints.maxWidth - padding * 2,
                      ),
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
