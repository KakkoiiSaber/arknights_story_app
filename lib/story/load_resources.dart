import '../config/database.dart';
import '../utils/data_retriever.dart';
import 'story_models.dart';

String _toJsonPath(String storyTxtPath) {
  final trimmed = storyTxtPath.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('storyTxtPath cannot be empty');
  }

  final withoutLeadingSlash =
      trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  if (withoutLeadingSlash.endsWith('.json')) return withoutLeadingSlash;
  if (withoutLeadingSlash.endsWith('.txt')) {
    return withoutLeadingSlash.replaceRange(
      withoutLeadingSlash.length - 4,
      withoutLeadingSlash.length,
      '.json',
    );
  }
  return '$withoutLeadingSlash.json';
}

Future<List<StoryEvent>> loadStoryEvents(String storyTxtPath) async {
  final jsonPath = _toJsonPath(storyTxtPath);
  final url = '${Database.storyContentPath}$jsonPath';

  final data = await DataRetriever.getJsonFromURL(url);
  if (data is! List) {
    throw Exception('Unexpected story format from $url');
  }

  return data
      .whereType<Map>()
      .map((e) => StoryEvent.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
