import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../config/archive_style.dart';

/// Full artwork at a shared height; the decoded aspect ratio determines width.
class StoryEntry extends StatefulWidget {
  const StoryEntry({
    super.key,
    required this.name,
    required this.kvImage,
    required this.titleImage,
    required this.onTap,
    this.height = 128,
    this.framed = false,
    this.maxWidth = double.infinity,
    this.aspectRatio = 632 / 456,
  });

  final bool framed;
  final String name;
  final ImageProvider? kvImage;
  final ImageProvider? titleImage;
  final VoidCallback onTap;
  final double height;
  final double maxWidth;
  final double aspectRatio;

  @override
  State<StoryEntry> createState() => _StoryEntryState();
}

class _StoryEntryState extends State<StoryEntry> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _ratio;
  bool _visible = false;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _failed = false;
  late final Key _visibilityKey = UniqueKey();

  void _stopListening() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
    _stream = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visible) _resolve();
  }

  @override
  void didUpdateWidget(StoryEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kvImage != widget.kvImage) {
      _stopListening();
      _ratio = null;
      _failed = false;
      if (_visible) _resolve();
    }
  }

  void _resolve() {
    if (_stream != null || widget.kvImage == null) return;
    final stream = widget.kvImage!.resolve(
      createLocalImageConfiguration(context),
    );
    _stream = stream;
    _listener = ImageStreamListener(
      (info, synchronousCall) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        if (!mounted || ratio == _ratio) return;
        // Cached image delivery can be synchronous during widget updates.
        if (synchronousCall) {
          _ratio = ratio;
        } else {
          setState(() => _ratio = ratio);
        }
      },
      onError: (_, _) {
        if (mounted) setState(() => _failed = true);
      },
    );
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  Widget _artwork(double width, double height) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_visible && widget.kvImage != null && !_failed)
          Image(
            image: widget.kvImage!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallback(),
          )
        else if (_failed || widget.kvImage == null)
          _fallback(),
        if (_visible && widget.titleImage != null && !_failed)
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: .92,
              heightFactor: .52,
              child: Image(
                image: widget.titleImage!,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                frameBuilder: (context, child, frame, synchronous) =>
                    TweenAnimationBuilder<double>(
                      key: ValueKey(widget.titleImage),
                      tween: Tween(begin: 0, end: frame == null ? 0 : 1),
                      duration: ArchiveStyle.motion(context, 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: child,
                    ),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio ?? widget.aspectRatio;
    final width = math.min(widget.height * ratio, widget.maxWidth);
    final height = math.min(widget.height, width / ratio);
    final highlighted = _hovered || _focused;
    final ready = _ratio != null || _failed || widget.kvImage == null;
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (info.visibleFraction <= 0 || _visible || !mounted) return;
        setState(() => _visible = true);
        _resolve();
      },
      child: Semantics(
        label: widget.name,
        button: true,
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: ArchiveStyle.motion(context, 180),
            curve: Curves.easeOutCubic,
            width: width,
            height: widget.height,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHover: (value) => setState(() => _hovered = value),
                onFocusChange: (value) => setState(() => _focused = value),
                onHighlightChanged: (value) => setState(() => _pressed = value),
                splashFactory: NoSplash.splashFactory,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedScale(
                    scale: _pressed
                        ? 1.006
                        : highlighted
                        ? 1.018
                        : 1,
                    duration: ArchiveStyle.motion(
                      context,
                      _pressed ? 120 : 300,
                    ),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: ready ? 1 : 0,
                      duration: ArchiveStyle.motion(context, 360),
                      curve: Curves.easeOutCubic,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: highlighted ? 1 : 0),
                        duration: ArchiveStyle.motion(context, 300),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          final brightness = 1 + value * .09;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (value > 0 && ready)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: value * .14,
                                      child: ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX: 7,
                                          sigmaY: 7,
                                        ),
                                        child: ColorFiltered(
                                          colorFilter: const ColorFilter.mode(
                                            Color(0xffdfe5d8),
                                            BlendMode.srcIn,
                                          ),
                                          child: _artwork(width, height),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ColorFiltered(
                                colorFilter: ColorFilter.matrix([
                                  brightness,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  brightness,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  brightness,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                                child: child,
                              ),
                              if (_focused)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: ArchiveStyle.accent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        child: _artwork(width, height),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        widget.name,
        textAlign: TextAlign.center,
        style: const TextStyle(color: ArchiveStyle.muted, fontSize: 13),
      ),
    ),
  );
}
