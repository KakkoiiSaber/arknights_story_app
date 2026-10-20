enum StoryTypeFilter { all, main, activity, mini, collaboration }

const collaborationStoryIds = {
  'act17d0',
  'act24side',
  'act32side',
  'act36side',
  'act45side',
  'act13mini',
  'act50side',
  'act54side',
};

bool isCollaborationStory(String id, Map story) =>
    collaborationStoryIds.contains(id) || story['isCollaboration'] == true;

List<String> storyCatalogIds(
  Map table,
  StoryTypeFilter filter, {
  String query = '',
}) {
  final search = query.trim().toLowerCase();
  final ids = table.keys.map((id) => id.toString()).where((id) {
    final story = table[id];
    if (story is! Map) return false;
    final collab = isCollaborationStory(id, story);
    final matches = switch (filter) {
      StoryTypeFilter.collaboration => collab,
      StoryTypeFilter.all => !collab,
      StoryTypeFilter.main => !collab && story['type'] == 'MAIN_STORY',
      StoryTypeFilter.activity => !collab && story['type'] == 'ACTIVITY_STORY',
      StoryTypeFilter.mini => !collab && story['type'] == 'MINI_STORY',
    };
    return matches &&
        (search.isEmpty ||
            '${story['name']} $id'.toLowerCase().contains(search));
  }).toList();
  DateTime date(String id) =>
      DateTime.tryParse('${table[id]['startTime']}-01') ?? DateTime(1970);
  int chapter(String id) => int.tryParse(id.replaceFirst('main_', '')) ?? -1;
  ids.sort((a, b) {
    if (filter == StoryTypeFilter.main) return chapter(b).compareTo(chapter(a));
    final byDate = date(b).compareTo(date(a));
    if (byDate != 0) return byDate;
    final byChapter = chapter(b).compareTo(chapter(a));
    return byChapter != 0 ? byChapter : a.compareTo(b);
  });
  return ids;
}
