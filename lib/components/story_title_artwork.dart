import 'package:flutter/material.dart';
import '../config/archive_style.dart';

/// Reserve the final logo geometry before decoding, including loading/error states.
class StoryTitleArtwork extends StatelessWidget {
  const StoryTitleArtwork({
    super.key,
    required this.name,
    this.image,
    this.loading = false,
    this.compact = false,
  });
  final String name;
  final ImageProvider? image;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 100.0 : 180.0;
    Widget fallback() => Text(
      name,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: ArchiveStyle.foreground,
        fontSize: 27,
        letterSpacing: 2,
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Center(
        child: image == null
            ? loading
                  ? const SizedBox.shrink()
                  : fallback()
            : SizedBox(
                width: 280,
                height: height,
                child: Image(
                  image: image!,
                  width: 280,
                  height: height,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  frameBuilder: (context, child, frame, synchronous) =>
                      TweenAnimationBuilder<double>(
                        key: ValueKey(image),
                        tween: Tween(begin: 0, end: frame == null ? 0 : 1),
                        duration: ArchiveStyle.motion(context, 280),
                        curve: Curves.easeOutCubic,
                        builder: (context, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: child,
                      ),
                  errorBuilder: (_, _, _) => fallback(),
                ),
              ),
      ),
    );
  }
}
