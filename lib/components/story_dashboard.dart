import 'package:arknights_story_app/config/database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'story_entry.dart';
import '../pages/story_review.dart';
import '../utils/data_retriever.dart';

class StoryDashboard extends StatelessWidget {
  final Future<dynamic> storyMetaTableFuture;
  const StoryDashboard({
    super.key,
    required this.storyMetaTableFuture,
  });

  Future<void> onEntryType(BuildContext context, String id) async {
    final url = '${Database.reviewInfoPath}$id.json';
    final storyInfo = await DataRetriever.getJsonFromURL(url);

    if (storyInfo is! Map<String, dynamic>) {
      debugPrint('Failed to load story info from $url');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load story details')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReviewPage(storyInfo: storyInfo),
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
        final ids = table.keys.toList();
        return SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = 16;
                const double padding = 16;
                const int minPerRow = 3;
                final double available =
                    (constraints.maxWidth - padding * 2).clamp(0, double.infinity);
                final double rawTargetWidth =
                    (available - spacing * (minPerRow - 1)) / minPerRow;
                final double cardWidth =
                    rawTargetWidth <= 0 ? 120 : (rawTargetWidth > 250 ? 250 : rawTargetWidth);
                final bool isCompact = cardWidth < 220;
                final double cardHeight =
                    isCompact ? cardWidth * 1.8 : cardWidth * 1.2;

                return Padding(
                  padding: const EdgeInsets.all(padding),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final id in ids)
                        StoryEntry(
                          name: table[id]['name'],
                          kvImage: table[id]['kvImageId'] != null ? NetworkImage(Database.kvImagePath + table[id]['kvImageId']) : null,
                          titleImage: table[id]['type'] != "MAIN_STORY" ? (table[id]['titleImageId'] != null ? NetworkImage(Database.titleImagePath + table[id]['titleImageId']) : null) : null,
                          width: cardWidth,
                          height: cardHeight,
                          onTap: () {
                            onEntryType(context, id.toString());
                          },
                        ),
                    ],
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
