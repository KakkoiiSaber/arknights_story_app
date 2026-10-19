import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/database.dart';
import 'story_player.dart';

class StoryPlayerView extends StatefulWidget {
  const StoryPlayerView({
    super.key,
    required this.player,
    required this.title,
    this.artBuilder,
  });
  final StoryPlayer player;
  final String title;
  final Widget Function(List<String> urls, BoxFit fit)? artBuilder;
  @override
  State<StoryPlayerView> createState() => _StoryPlayerViewState();
}

class _StoryPlayerViewState extends State<StoryPlayerView> {
  StoryPlayer get player => widget.player;
  void _advance() => setState(player.advance);
  void _restart() => setState(player.restart);
  Widget _art(List<String> urls, BoxFit fit) =>
      widget.artBuilder?.call(urls, fit) ??
      _StoryArt(key: ValueKey(urls.join('|')), urls: urls, fit: fit);

  Widget _character(String slot, StoryCharacter character, double stageHeight) {
    List<String> urls;
    try {
      urls = Database.storyCharacterURLs(character.name);
    } on ArgumentError {
      urls = [];
    }
    return FractionallySizedBox(
      key: ValueKey('character-$slot'),
      widthFactor: player.characters.length == 1 ? .9 : .7,
      heightFactor: .95,
      alignment: Alignment.bottomCenter,
      child: OverflowBox(
        minWidth: 0,
        maxWidth: double.infinity,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: stageHeight * .95,
          height: stageHeight * .95,
          child: Opacity(
            opacity: character.dimmed ? .48 : 1,
            child: _art(urls, BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.space): _advance,
      const SingleActivator(LogicalKeyboardKey.arrowRight): _advance,
      const SingleActivator(LogicalKeyboardKey.enter): _advance,
    },
    child: Focus(
      autofocus: true,
      child: Material(
        color: const Color(0xff090d12),
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            key: const ValueKey('advance-story'),
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (player.background != null)
                  _art([
                    Database.storyBackgroundURL(player.background!),
                  ], BoxFit.cover),
                for (final entry in player.characters.entries)
                  Align(
                    alignment: switch (entry.key) {
                      'l' => const Alignment(-.85, 1),
                      'r' => const Alignment(.85, 1),
                      _ => Alignment.bottomCenter,
                    },
                    child: _character(
                      entry.key,
                      entry.value,
                      constraints.maxHeight,
                    ),
                  ),
                if (player.image != null)
                  _art([Database.storyImageURL(player.image!)], BoxFit.contain),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x99000000),
                          Colors.transparent,
                          Color(0xaa000000),
                        ],
                        stops: [0, .3, 1],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: '返回故事主题页',
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('restart-story'),
                              tooltip: '重新阅读',
                              icon: const Icon(Icons.replay),
                              onPressed: _restart,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 1100,
                          maxHeight: math.max(100, constraints.maxHeight * .55),
                        ),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xee101820),
                            border: Border(
                              top: BorderSide(
                                color: Colors.cyan.shade200,
                                width: 2,
                              ),
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 24),
                            ],
                          ),
                          child: SingleChildScrollView(
                            key: ValueKey(
                              'dialogue-${player.lineNumber}-${player.ended}',
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (player.ended) ...[
                                  const Text(
                                    '本节故事结束',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _restart,
                                        child: const Text('重新阅读'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(context).maybePop(),
                                        child: const Text('返回故事主题页'),
                                      ),
                                    ],
                                  ),
                                ] else if (player.choices.isNotEmpty) ...[
                                  const Text(
                                    '选择回应',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 8),
                                  for (
                                    var i = 0;
                                    i < player.choices.length;
                                    i++
                                  )
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          key: ValueKey('choice-$i'),
                                          onPressed: () =>
                                              setState(() => player.choose(i)),
                                          child: Text(
                                            player.choices[i].label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ] else ...[
                                  if (player.speaker.isNotEmpty) ...[
                                    Text(
                                      player.speaker,
                                      style: TextStyle(
                                        color: Colors.cyan.shade100,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Text(
                                    player.text,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.65,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '点击继续  ▸',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StoryArt extends StatefulWidget {
  const _StoryArt({super.key, required this.urls, required this.fit});
  final List<String> urls;
  final BoxFit fit;
  @override
  State<_StoryArt> createState() => _StoryArtState();
}

class _StoryArtState extends State<_StoryArt> {
  Widget _candidate(int index) {
    if (index >= widget.urls.length) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          semanticLabel: '图片暂不可用',
        ),
      );
    }
    return Image.network(
      widget.urls[index],
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) => _candidate(index + 1),
    );
  }

  @override
  Widget build(BuildContext context) => _candidate(0);
}
