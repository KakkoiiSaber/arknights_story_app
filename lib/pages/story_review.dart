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
  Map<String, dynamic> get storyInfo => widget.storyInfo;

  String? get id => storyInfo['id'] as String?;
  String? get name => storyInfo['name'] as String?;
  String? get backgroundId => storyInfo['backgroundId'] as String?;
  String? get gameMusicName => storyInfo['gameMusicName'] as String?;
  List<dynamic> get infoUnlockDatas =>
      (storyInfo['infoUnlockDatas'] as List<dynamic>?) ?? const [];

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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(Database.backgroundPath + backgroundId!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.35),
                      BlendMode.darken,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: hasBackground ? Colors.black.withOpacity(0.25) : null,
              child: SafeArea(
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
                        final storyName = infoMap?['storyName'] as String? ?? '';
                        final tag = infoMap?['avgTag'] as String?;
                        final storyId = infoMap?['storyId'] as String?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      storyName,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    if (storyId != null)
                                      Text(
                                        storyId,
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              if (tag != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
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
            ),
          ),
        ],
      ),
    );
  }
}
