import 'package:flutter/material.dart';
import '../config/database.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class StoryReviewPage extends StatefulWidget {
  final String storyId;
  final Duration fadeDuration;
  const StoryReviewPage({
    super.key,
    required this.storyId,
    this.fadeDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<StoryReviewPage> createState() => _StoryReviewPageState();
}

class _StoryReviewPageState extends State<StoryReviewPage> {
  static const double _layoutSwitchSize = 1080;

  Map<String, dynamic>? _story;
  bool _loading = true;
  String? _error;
  bool _bgLoaded = false;
  bool _bgReady = false;
  ImageProvider? _bgProvider;

  String? get id => _story?['id'] as String?;
  String? get name => _story?['name'] as String?;
  String? get desc => _story?['desc'] as String?;
  String? get backgroundId => _story?['backgroundId'] as String?;
  String? get gameMusicName => _story?['gameMusicName'] as String?;
  List<dynamic> get infoUnlockDatas =>
      (_story?['infoUnlockDatas'] as List<dynamic>?) ?? const [];

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  Future<void> _loadStory() async {
    final url = '${Database.reviewInfoPath}${widget.storyId}.json';
    try {
      final fetched = await DataRetriever.getJsonFromURL(url);
      if (fetched is! Map) throw Exception('Invalid story data');
      final story = Map<String, dynamic>.from(fetched as Map);
      final bgId = story['backgroundId'] as String?;
      final musicKey = story['gameMusicName'] as String?;

      if (mounted) {
        setState(() {
          _story = story;
          _loading = false;
          _bgLoaded = false;
          _bgReady = bgId == null || bgId.isEmpty;
          _bgProvider = null;
        });
      }

      await _preloadBackground(bgId);
      await _playBgMusic(musicKey);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load story';
      });
    }
  }

  Future<void> _preloadBackground(String? bgId) async {
    if (bgId == null || bgId.isEmpty) {
      if (mounted) {
        setState(() {
          _bgReady = true;
          _bgLoaded = false;
          _bgProvider = null;
        });
      }
      return;
    }

    final provider = NetworkImage(Database.backgroundPath + bgId);
    try {
      await precacheImage(provider, context);
      if (!mounted) return;
      setState(() {
        _bgLoaded = true;
        _bgReady = true;
        _bgProvider = provider;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bgLoaded = false;
        _bgReady = true;
        _bgProvider = null;
      });
    }
  }

  Future<void> _playBgMusic(String? musicKey) async {
    if (musicKey == null) return;

    final audioTable = await DataRetriever.getJsonFromURL(
      Database.gameMusicDataPath,
    );

    final trackInfo = audioTable[musicKey];
    if (trackInfo is! Map) return;

    final introPath = trackInfo['intro'] as String?;
    final loopPath = trackInfo['loop'] as String?;

    if (introPath == null && loopPath == null) return;
    if (introPath == null && loopPath != null) {
      await audio.loop(Database.gameMusicPath + loopPath);
      return;
    }
    if (introPath != null && loopPath != null) {
      await audio.intro2loop(
        Database.gameMusicPath + introPath,
        Database.gameMusicPath + loopPath,
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
            color: Colors.black.withOpacity(0.55),
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
    final hasBackground = hasData && (backgroundId?.isNotEmpty ?? false);
    final showError = !_loading && _error != null;
    final canShowContent = hasData && (_bgReady || !hasBackground);

    return Scaffold(
      // appBar: AppBar(
      //   // title: Text(name ?? 'Story')
      //   // backgroundColor: Colors.transparent,
      //   ),
      body: Stack(
        children: [
          if (hasBackground)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _bgLoaded && _bgReady ? 1 : 0,
                duration: widget.fadeDuration,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_bgProvider != null)
                      Image(
                        image: _bgProvider!,
                        fit: BoxFit.cover,
                        // Bias view to ~30% from the left so important left-side art stays visible on narrow widths.
                        alignment: const Alignment(-0.5, 0),
                      ),
                    // Darken background for readability.
                    Container(color: Colors.black.withOpacity(0.2)),
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
              color: hasBackground ? Colors.black.withOpacity(0.25) : null,
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
                    final primaryText = Colors.white.withOpacity(0.92);
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
                                        Text(
                                          name ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: primaryText,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
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
                                          final storyDesc =
                                              (infoMap?['storyDesc'] ?? '')
                                                  .toString()
                                                  .trim();

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.12,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
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
                                                          if (storyCode != null)
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
                                                              .withOpacity(0.1),
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
                                                            fontSize: codeSize,
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
        ],
      ),
    );
  }
}
