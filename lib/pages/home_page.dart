import 'package:flutter/material.dart';

import '../components/story_dashboard.dart';
import '../config/archive_style.dart';
import '../config/database.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<dynamic> _storyMetaFuture;
  late final Future<dynamic> _homeAudioFuture;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  StoryTypeFilter _filter = StoryTypeFilter.all;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _storyMetaFuture = DataRetriever.getJsonFromURL(
      Database.storyMetaTablePath,
    );
    _homeAudioFuture = DataRetriever.getJsonFromURL(Database.gameMusicDataPath);
    _playHomeMusic();
  }

  Future<void> _playHomeMusic() async {
    final table = await _homeAudioFuture;
    // A delayed request must not replace the activity's music after navigation.
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        table is! Map) {
      return;
    }
    final track = table['sys.ON_MUSIC.bg_void'];
    if (track is! Map) return;
    String? url(String key) => track[key] is String
        ? Database.reviewAssetURL(Database.gameMusicPath, track[key] as String)
        : null;
    if (url('intro') != null) {
      await audio.intro2loop(url('intro'), url('loop'));
    } else {
      await audio.loop(url('loop'));
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) _search.clear();
    });
    if (_searchOpen) {
      _searchFocus.requestFocus();
    } else {
      _searchFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const filters = StoryTypeFilter.values;
    const labels = ['全部', '主线', '活动', '故事集', '联动'];
    final padding = MediaQuery.sizeOf(context).width < 600 ? 18.0 : 28.0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 10, padding - 8, 4),
              child: Row(
                children: [
                  Transform(
                    transform: Matrix4.skewX(-0.2),
                    child: Container(
                      width: 5,
                      height: 20,
                      color: ArchiveStyle.foreground,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '故事库',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _searchOpen ? '关闭搜索' : '搜索故事',
                    onPressed: _toggleSearch,
                    icon: Icon(
                      _searchOpen ? Icons.close : Icons.search,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: ArchiveStyle.motion(context, 200),
              curve: Curves.easeOutCubic,
              child: _searchOpen
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: TextField(
                        controller: _search,
                        focusNode: _searchFocus,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '搜索故事',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                          border: UnderlineInputBorder(),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 4, padding, 12),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ArchiveStyle.line, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < filters.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: _filter == filters[i],
                          child: InkWell(
                            onTap: () => setState(() => _filter = filters[i]),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    labels[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _filter == filters[i]
                                          ? ArchiveStyle.foreground
                                          : ArchiveStyle.muted,
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: ArchiveStyle.motion(context, 180),
                                  width: 28,
                                  height: 2,
                                  color: _filter == filters[i]
                                      ? ArchiveStyle.accent
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StoryDashboard(
                storyMetaTableFuture: _storyMetaFuture,
                filter: _filter,
                query: _search.text,
                onStoryClosed: _playHomeMusic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
