import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../config/database.dart';
import '../story/story_models.dart';
import '../utils/audio_manager.dart';
import '../utils/data_retriever.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.storyTxt});

  final String storyTxt;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final ScrollController _scrollController = ScrollController();
  static const double _maxContentWidth = 900;
  static const Set<String> _hardBreakTypes = {
    'decision',
    'predicate',
    'start_battle',
    'tutorial_signal',
    'skip_to_this',
    'header',
  };

  bool _loading = true;
  String? _error;
  List<StoryEvent> _events = const [];

  String? _backgroundUrl;
  String? _foregroundUrl;
  String? _currentMusicLoopUrl;
  Map<String, String> _characters = {};
  // bool _textOnlyMode = false;
  bool _textOnlyMode = true;

  @override
  void initState() {
    super.initState();
    _loadStory();
  }

  @override
  void dispose() {
    audio.stop();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _candidateUrls() {
    final normalized =
        widget.storyTxt.startsWith('http') ? widget.storyTxt : '${Database.storyContentPath}${widget.storyTxt}'.replaceAll('.txt', '.json');
    final urls = <String>[];

    if (normalized.endsWith('.json')) {
      urls.add(normalized);
    } else if (normalized.endsWith('.txt')) {
      urls.add(normalized.replaceFirst(RegExp(r'\\.txt\$'), '.json'));
    } else {
      urls.add('$normalized.json');
    }

    urls.add(normalized); // fall back to the raw path if it was already JSON.
    return urls.toSet().toList();
  }

  Future<void> _loadStory() async {
    setState(() {
      _loading = true;
      _error = null;
      _events = const [];
    });

    StoryEvent? firstEvent;
    for (final url in _candidateUrls()) {
      final data = await DataRetriever.getJsonFromURL(url);
      if (data is! List) continue;

      final parsed = data
          .whereType<Map>()
          .map((e) => StoryEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      if (parsed.isNotEmpty) {
        firstEvent = parsed.first;
      }

      if (mounted) {
        setState(() {
          _events = parsed;
          _loading = false;
        });
      }

      await _applyInitialEvents();
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = 'Unable to load story events.';
    });
  }

  Future<void> _applyInitialEvents() async {
    bool hasVisual = _backgroundUrl != null || _foregroundUrl != null;
    int applied = 0;

    for (final event in _events) {
      if (applied > 50) break; // safety guard against very long headers.

      if (!event.isTextual) {
        await _applyEvent(event);
        applied++;

        if (event.type.startsWith('background')) {
          hasVisual = true;
        } else if (event.type.startsWith('image') || event.type == 'character_cutin') {
          hasVisual = true;
        }
      } else if (hasVisual) {
        // Stop after we've established an initial visual state and reached the first text.
        break;
      }
    }
  }

  void _onEventVisible(StoryEvent event) {
    _applyEvent(event);
  }

  Future<void> _applyEvent(StoryEvent event) async {
    switch (event.type) {
      case 'background':
      case 'background_tween':
      case 'vertical_bg':
      case 'grid_background':
      case 'large_bg_tween':
        final bg = event.backgroundUrl;
        setState(() {
          _backgroundUrl = bg;
        });
        break;
      case 'image':
      case 'image_tween':
      case 'character_cutin':
        final img = event.imageUrl;
        setState(() {
          _foregroundUrl = img;
        });
        break;
      case 'play_music':
        await _startMusic(event);
        break;
      case 'stop_music':
        _currentMusicLoopUrl = null;
        await audio.stop();
        break;
      case 'charslot':
      case 'character':
        _updateCharacterSlot(event);
        break;
      default:
        break;
    }
  }

  Future<void> _startMusic(StoryEvent event) async {
    final intro = event.introMusicUrl;
    final loop = event.loopMusicUrl ?? intro;

    if (loop == null) return;
    if (_currentMusicLoopUrl == loop) return;

    if (intro != null && intro != loop) {
      await audio.intro2loop(intro, loop);
    } else {
      await audio.loop(loop);
    }
    _currentMusicLoopUrl = loop;

    if (event.volume != null) {
      await audio.setVolume(event.volume!.clamp(0, 1));
    }
  }

  void _updateCharacterSlot(StoryEvent event) {
    final slot = (event.slot ?? 'm').toLowerCase();
    final url = event.characterUrl;
    final updated = Map<String, String>.from(_characters);

    if (url == null || url.isEmpty) {
      updated.remove(slot);
    } else {
      updated[slot] = url;
    }

    setState(() {
      _characters = updated;
    });
  }

  Alignment _alignmentForSlot(String slot) {
    switch (slot) {
      case 'l':
      case 'left':
        return Alignment.bottomLeft;
      case 'r':
      case 'right':
        return Alignment.bottomRight;
      default:
        return Alignment.bottomCenter;
    }
  }

  Widget _buildCharacters() {
    if (_characters.isEmpty) return const SizedBox.shrink();
    final entries = _characters.entries.toList();

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final entry in entries)
              Align(
                alignment: _alignmentForSlot(entry.key),
                child: FractionallySizedBox(
                  // widthFactor: 0.42,
                  widthFactor: 1,
                  child: Image.network(
                    entry.value,
                    // fit: BoxFit.contain,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForegroundImage() {
    if (_foregroundUrl == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [
              ...previous,
              if (current != null) current,
            ],
          ),
          child: Image.network(
            _foregroundUrl!,
            key: ValueKey(_foregroundUrl),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [
                ...previous,
                if (current != null) current,
              ],
            ),
            child: _backgroundUrl == null
                ? Container(
                    key: const ValueKey('empty-bg'),
                    color: Colors.black,
                  )
                : Image.network(
                    _backgroundUrl!,
                    key: ValueKey(_backgroundUrl),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black,
                    ),
                  ),
          ),
          Container(color: Colors.black.withOpacity(0.35)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadStory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final groupedEvents = _groupEvents(_events);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
      physics: const BouncingScrollPhysics(),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final entry = groupedEvents[index];
        return LayoutBuilder(
          builder: (context, constraints) {
            final targetWidth =
                math.min(_maxContentWidth, constraints.maxWidth);
            if (entry.isTextual) {
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: targetWidth,
                  child: _GroupedDialogTile(
                    events: entry.events,
                    onVisible: _onEventVisible,
                  ),
                ),
              );
            }
            final event = entry.events.first;
            return Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: targetWidth,
                child: _StoryEventTile(
                  event: event,
                  onVisible: _onEventVisible,
                  hideContent: _textOnlyMode,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_DisplayEntry> _groupEvents(List<StoryEvent> events) {
    if (events.isEmpty) return const [];

    final grouped = <_DisplayEntry>[];
    _DisplayEntry? current;

    bool sameSpeaker(String? a, String? b) {
      final left = (a ?? '').trim();
      final right = (b ?? '').trim();
      return left == right;
    }

    for (final event in events) {
      if (event.isTextual) {
        if (current != null &&
            current.isTextual &&
            sameSpeaker(current.speaker, event.speaker)) {
          current.events.add(event);
          continue;
        }
        current = _DisplayEntry(events: [event], speaker: event.speaker);
        grouped.add(current);
      } else {
        if (current != null &&
            current.isTextual &&
            !_hardBreakTypes.contains(event.type)) {
          current.events.add(event);
          continue;
        }
        current = _DisplayEntry(events: [event]);
        grouped.add(current);
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackground(),
          _buildForegroundImage(),
          _buildCharacters(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.storyTxt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _textOnlyMode ? 'Show all events' : 'Show dialog only',
                        onPressed: () {
                          setState(() {
                            _textOnlyMode = !_textOnlyMode;
                          });
                        },
                        icon: Icon(
                          _textOnlyMode ? Icons.forum : Icons.view_agenda_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayEntry {
  _DisplayEntry({
    required this.events,
    this.speaker,
  });

  final List<StoryEvent> events;
  final String? speaker;

  bool get isTextual => events.isNotEmpty && events.first.isTextual;
}

class _StoryEventTile extends StatefulWidget {
  const _StoryEventTile({
    required this.event,
    required this.onVisible,
    this.hideContent = false,
  });

  final StoryEvent event;
  final ValueChanged<StoryEvent> onVisible;
  final bool hideContent;

  @override
  State<_StoryEventTile> createState() => _StoryEventTileState();
}

class _StoryEventTileState extends State<_StoryEventTile> {
  bool _isActive = false;

  @override
  Widget build(BuildContext context) {
    final activateThreshold = widget.hideContent ? 0.001 : 0.18;
    final resetThreshold = widget.hideContent ? 0.0 : 0.02;

    return VisibilityDetector(
      key: ValueKey('evt-${widget.event.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > activateThreshold;
        if (visible && !_isActive) {
          _isActive = true;
          widget.onVisible(widget.event);
        } else if (!visible && _isActive && info.visibleFraction < resetThreshold) {
          _isActive = false;
        }
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: widget.hideContent ? 0 : 12),
        child: widget.hideContent
            ? const SizedBox(height: 1)
            : widget.event.isTextual
                ? _DialogTile(event: widget.event)
                : _MetaTile(event: widget.event),
      ),
    );
  }
}

class _GroupedDialogTile extends StatefulWidget {
  const _GroupedDialogTile({
    required this.events,
    required this.onVisible,
  });

  final List<StoryEvent> events;
  final ValueChanged<StoryEvent> onVisible;

  @override
  State<_GroupedDialogTile> createState() => _GroupedDialogTileState();
}

class _GroupedDialogTileState extends State<_GroupedDialogTile> {
  bool _isActive = false;

  @override
  Widget build(BuildContext context) {
    final first = widget.events.first;
    final mergedContent = widget.events
        .map((e) => e.textContent)
        .where((c) => c != null && c!.isNotEmpty)
        .map((c) => c!)
        .join('\n');
    final speaker = widget.events.first.speaker;

    return VisibilityDetector(
      key: ValueKey('evt-group-${first.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.18;
        if (visible && !_isActive) {
          _isActive = true;
          for (final e in widget.events) {
            widget.onVisible(e);
          }
        } else if (!visible && _isActive && info.visibleFraction < 0.02) {
          _isActive = false;
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _DialogTile(
          event: first,
          contentOverride: mergedContent,
          speakerOverride: speaker,
        ),
      ),
    );
  }
}

class _DialogTile extends StatelessWidget {
  const _DialogTile({
    required this.event,
    this.contentOverride,
    this.speakerOverride,
  });

  final StoryEvent event;
  final String? contentOverride;
  final String? speakerOverride;

  @override
  Widget build(BuildContext context) {
    final content = contentOverride ?? event.textContent ?? '';
    final isDialog = event.type == 'dialog';
    final speaker = speakerOverride ?? event.speaker;
    final speakerText = speaker == null || speaker.isEmpty ? null : '$speaker:';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDialog && speakerText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                speakerText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.event});

  final StoryEvent event;

  IconData _iconForType(String type) {
    switch (type) {
      case 'background':
      case 'background_tween':
        return Icons.image;
      case 'play_music':
        return Icons.music_note;
      case 'stop_music':
        return Icons.stop_circle_outlined;
      case 'charslot':
        return Icons.person;
      case 'decision':
        return Icons.list_alt;
      case 'dialog_marker':
        return Icons.bookmark_border;
      default:
        return Icons.adjust;
    }
  }

  Widget _buildDecision() {
    final options = event.options;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForType(event.type), color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Decision',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (o) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      o,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (event.isDecision) return _buildDecision();

    final icon = _iconForType(event.type);
    String label = event.type;

    if (event.type == 'background' && event.background != null) {
      label = 'Background • ${event.background}';
    } else if (event.type == 'play_music' && event.loopMusic != null) {
      label = 'Music • ${event.loopMusic}';
    } else if (event.type == 'charslot' && event.character != null) {
      label = 'Character • ${event.character}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '#${event.id}',
            style: const TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
