import 'package:arknights_story_app/config/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'story_entry.dart';
import '../pages/story_review.dart';

class StoryDashboard extends StatelessWidget {
  final Future<dynamic> storyMetaTableFuture;
  const StoryDashboard({
    super.key,
    required this.storyMetaTableFuture,
  });
  void onEntryType(BuildContext context, dynamic storyInfo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryReviewPage(storyInfo: storyInfo,),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final id in ids)
                    StoryEntry(
                      name: table[id]['name'],
                      kvImage: NetworkImage(Database.assetsSourceURL + "/" + Database.kvImagePath + "/" + table[id]['kvImageId']),
                      titleImage: table[id]['entryType'] != "MAINLINE" ? NetworkImage(Database.assetsSourceURL + "/" + Database.titleImagePath + "/" + table[id]['titleImageId']) : null,
                      onTap: () => onEntryType(context, table[id]),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
