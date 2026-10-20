import 'dart:math' as math;

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
    this.maxWidth = double.infinity,
    this.aspectRatio = 632 / 456,
  });

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

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio ?? widget.aspectRatio;
    final width = math.min(widget.height * ratio, widget.maxWidth);
    final height = math.min(widget.height, width / ratio);
    final highlighted = _hovered || _focused;
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
                hoverColor: Colors.transparent,
                highlightColor: Colors.white.withValues(alpha: 0.04),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    AnimatedSlide(
                      offset: highlighted
                          ? const Offset(0, -0.02)
                          : Offset.zero,
                      duration: ArchiveStyle.motion(context, 200),
                      child: SizedBox(
                        height: height,
                        width: width,
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
                            if (_visible &&
                                widget.titleImage != null &&
                                !_failed)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  widthFactor: 0.92,
                                  heightFactor: 0.52,
                                  child: Image(
                                    image: widget.titleImage!,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomCenter,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (highlighted)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _CoverCorners()),
                        ),
                      ),
                  ],
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

class _CoverCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ArchiveStyle.accent
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(0, 16)
        ..lineTo(0, 0)
        ..lineTo(16, 0),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 16, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - 16),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CoverCorners oldDelegate) => false;
}
