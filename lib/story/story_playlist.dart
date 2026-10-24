import '../config/database.dart';
import 'story_script.dart' show storyTxtPath;

class StoryPlaylistEntry {
  const StoryPlaylistEntry({
    required this.scriptURL,
    required this.title,
    this.summary = '',
    this.storyName = '',
    this.storyId = '',
  });
  final String scriptURL;
  final String title;
  final String summary;
  final String storyName;
  final String storyId;

  Map<String, String> toJson() => {
    'script': scriptURL,
    'title': title,
    if (summary.isNotEmpty) 'summary': summary,
    if (storyName.isNotEmpty) 'storyName': storyName,
    if (storyId.isNotEmpty) 'storyId': storyId,
  };

  /// Preserve the review's reading order, including before/after battle pairs.
  static List<StoryPlaylistEntry> fromReview(
    List<dynamic> sections, {
    String archiveName = '',
    String storyId = '',
  }) => [
    for (final section in sections)
      if (section is Map &&
          section['storyTxt'] is String &&
          (section['storyTxt'] as String).trim().isNotEmpty)
        StoryPlaylistEntry(
          summary: section['storyDesc'] as String? ?? '',
          storyName: archiveName,
          storyId: storyId,
          scriptURL:
              '${Database.storyContentPath}${storyTxtPath(section['storyTxt'] as String)}',
          title: [
            section['storyCode'],
            section['storyName'],
            section['avgTag'],
          ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
        ),
  ];
}
