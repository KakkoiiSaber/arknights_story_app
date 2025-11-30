import 'package:flutter/material.dart';

import '../config/database.dart';
import '../utils/audio_manager.dart';
import 'story_models.dart';

/// Returns a widget representation for a story event.
/// For audio-related events, playback is triggered via [AudioManager].
Widget buildEventWidget(BuildContext context, StoryEvent event) {
  switch (event.type) {
    case 'dialog':
    case 'narration':
    case 'subtitle':
      return _DialogEventTile(event: event);
    case 'decision':
      return _DecisionEventTile(event: event);
    case 'background':
    case 'background_tween':
    case 'vertical_bg':
    case 'grid_background':
    case 'large_bg_tween':
      return _BackgroundEventTile(event: event);
    case 'image':
    case 'image_tween':
    case 'character':
    case 'character_cutin':
    case 'charslot':
      return _ImageEventTile(event: event);
    case 'play_music':
    case 'stop_music':
    case 'play_sound':
      return _AudioEventTile(event: event);
    default:
      return _SystemEventTile(
        label: event.type,
        detail: event.raw ?? 'Unhandled event',
      );
  }
}

class _DialogEventTile extends StatelessWidget {
  const _DialogEventTile({required this.event});
  final StoryEvent event;

  @override
  Widget build(BuildContext context) {
    final speaker = event.speaker;
    final content = event.textContent ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (speaker != null && speaker.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                speaker,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _DecisionEventTile extends StatelessWidget {
  const _DecisionEventTile({required this.event});
  final StoryEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decision',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...event.options.map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $o'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundEventTile extends StatelessWidget {
  const _BackgroundEventTile({required this.event});
  final StoryEvent event;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveImageTile(
      label: 'Background',
      icon: Icons.image,
      imageUrl: event.backgroundUrl,
      fallbackDetail: event.raw,
    );
  }
}

class _ImageEventTile extends StatelessWidget {
  const _ImageEventTile({required this.event});
  final StoryEvent event;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl ?? event.characterUrl;
    final title = event.type == 'character' ? 'Character' : 'Image';
    return _ResponsiveImageTile(
      label: title,
      icon: Icons.photo_library_outlined,
      imageUrl: url,
      fallbackDetail: event.raw,
    );
  }
}

class _AudioEventTile extends StatefulWidget {
  const _AudioEventTile({required this.event});
  final StoryEvent event;

  @override
  State<_AudioEventTile> createState() => _AudioEventTileState();
}

class _AudioEventTileState extends State<_AudioEventTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAudioAction());
  }

  Future<void> _runAudioAction() async {
    final event = widget.event;
    switch (event.type) {
      case 'play_music':
        final intro = _resolveAudioUrl(event.introMusic ?? event.data['intro']);
        final loop = _resolveAudioUrl(event.loopMusic ?? event.data['key']);
        final volume = event.volume;
        if (volume != null) {
          await audio.setVolume(volume);
        }
        if (intro != null && loop != null) {
          await audio.intro2loop(intro, loop);
          return;
        }
        if (loop != null) {
          await audio.loop(loop);
          return;
        }
        if (intro != null) {
          await audio.intro(intro);
        }
        break;
      case 'stop_music':
        await audio.stop();
        break;
      case 'play_sound':
        final key = event.data['key'] ?? event.data['sound'];
        final soundUrl = _resolveAudioUrl(key);
        final volume = event.volume;
        await audio.playSound(soundUrl, volume: volume);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SystemEventTile(
      label: widget.event.type,
      detail: widget.event.raw ?? '',
      icon: Icons.music_note,
    );
  }
}

class _ResponsiveImageTile extends StatelessWidget {
  const _ResponsiveImageTile({
    required this.label,
    required this.icon,
    required this.imageUrl,
    this.fallbackDetail,
  });

  final String label;
  final IconData icon;
  final String? imageUrl;
  final String? fallbackDetail;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _SystemEventTile(
        label: label,
        detail: fallbackDetail ?? 'Missing image url',
        icon: icon,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final image = _NetworkImageBox(url: imageUrl!);
        final infoCard = _OverlayCard(
          label: label,
          detail: imageUrl!,
          icon: icon,
        );

        if (isWide) {
          return SizedBox(
            height: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: image,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: infoCard,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: image,
              ),
            ),
            const SizedBox(height: 8),
            infoCard,
          ],
        );
      },
    );
  }
}

class _NetworkImageBox extends StatelessWidget {
  const _NetworkImageBox({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
      ),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final total = progress.expectedTotalBytes;
          final loaded = progress.cumulativeBytesLoaded;
          final value = total != null ? loaded / total : null;
          return Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(value: value),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.white.withValues(alpha: 0.7),
              size: 32,
            ),
          );
        },
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemEventTile extends StatelessWidget {
  const _SystemEventTile({
    required this.label,
    required this.detail,
    this.icon,
  });

  final String label;
  final String detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(icon, size: 18),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _resolveAudioUrl(dynamic value) {
  if (value == null) return null;
  final str = value.toString().trim();
  if (str.isEmpty) return null;
  if (str.startsWith('http')) return str;
  return Database.storyMusicPath + str;
}
