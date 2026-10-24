import 'package:flutter/material.dart';

import '../components/story_dashboard.dart';
import '../config/archive_style.dart';
import '../config/database.dart';
import '../utils/audio_manager.dart';
import '../utils/music_controller.dart';
import '../utils/data_retriever.dart';
import 'settings_page.dart';
import '../downloads/review_service.dart';
import '../components/review_download_panel.dart';
import '../account/account_service.dart';
import '../account/reading_library.dart';
import 'account_page.dart';
import 'story_review.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late Future<dynamic> _storyMetaFuture;
  late Future<dynamic> _homeAudioFuture;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  StoryTypeFilter _filter = StoryTypeFilter.all;
  bool _searchOpen = false;
  late final AnimationController _categoryMotion;
  StoryTypeFilter _catalogFilter = StoryTypeFilter.all;
  bool _switchingOut = false;
  int _filterRevision = 0;
  String? _reviewRevision;
  MusicScope? _music;

  @override
  void initState() {
    super.initState();
    _categoryMotion = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 110),
    );
    _reviewRevision = reviewAssets.revision;
    reviewAssets.addListener(_reviewUpdated);
    _storyMetaFuture = DataRetriever.getJsonFromURL(
      Database.storyMetaTablePath,
    );
    _homeAudioFuture = DataRetriever.getJsonFromURL(Database.gameMusicDataPath);
    _playHomeMusic();
  }

  Future<void> _playHomeMusic() async {
    final music = _music = audio.claimMusic();
    final table = await _homeAudioFuture;
    // A delayed request must not replace the activity's music after navigation.
    if (!mounted ||
        !music.isCurrent ||
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
      await music.play(intro: url('intro'), loop: url('loop'));
    } else {
      await music.play(loop: url('loop'));
    }
  }

  void _reviewUpdated() {
    if (!mounted || reviewAssets.revision == _reviewRevision) return;
    _reviewRevision = reviewAssets.revision;
    setState(() {
      _storyMetaFuture = DataRetriever.getJsonFromURL(
        Database.storyMetaTablePath,
      );
      _homeAudioFuture = DataRetriever.getJsonFromURL(
        Database.gameMusicDataPath,
      );
    });
    if (ModalRoute.of(context)?.isCurrent == true) _playHomeMusic();
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

  void _retryCatalog() {
    setState(() {
      _storyMetaFuture = DataRetriever.getJsonFromURL(
        Database.storyMetaTablePath,
      );
      _homeAudioFuture = DataRetriever.getJsonFromURL(
        Database.gameMusicDataPath,
      );
    });
    _playHomeMusic();
  }

  @override
  void dispose() {
    reviewAssets.removeListener(_reviewUpdated);
    _music?.close();
    _categoryMotion.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _selectFilter(StoryTypeFilter next) async {
    if (_filter == next) return;
    final revision = ++_filterRevision;
    setState(() {
      _filter = next;
      _switchingOut = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _catalogFilter = next;
        _switchingOut = false;
      });
      _categoryMotion.value = 1;
      return;
    }
    try {
      await _categoryMotion.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || revision != _filterRevision) return;
    setState(() {
      _catalogFilter = next;
      _switchingOut = false;
    });
    _categoryMotion.forward();
  }

  Widget _filters() => Wrap(
    spacing: 22,
    children: [
      for (final filter in StoryTypeFilter.values)
        Semantics(
          selected: _filter == filter,
          child: InkWell(
            onTap: () => _selectFilter(filter),
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: ArchiveStyle.motion(context, 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _filter == filter
                        ? ArchiveStyle.accent
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                const ['全部档案', '主线', '活动', '故事集', '联动'][filter.index],
                style: TextStyle(
                  fontSize: 12,
                  color: _filter == filter
                      ? ArchiveStyle.foreground
                      : ArchiveStyle.muted,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _searchField() => SizedBox(
    width: 180,
    height: 41,
    child: TextField(
      controller: _search,
      focusNode: _searchFocus,
      onChanged: (_) => setState(() {}),
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(
        fontSize: 11,
        height: 1.5,
        color: Color(0xffbcc6c7),
      ),
      decoration: const InputDecoration(
        hintText: '检索故事 / SEARCH',
        hintStyle: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: Color(0xff747e7f),
        ),
        prefixIcon: Icon(Icons.search, size: 14),
        prefixIconConstraints: BoxConstraints(minWidth: 30, minHeight: 41),
        isDense: true,
        filled: true,
        fillColor: Color(0x04ffffff),
        contentPadding: EdgeInsets.only(right: 12),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final padding = screenWidth > 1500
        ? 60.0
        : screenWidth <= 750
        ? 18.0
        : screenWidth <= 1050
        ? 24.0
        : 42.0;
    return Scaffold(
      body: ArchiveBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(padding, 25, padding, 24),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x1cffffff))),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '方舟档案馆',
                                  style: TextStyle(
                                    fontSize: 32,
                                    height: 1.44,
                                    fontWeight: FontWeight.w700,
                                    fontVariations: [
                                      FontVariation('wght', 700),
                                    ],
                                    letterSpacing: 2.56,
                                  ),
                                ),
                                WidgetSpan(child: SizedBox(width: 18)),
                                TextSpan(
                                  text: 'RECORDS',
                                  style: TextStyle(
                                    fontFamily: 'Archive Condensed',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 19,
                                    letterSpacing: 2.28,
                                    color: ArchiveStyle.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (wide) ...[
                          _filters(),
                          const SizedBox(width: 28),
                          _searchField(),
                        ],
                        if (!wide)
                          IconButton(
                            tooltip: '搜索故事',
                            onPressed: _toggleSearch,
                            icon: const Icon(Icons.search, size: 20),
                          ),
                        ListenableBuilder(
                          listenable: accountService,
                          builder: (context, _) => IconButton(
                            tooltip: '账户',
                            icon: Icon(
                              accountService.user == null
                                  ? Icons.person_outline
                                  : Icons.person,
                            ),
                            onPressed: () => Navigator.of(context).push(
                              archiveRoute(
                                context,
                                (_) => accountService.user == null
                                    ? const AccountPage()
                                    : const SettingsPage(),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '设置',
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              archiveRoute(
                                context,
                                (_) => const SettingsPage(),
                              ),
                            );
                            if (mounted && _music?.isCurrent != true) {
                              _playHomeMusic();
                            }
                          },
                        ),
                      ],
                    ),
                    if (!wide)
                      Align(alignment: Alignment.centerLeft, child: _filters()),
                    if (!wide && _searchOpen)
                      Align(
                        alignment: Alignment.centerRight,
                        child: _searchField(),
                      ),
                  ],
                ),
              ),
              ReviewDownloadPanel(compact: true, onRetry: _retryCatalog),
              ListenableBuilder(
                listenable: readingLibrary,
                builder: (context, _) {
                  final saved = readingLibrary.latestResume;
                  if (saved == null) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: Text(
                          '继续阅读 · ${saved['title'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            archiveRoute(
                              context,
                              (_) => StoryReviewPage(
                                storyId: saved['storyId'] as String,
                                resumeOnOpen: true,
                              ),
                            ),
                          );
                          if (mounted) _playHomeMusic();
                        },
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _categoryMotion,
                  builder: (context, child) {
                    final value = Curves.easeOutCubic.transform(
                      _categoryMotion.value,
                    );
                    return IgnorePointer(
                      ignoring: _switchingOut,
                      child: Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            (1 - value) * (_switchingOut ? -6 : 10),
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: StoryDashboard(
                    storyMetaTableFuture: _storyMetaFuture,
                    filter: _catalogFilter,
                    query: _search.text,
                    onStoryClosed: _playHomeMusic,
                    onRetry: _retryCatalog,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 10, padding, 14),
                child: Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: ArchiveStyle.line)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ARKNIGHTS / UNOFFICIAL ARCHIVE',
                        style: TextStyle(
                          fontFamily: 'Archive Condensed',
                          fontSize: 10,
                          letterSpacing: 1,
                          color: ArchiveStyle.muted,
                        ),
                      ),
                      Text(
                        'RECORDS OF OUR TIME  +',
                        style: TextStyle(
                          fontFamily: 'Archive Condensed',
                          fontSize: 10,
                          letterSpacing: 1,
                          color: ArchiveStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
