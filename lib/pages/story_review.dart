import 'package:flutter/material.dart';
import '../config/database.dart';
import '../config/config.dart';
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
  static final double _layoutSwitchSize = Config.layoutSwitchSize;

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
      MaterialPageRoute(
        builder: (_) => StoryPage(
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
    super.dispose();
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 12,
      left: 12,
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = !_loading && _story != null;
    final hasBackgroundId = hasData && _backgroundUrls.isNotEmpty;
    final showBackgroundLayer = hasData && hasBackgroundId;
    final showError = !_loading && _error != null;
    final canShowContent = hasData;

    return Scaffold(
      body: Stack(
        children: [
          if (showBackgroundLayer)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _bgLoaded ? 1 : 0,
                duration: widget.fadeDuration,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryBackground(
                      images: _bgProviders,
                      aspectRatio: _theme?.backgroundAspectRatio ?? 16 / 9,
                    ),
                    // Darken background for readability.
                    Container(color: Colors.black.withValues(alpha: 0.2)),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                // bottom: 16,
              ),
              color: showBackgroundLayer
                  ? Colors.black.withValues(alpha: 0.25)
                  : null,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.maxWidth;
                    final targetWidth = available > _layoutSwitchSize
                        ? 0.4 * available
                        : available;
                    final isWide = constraints.maxWidth >= 800;
                    final titleSize = isWide ? 18.0 : 16.0;
                    final codeSize = isWide ? 13.0 : 12.0;
                    final descSize = isWide ? 15.0 : 14.0;
                    final primaryText = Colors.white.withValues(alpha: 0.92);
                    final secondaryText = Colors.white70;

                    return Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: targetWidth,
                        child: AnimatedOpacity(
                          duration: widget.fadeDuration,
                          opacity: canShowContent ? 1 : 0,
                          child: canShowContent
                              ? AnimatedSwitcher(
                                  duration: widget.fadeDuration,
                                  child: SingleChildScrollView(
                                    key: const ValueKey('story-content'),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_titleProvider != null)
                                          SizedBox(
                                            height: 150,
                                            width: _theme?.titleIsBanner == true
                                                ? 300
                                                : 200,
                                            child: Image(
                                              image: _titleProvider!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        if (_titleProvider != null)
                                          const SizedBox(height: 8),
                                        if (_titleProvider == null)
                                          Text(
                                            name ?? '',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.headlineSmall,
                                          ),
                                        // Text(
                                        //   name ?? '',
                                        //   style: Theme.of(context)
                                        //       .textTheme
                                        //       .headlineSmall
                                        //       ?.copyWith(
                                        //         color: primaryText,
                                        //         fontWeight: FontWeight.w600,
                                        //       ),
                                        // ),
                                        if (desc != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            desc!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        Text(
                                          'Stories',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(color: primaryText),
                                        ),
                                        const SizedBox(height: 8),
                                        ...infoUnlockDatas.map<Widget>((info) {
                                          final infoMap = info as Map?;
                                          final storyName =
                                              infoMap?['storyName']
                                                  as String? ??
                                              '';
                                          final tag =
                                              infoMap?['avgTag'] as String?;
                                          final storyCode =
                                              infoMap?['storyCode'] as String?;
                                          final storyTxt = infoMap?['storyTxt']
                                              ?.toString();
                                          final storyDesc =
                                              (infoMap?['storyDesc'] ?? '')
                                                  .toString()
                                                  .trim();
                                          final bool hasStoryTxt =
                                              storyTxt != null &&
                                              storyTxt.isNotEmpty;

                                          return GestureDetector(
                                            onTap: hasStoryTxt
                                                ? () => _openStory(
                                                    storyTxt: storyTxt,
                                                    storyName: storyName,
                                                    storyCode: storyCode,
                                                    storyTag: tag,
                                                  )
                                                : null,
                                            behavior: HitTestBehavior.opaque,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.12),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              storyName,
                                                              style: TextStyle(
                                                                color:
                                                                    primaryText,
                                                                fontSize:
                                                                    titleSize,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            if (storyCode !=
                                                                null)
                                                              Text(
                                                                storyCode,
                                                                style: TextStyle(
                                                                  color:
                                                                      secondaryText,
                                                                  fontSize:
                                                                      codeSize,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (tag != null)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            tag,
                                                            style: TextStyle(
                                                              color:
                                                                  secondaryText,
                                                              fontSize:
                                                                  codeSize,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if (storyDesc.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      storyDesc,
                                                      style: TextStyle(
                                                        color: secondaryText,
                                                        fontSize: descSize,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('story-empty'),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (showError && !hasData)
            Center(
              child: Text(
                _error ?? 'Failed to load story',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          _buildBackButton(),
          _buildVolumeButton(),
        ],
      ),
    );
  }

  Widget _buildVolumeButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: audio.soundEnabled,
          builder: (context, enabled, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(22),
              ),
              child: IconButton(
                icon: Icon(
                  enabled ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await audio.toggleEnabled();
                  if (mounted) setState(() {});
                },
                tooltip: enabled ? 'Mute' : 'Unmute',
              ),
            );
          },
        ),
      ),
    );
  }
}
