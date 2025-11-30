import 'package:arknights_story_app/config/database.dart';
import 'package:flutter/material.dart';
import 'story_entry.dart';
import '../pages/story_review.dart';

enum StoryTypeFilter { all, main, activity, mini }

class StoryDashboard extends StatelessWidget {
  final Future<dynamic> storyMetaTableFuture;
  final StoryTypeFilter filter;
  const StoryDashboard({
    super.key,
    required this.storyMetaTableFuture,
    this.filter = StoryTypeFilter.all,
  });

  void onEntryTap(BuildContext context, String id, String? titleImageId) {
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => StoryReviewPage(
          storyId: id,
          titleImageId: titleImageId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: storyMetaTableFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final table = snapshot.data;
        if (table == null) {
          return const Center(child: Text('Failed to load stories'));
        }
        final ids = _filteredAndSortedIds(table, filter);
        return SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = 16;
                const double padding = 16;
                const int minPerRow = 3;
                final double available = (constraints.maxWidth - padding * 2)
                    .clamp(0, double.infinity);
                final double rawTargetWidth =
                    (available - spacing * (minPerRow - 1)) / minPerRow;
                final double cardWidth = rawTargetWidth <= 0
                    ? 120
                    : (rawTargetWidth > 250 ? 250 : rawTargetWidth);
                final bool isCompact = cardWidth < 220;
                final double cardHeight = isCompact
                    ? cardWidth * 1.8
                    : cardWidth * 1.2;
                final int columns =
                    ((available + spacing) / (cardWidth + spacing))
                        .floor()
                        .clamp(1, 12);
                final int effectiveColumns = columns < minPerRow
                    ? minPerRow
                    : columns;
                final double contentWidth =
                    effectiveColumns * (cardWidth + spacing) - spacing;

                return Padding(
                  padding: const EdgeInsets.all(padding),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        runAlignment: WrapAlignment.start,
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final id in ids)
                            StoryEntry(
                              name: table[id]['name'],
                              kvImage: table[id]['kvImageId'] != null
                                  ? NetworkImage(
                                      Database.kvImagePath +
                                          table[id]['kvImageId'],
                                    )
                                  : null,
                              titleImage: table[id]['type'] != "MAIN_STORY"
                                  ? (table[id]['titleImageId'] != null
                                        ? NetworkImage(
                                            Database.titleImagePath +
                                                table[id]['titleImageId'],
                                          )
                                        : null)
                                  : null,
                              width: cardWidth,
                              height: cardHeight,
                              onTap: () {
                                onEntryTap(
                                  context,
                                  id.toString(),
                                  table[id]['titleImageId']?.toString(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

List<dynamic> _filteredAndSortedIds(
  Map<dynamic, dynamic> table,
  StoryTypeFilter filter,
) {
  final filtered = table.keys.where((id) {
    final type = table[id]?['type']?.toString() ?? '';
    switch (filter) {
      case StoryTypeFilter.main:
        return type == 'MAIN_STORY';
      case StoryTypeFilter.activity:
        return type == 'ACTIVITY_STORY';
      case StoryTypeFilter.mini:
        return type == 'MINI_STORY';
      case StoryTypeFilter.all:
        return true;
    }
  }).toList();

  filtered.sort((a, b) {
    int safeYear(dynamic v) {
      final raw = v?.toString() ?? '';
      if (raw.contains('-')) {
        final parts = raw.split('-');
        if (parts.isNotEmpty) {
          return int.tryParse(parts[0]) ?? 0;
        }
      }
      return int.tryParse(raw) ?? 0;
    }

    int safeMonth(dynamic v) {
      final raw = v?.toString() ?? '';
      if (raw.contains('-')) {
        final parts = raw.split('-');
        if (parts.length > 1) {
          return int.tryParse(parts[1]) ?? 1;
        }
      }
      return 1;
    }

    final ayyyy = safeYear(table[a]?['startTime']);
    final amm = safeMonth(table[a]?['startTime']);
    final byyyy = safeYear(table[b]?['startTime']);
    final bmm = safeMonth(table[b]?['startTime']);
    final aTime = DateTime(ayyyy, amm);
    final bTime = DateTime(byyyy, bmm);
    return bTime.compareTo(aTime); // newest first
  });

  return filtered;
}
