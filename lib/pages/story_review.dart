import 'package:flutter/material.dart';
import '../config/database.dart';
import '../config/archive_style.dart';
import '../components/story_chapter_entry.dart';
import '../config/story_themes.dart';
import '../downloads/review_service.dart';
import '../components/story_background.dart';
import '../utils/audio_manager.dart';
import '../utils/music_controller.dart';
import '../utils/data_retriever.dart';
import 'story.dart';
import '../story/story_playlist.dart';
import '../components/chapter_download_button.dart';
import '../story/story_script.dart' show storyTxtPath;
import '../account/reading_library.dart';
import '../components/reading_progress.dart';

class StoryReviewPage extends StatefulWidget {
  final String storyId;
  final String? titleImageId;
  final String? storyDate;
  final String? storyType;
  final Duration fadeDuration;
  final bool resumeOnOpen;
  const StoryReviewPage({
    super.key,
    required this.storyId,
    this.titleImageId,
    this.storyDate,
    this.storyType,
    this.fadeDuration = const Duration(milliseconds: 1000),
    this.resumeOnOpen = false,
  });

  @override
  State<StoryReviewPage> createState() => _StoryReviewPageState();
}

class _StoryReviewPageState extends State<StoryReviewPage> {
  final _scroll = ScrollController();
  late MusicScope _music;

  Map<String, dynamic>? _story;
  bool _loading = true;
  String? _error;
  bool _bgLoaded = false;
  List<String> _backgroundUrls = const [];
  List<ImageProvider> _bgProviders = const [];
  bool _readingStory = false;
  String? _reviewRevision;
  bool _needsRefresh = false;
  Future<void>? _loadingStory;
  ImageProvider? _titleProvider;
  bool _autoResumed = false;
  StoryThemeAssets? get _theme =>
      StoryThemes.forStory(widget.storyId, metadata: _story);

  String? get id => _story?['id'] as String?;
  String? get name => _story?['name'] as String?;
  String? get desc => _story?['desc'] as String?;
  String? get gameMusicName => _story?['gameMusicName'] as String?;
  List<dynamic> get infoUnlockDatas =>
      (_story?['infoUnlockDatas'] as List<dynamic>?) ?? const [];

  @override
  void initState() {
    super.initState();
    _music = audio.claimMusic();
    _reviewRevision = reviewAssets.revision;
    reviewAssets.addListener(_reviewUpdated);
    readingLibrary.addListener(_readingUpdated);
    _loadStory();
  }

  Future<void> _stopAllAudio() async {
    await Future.wait([_music.close(), audio.stopSfx()]);
  }

  Future<void> _openStory({
    required String storyTxt,
    String? storyName,
    String? storyCode,
    String? storyTag,
  }) async {
    if (_readingStory) return;
    _readingStory = true;
    await _stopAllAudio();
    if (!mounted) return;
    await Navigator.of(context).push(
      archiveRoute(
        context,
        (_) => StoryPage(
          storyId: widget.storyId,
          storyTxtPath: storyTxt,
          playlist: StoryPlaylistEntry.fromReview(
            infoUnlockDatas,
            archiveName: name ?? '',
            storyId: widget.storyId,
          ),
          storyName: storyName,
          storyCode: storyCode,
          storyTag: storyTag,
        ),
      ),
    );
    _readingStory = false;
    if (mounted) {
      _music = audio.claimMusic();
      if (_needsRefresh) {
        _needsRefresh = false;
        await _loadStory();
      } else {
        await _playBgMusic(gameMusicName);
      }
    }
  }

  void _reviewUpdated() {
    if (!mounted || reviewAssets.revision == _reviewRevision) return;
    _reviewRevision = reviewAssets.revision;
    _needsRefresh = true;
    if (!_readingStory && _loadingStory == null) {
      _needsRefresh = false;
      _loadStory();
    }
  }

  void _readingUpdated() {
    if (mounted) setState(() {});
  }

  void _continueStory() {
    final chapters = infoUnlockDatas
        .whereType<Map>()
        .where((c) => c['storyTxt'] is String)
        .toList();
    if (chapters.isEmpty) return;
    final saved = readingLibrary.resume(widget.storyId)?['chapterId'];
    var index = chapters.indexWhere(
      (c) => chapterKey(c['storyTxt'] as String) == saved,
    );
    if (index < 0) index = 0;
    final checkpoint = readingLibrary.chapter(
      chapters[index]['storyTxt'] as String,
    );
    if ((checkpoint?['atEnd'] == true ||
            (checkpoint?['atEnd'] == null &&
                checkpoint?['completed'] == true)) &&
        index + 1 < chapters.length) {
      index++;
    }
    final c = chapters[index];
    _openStory(
      storyTxt: c['storyTxt'] as String,
      storyName: c['storyName'] as String?,
      storyCode: c['storyCode'] as String?,
      storyTag: c['avgTag'] as String?,
    );
  }

  Future<void> _loadStory() =>
      _loadingStory ??= _loadStoryContent().whenComplete(() {
        _loadingStory = null;
        if (_needsRefresh && mounted && !_readingStory) {
          _needsRefresh = false;
          _loadStory();
        }
      });

  Future<void> _loadStoryContent() async {
    if (!mounted) return;
    final url = '${Database.reviewInfoPath}${widget.storyId}.json';
    try {
      final fetched = await DataRetriever.getJsonFromURL(url);
      if (fetched is! Map) throw Exception('Invalid story data');
      final story = Map<String, dynamic>.from(fetched);
      final theme = StoryThemes.forStory(widget.storyId, metadata: story);
      final bgId = story['backgroundId']?.toString();
      final musicKey = story['gameMusicName']?.toString();
      final titleId = widget.titleImageId ?? story['titleImageId']?.toString();
      final backgroundUrls =
          theme?.backgroundUrls ??
          [
            if (bgId != null && bgId.isNotEmpty)
              Database.reviewAssetURL(Database.backgroundPath, bgId),
          ];
      final titleUrl =
          theme?.titleUrl ??
          (titleId == null || titleId.isEmpty
              ? null
              : Database.reviewAssetURL(Database.titleImagePath, titleId));

      if (mounted) {
        setState(() {
          _story = story;
          _loading = false;
          _bgLoaded = false;
          _backgroundUrls = backgroundUrls;
          _bgProviders = const [];
          _titleProvider = null;
        });
      }

      readingLibrary.registerStory(
        widget.storyId,
        infoUnlockDatas
            .whereType<Map>()
            .map((c) => c['storyTxt'])
            .whereType<String>(),
      );
      if (widget.resumeOnOpen && !_autoResumed && mounted) {
        _autoResumed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _continueStory();
        });
      }
      // Artwork and audio prepare independently; the chapter list is usable immediately.
      await Future.wait([
        _preloadBackground(backgroundUrls),
        _preloadTitleImage(titleUrl),
        _playBgMusic(musicKey),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load story';
      });
    }
  }

  Future<bool> _precache(ImageProvider provider) async {
    if (!mounted) return false;
    var succeeded = true;
    try {
      // Download/decode once through Flutter's shared image cache. In particular,
      // don't GET a large background as a preliminary availability check.
      await precacheImage(
        provider,
        context,
        onError: (_, _) {
          succeeded = false;
        },
      ).timeout(const Duration(seconds: 30));
      return succeeded;
    } catch (_) {
      return false;
    }
  }

  Future<void> _preloadBackground(List<String> urls) async {
    final providers = [for (final url in urls) reviewAssets.image(url)];
    final loaded = await Future.wait(providers.map(_precache));
    if (!mounted) return;
    setState(() {
      // A tiled background is one composition: don't display only half of it.
      _bgLoaded = providers.isNotEmpty && loaded.every((value) => value);
      _bgProviders = _bgLoaded ? providers : const [];
    });
  }

  Future<void> _preloadTitleImage(String? url) async {
    if (url == null || url.isEmpty) return;
    final provider = reviewAssets.image(url);
    final loaded = await _precache(provider);
    if (!mounted) return;
    setState(() => _titleProvider = loaded ? provider : null);
  }

  Future<void> _playBgMusic(String? musicKey) async {
    final music = _music;
    if (!mounted || _readingStory || !music.isCurrent) return;
    // Old cached data may still carry the retired first-story music fallback.
    if (_story?['musicRole'] == 'opening-story' ||
        _story?['musicRole'] == 'none' ||
        musicKey?.startsWith('story.') == true) {
      await music.play();
      return;
    }
    final theme = _theme;
    if (theme != null) {
      if (!theme.hasReviewMusic) {
        await music.play();
        return;
      }
      if (theme.musicIntroUrl != null) {
        await music.play(intro: theme.musicIntroUrl, loop: theme.musicLoopUrl);
      } else {
        await music.play(loop: theme.musicLoopUrl);
      }
      return;
    }
    if (musicKey == null) {
      await music.play();
      return;
    }

    final audioTable = await DataRetriever.getJsonFromURL(
      Database.gameMusicDataPath,
    );

    if (!mounted || _readingStory || !music.isCurrent || audioTable is! Map) {
      return;
    }
    final trackInfo = audioTable[musicKey];
    if (trackInfo is! Map) return;

    final introPath = trackInfo['intro'] as String?;
    final loopPath = trackInfo['loop'] as String?;

    if (introPath == null && loopPath == null) return;
    if (introPath == null && loopPath != null) {
      await music.play(
        loop: Database.reviewAssetURL(Database.gameMusicPath, loopPath),
      );
      return;
    }
    if (introPath != null && loopPath != null) {
      await music.play(
        intro: Database.reviewAssetURL(Database.gameMusicPath, introPath),
        loop: Database.reviewAssetURL(Database.gameMusicPath, loopPath),
      );
      return;
    }
  }

  @override
  void dispose() {
    readingLibrary.removeListener(_readingUpdated);
    reviewAssets.removeListener(_reviewUpdated);
    // The pop future can resume home before this exit animation disposes us.
    // Closing this scope must never stop the new homepage music.
    _music.close();
    _scroll.dispose();
    super.dispose();
  }

  Widget _artwork() => AnimatedOpacity(
    opacity: _bgLoaded ? 1 : 0,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : widget.fadeDuration,
    child: StoryBackground(
      images: _bgProviders,
      aspectRatio: _theme?.backgroundAspectRatio ?? 16 / 9,
    ),
  );

  Widget _gradient({required bool wide}) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (wide)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Color(0x12000000),
                  Color(0x85000000),
                  Color(0xe8000000),
                  Colors.black,
                ],
                stops: [0.32, 0.45, 0.61, 0.79, 1],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: wide
                  ? const [
                      Color(0x50000000),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black,
                    ]
                  : const [
                      Color(0x30000000),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black,
                    ],
              stops: const [0, 0.14, 0.72, 1],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _recordLabel() => Text(
    'ARKNIGHTS / ${name ?? widget.storyId}',
    textAlign: TextAlign.right,
    style: const TextStyle(
      fontFamily: 'Archive Condensed',
      fontSize: 11,
      letterSpacing: 1.3,
      color: ArchiveStyle.muted,
    ),
  );

  Widget _details({
    required bool compact,
    bool showRecordLabel = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showRecordLabel) ...[
        Align(alignment: Alignment.centerRight, child: _recordLabel()),
        SizedBox(height: compact ? 14 : 24),
      ],
      if (_titleProvider != null)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 180),
            child: Image(
              image: _titleProvider!,
              width: 280,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => _name(),
            ),
          ),
        )
      else
        _name(),
      const SizedBox(height: 18),
      if (desc?.trim().isNotEmpty == true) ...[
        Text(
          desc!,
          style: TextStyle(
            color: const Color(0xffd0d2d6),
            fontSize: compact ? 12 : 14,
            height: 1.9,
          ),
        ),
        const SizedBox(height: 26),
      ],
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('章节目录', style: TextStyle(fontSize: 18, letterSpacing: 2)),
          Text(
            '${infoUnlockDatas.length} RECORDS',
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: ArchiveStyle.muted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      StoryReadingProgress(storyId: widget.storyId),
      if (readingLibrary.resume(widget.storyId) != null)
        TextButton.icon(
          onPressed: _continueStory,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(
            '继续阅读 · ${readingLibrary.resume(widget.storyId)?['title'] ?? ''}',
          ),
        ),
      const SizedBox(height: 12),
      if (infoUnlockDatas.isNotEmpty)
        ChapterDownloadButton(
          storyId: 'story:${Database.storyContentPath}:${widget.storyId}',
          title: name ?? widget.storyId,
          chapters: {
            for (final raw in infoUnlockDatas)
              if (raw is Map &&
                  raw['storyTxt'] is String &&
                  (raw['storyTxt'] as String).isNotEmpty)
                '${Database.storyContentPath}${storyTxtPath(raw['storyTxt'] as String)}':
                    [raw['storyCode'], raw['storyName'], raw['avgTag']]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' · '),
          },
        ),
      for (var i = 0; i < infoUnlockDatas.length; i++)
        _chapter(
          infoUnlockDatas[i] as Map,
          compact: compact,
          last: i == infoUnlockDatas.length - 1,
        ),
      if (infoUnlockDatas.isEmpty)
        const Text('暂无可阅读章节', style: TextStyle(color: ArchiveStyle.muted)),
    ],
  );

  Widget _name() => Text(
    name ?? '',
    style: const TextStyle(
      color: ArchiveStyle.foreground,
      fontSize: 27,
      letterSpacing: 2,
    ),
  );

  Widget _chapter(Map data, {required bool compact, required bool last}) {
    final txt = data['storyTxt'] as String?;
    return StoryChapterEntry(
      name: data['storyName'] as String? ?? '',
      description: data['storyDesc'] as String? ?? '',
      code: data['storyCode'] as String?,
      tag: data['avgTag'] as String?,
      compact: compact,
      last: last,
      progressLabel: txt == null ? null : chapterProgressLabel(txt),
      onTap: txt == null || txt.isEmpty
          ? null
          : () => _openStory(
              storyTxt: txt,
              storyName: data['storyName'] as String?,
              storyCode: data['storyCode'] as String?,
              storyTag: data['avgTag'] as String?,
            ),
    );
  }

  Widget _controls() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: const Color(0xb8121719),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, size: 23),
                    SizedBox(width: 12),
                    Text('返回', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 700 ||
            (constraints.maxWidth >= 600 &&
                constraints.maxWidth > constraints.maxHeight);
        final compact = constraints.maxHeight < 480;
        // Match the artwork's reserved right-hand area at every screen size.
        // A pixel cap would squeeze this into a narrow strip on wide monitors.
        final infoWidth = constraints.maxWidth * 0.40;
        final artHeight = (constraints.maxWidth * 0.68).clamp(250.0, 340.0);
        final hasData = !_loading && _story != null;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Stack(
            children: [
              if (wide && _backgroundUrls.isNotEmpty) ...[
                Positioned.fill(child: _artwork()),
                Positioned.fill(child: _gradient(wide: true)),
              ],
              if (hasData)
                if (wide)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SafeArea(
                      left: false,
                      child: SizedBox(
                        width: infoWidth,
                        height: double.infinity,
                        child: Scrollbar(
                          controller: _scroll,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            key: PageStorageKey('story-info-${widget.storyId}'),
                            padding: EdgeInsets.fromLTRB(
                              22,
                              compact ? 16 : 26,
                              24,
                              32,
                            ),
                            child: _details(compact: compact),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Scrollbar(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: Column(
                        children: [
                          SizedBox(
                            height: artHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _artwork(),
                                _gradient(wide: false),
                                Positioned(
                                  top: 28,
                                  right: 24,
                                  child: _recordLabel(),
                                ),
                              ],
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: _details(
                                compact: false,
                                showRecordLabel: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_loading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              if (_error != null && !hasData)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '故事加载失败',
                        style: TextStyle(color: ArchiveStyle.muted),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadStory();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              if (wide)
                Positioned(
                  left: 40,
                  bottom: 30,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (widget.storyType) {
                            'MAIN_STORY' => 'MAIN STORY',
                            'MINI_STORY' => 'STORY COLLECTION',
                            _ => 'SIDE STORY',
                          },
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            color: ArchiveStyle.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (widget.storyDate ?? '').replaceAll('-', ' / '),
                          style: const TextStyle(
                            fontSize: 10,
                            color: ArchiveStyle.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(top: 0, left: 0, right: 0, child: _controls()),
            ],
          ),
        );
      },
    ),
  );
}
