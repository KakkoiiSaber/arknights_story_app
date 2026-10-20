import 'package:flutter/material.dart';
import '../config/database.dart';
import '../config/archive_style.dart';
import '../components/story_chapter_entry.dart';
import '../config/story_themes.dart';
import '../components/story_background.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';
import 'story.dart';

class StoryReviewPage extends StatefulWidget {
  final String storyId;
  final String? titleImageId;
  final Duration fadeDuration;
  const StoryReviewPage({
    super.key,
    required this.storyId,
    this.titleImageId,
    this.fadeDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<StoryReviewPage> createState() => _StoryReviewPageState();
}

class _StoryReviewPageState extends State<StoryReviewPage> {
  final _scroll = ScrollController();

  Map<String, dynamic>? _story;
  bool _loading = true;
  String? _error;
  bool _bgLoaded = false;
  List<String> _backgroundUrls = const [];
  List<ImageProvider> _bgProviders = const [];
  bool _readingStory = false;
  ImageProvider? _titleProvider;
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
    _loadStory();
  }

  Future<void> _stopAllAudio() async {
    await audio.stop();
  }

  Future<void> _openStory({
    required String storyTxt,
    String? storyName,
    String? storyCode,
    String? storyTag,
  }) async {
    _readingStory = true;
    await _stopAllAudio();
    if (!mounted) return;
    await Navigator.of(context).push(
      archiveRoute(
        context,
        (_) => StoryPage(
          storyTxtPath: storyTxt,
          storyName: storyName,
          storyCode: storyCode,
          storyTag: storyTag,
        ),
      ),
    );
    _readingStory = false;
    if (mounted) await _playBgMusic(gameMusicName);
  }

  Future<void> _loadStory() async {
    await _stopAllAudio();
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
    final providers = [for (final url in urls) NetworkImage(url)];
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
    final provider = NetworkImage(url);
    final loaded = await _precache(provider);
    if (!mounted) return;
    setState(() => _titleProvider = loaded ? provider : null);
  }

  Future<void> _playBgMusic(String? musicKey) async {
    if (!mounted || _readingStory) return;
    final theme = _theme;
    if (theme != null) {
      if (theme.musicIntroUrl != null) {
        await audio.intro2loop(theme.musicIntroUrl, theme.musicLoopUrl);
      } else {
        await audio.loop(theme.musicLoopUrl);
      }
      return;
    }
    if (musicKey == null) return;

    final audioTable = await DataRetriever.getJsonFromURL(
      Database.gameMusicDataPath,
    );

    if (!mounted || _readingStory || audioTable is! Map) return;
    final trackInfo = audioTable[musicKey];
    if (trackInfo is! Map) return;

    final introPath = trackInfo['intro'] as String?;
    final loopPath = trackInfo['loop'] as String?;

    if (introPath == null && loopPath == null) return;
    if (introPath == null && loopPath != null) {
      await audio.loop(
        Database.reviewAssetURL(Database.gameMusicPath, loopPath),
      );
      return;
    }
    if (introPath != null && loopPath != null) {
      await audio.intro2loop(
        Database.reviewAssetURL(Database.gameMusicPath, introPath),
        Database.reviewAssetURL(Database.gameMusicPath, loopPath),
      );
      return;
    }
  }

  @override
  void dispose() {
    // Stop page-specific music when leaving (remove if you want continuous music)
    audio.stop();
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

  Widget _details({required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_titleProvider != null)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 160),
          child: Image(
            image: _titleProvider!,
            width: 280,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, _, _) => _name(),
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
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.black.withValues(alpha: 0.5),
            child: IconButton(
              tooltip: '返回故事库',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 21),
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
        return Stack(
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
                            compact ? 54 : 64,
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
                            children: [_artwork(), _gradient(wide: false)],
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            child: _details(compact: false),
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
            Positioned(top: 0, left: 0, right: 0, child: _controls()),
          ],
        );
      },
    ),
  );
}
