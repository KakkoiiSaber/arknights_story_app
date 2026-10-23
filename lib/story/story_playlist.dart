import '../config/database.dart';
import 'story_script.dart' show storyTxtPath;

class StoryPlaylistEntry {
  const StoryPlaylistEntry({
    required this.scriptURL,
    required this.title,
    this.summary = '',
    this.storyName = '',
  });
  final String scriptURL;
  final String title;
  final String summary;
  final String storyName;

  Map<String, String> toJson() => {
    'script': scriptURL,
    'title': title,
    if (summary.isNotEmpty) 'summary': summary,
    if (storyName.isNotEmpty) 'storyName': storyName,
  };

  /// Preserve the review's reading order, including before/after battle pairs.
  static List<StoryPlaylistEntry> fromReview(
    List<dynamic> sections, {
    String archiveName = '',
  }) => [
    for (final section in sections)
      if (section is Map &&
          section['storyTxt'] is String &&
          (section['storyTxt'] as String).trim().isNotEmpty)
        StoryPlaylistEntry(
          summary: section['storyDesc'] as String? ?? '',
          storyName: archiveName,
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
