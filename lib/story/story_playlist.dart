import '../config/database.dart';
import 'story_script.dart' show storyTxtPath;

class StoryPlaylistEntry {
  const StoryPlaylistEntry({required this.scriptURL, required this.title});
  final String scriptURL;
  final String title;

  Map<String, String> toJson() => {'script': scriptURL, 'title': title};

  /// Preserve the review's reading order, including before/after battle pairs.
  static List<StoryPlaylistEntry> fromReview(List<dynamic> sections) => [
    for (final section in sections)
      if (section is Map &&
          section['storyTxt'] is String &&
          (section['storyTxt'] as String).trim().isNotEmpty)
        StoryPlaylistEntry(
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
