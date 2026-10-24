import '../story/story_playlist.dart';
import 'reading_library.dart';
import 'account_service.dart';

/// Late events from an outgoing WebView cannot write into another account.
class ReadingSession {
  ReadingSession(
    String script,
    String title,
    String storyId,
    List<StoryPlaylistEntry> playlist,
  ) : scope = readingLibrary.scope,
      chapterCount = playlist.isEmpty ? null : playlist.length {
    for (final entry in playlist) {
      chapters[chapterKey(entry.scriptURL)] = (
        entry.storyId.isEmpty ? storyId : entry.storyId,
        entry.title,
      );
    }
    chapters.putIfAbsent(chapterKey(script), () => (storyId, title));
  }
  final String scope;
  final int? chapterCount;
  final chapters = <String, (String, String)>{};
  void close() {
    readingLibrary.persist();
    accountService.sync(pull: false);
  }

  Map<String, dynamic>? checkpoint(String key) =>
      scope == readingLibrary.scope && chapters.containsKey(key)
      ? readingLibrary.chapter(key)
      : null;
  void progress(Map value) {
    if (scope != readingLibrary.scope) return;
    final entry = chapters[value['chapterId']];
    if (entry == null || entry.$1.isEmpty) return;
    readingLibrary.recordProgress({
      ...value,
      'storyId': entry.$1,
      'title': entry.$2,
      if (chapterCount != null) 'chapterCount': chapterCount,
    });
    if (value['completed'] == true || value['skipped'] == true) {
      accountService.sync(pull: false);
    }
  }
}
