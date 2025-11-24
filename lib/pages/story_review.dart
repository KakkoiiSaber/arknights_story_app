import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../config/database.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class StoryReviewPage extends StatefulWidget {
  final Map<String, dynamic> storyInfo;
  const StoryReviewPage({super.key, required this.storyInfo});

  @override
  State<StoryReviewPage> createState() => _StoryReviewPageState();
}

class _StoryReviewPageState extends State<StoryReviewPage> {
  static const double _maxContentWidth = 1080;
  static const double _optContentWidth = 700;

  Map<String, dynamic> get storyInfo => widget.storyInfo;

  String? get id => storyInfo['id'] as String?;
  String? get name => storyInfo['name'] as String?;
  String? get backgroundId => storyInfo['backgroundId'] as String?;
  String? get gameMusicName => storyInfo['gameMusicName'] as String?;
  List<dynamic> get infoUnlockDatas =>
      (storyInfo['infoUnlockDatas'] as List<dynamic>?) ?? const [];

  bool _bgLoaded = false;

  @override
  void initState() {
    super.initState();
    _playBgMusic();
  }

  Future<void> _playBgMusic() async {
    final musicKey = gameMusicName;
    if (musicKey == null) return;

    final audioTable = await DataRetriever.getJsonFromURL(Database.gameMusicTablePath);

    final trackInfo = audioTable[musicKey];
    if (trackInfo is! Map) return;

    final intro = trackInfo['intro'] as String?;
    final loop = trackInfo['loop'] as String?;

    if (intro == null && loop == null) return;
    if (intro == null && loop != null) {
      await audio.loop(Database.musicPath + loop);
      return;
    }
    if (intro != null && loop != null) {
      await audio.intro2loop(
        Database.musicPath + intro,
        Database.musicPath + loop,
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

  @override
  Widget build(BuildContext context) {
    final hasBackground = backgroundId?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Story')),
      body: Stack(
        children: [
          if (hasBackground)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _bgLoaded ? 1 : 0,
                duration: const Duration(milliseconds: 2000),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      Database.backgroundPath + backgroundId!,
                      fit: BoxFit.cover,
                      // Bias view to ~30% from the left so important left-side art stays visible on narrow widths.
                      alignment: const Alignment(-0.5, 0),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null && !_bgLoaded) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _bgLoaded = true);
                          });
                        }
                        return child;
                      },
                      errorBuilder: (context, error, stackTrace) {
                        if (_bgLoaded) return const SizedBox.shrink();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _bgLoaded = false);
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                    // Darken background for readability.
                    Container(
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: hasBackground ? Colors.black.withOpacity(0.25) : null,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.maxWidth;
                    final best = _maxContentWidth - (available - _optContentWidth);
                    final targetWidth =
                        available < _maxContentWidth ? available : math.max(best, _optContentWidth);

                    return Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: targetWidth,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              if (id != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  id!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                'Stories',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              ...infoUnlockDatas.map<Widget>((info) {
                                final infoMap = info as Map?;
                                final storyName =
                                    infoMap?['storyName'] as String? ?? '';
                                final tag = infoMap?['avgTag'] as String?;
                                final storyCode = infoMap?['storyCode'] as String?;
                                final descPath = infoMap?['descPath'] as String?;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              storyName,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16),
                                            ),
                                            if (storyCode != null)
                                              Text(
                                                storyCode,
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (tag != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tag,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
