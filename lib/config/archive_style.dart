import 'package:flutter/material.dart';

class ArchiveStyle {
  static const background = Color(0xff17191a);
  static const foreground = Color(0xffe9eceb);
  static const muted = Color(0xff89989b);
  static const accent = Color(0xff9bd6dd);
  static const line = Color(0x26ffffff);

  static Duration motion(BuildContext context, [int milliseconds = 260]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Archive Sans',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontVariations: [FontVariation('wght', 400)]),
      bodyLarge: TextStyle(fontVariations: [FontVariation('wght', 400)]),
      bodySmall: TextStyle(fontVariations: [FontVariation('wght', 400)]),
      titleMedium: TextStyle(fontVariations: [FontVariation('wght', 500)]),
      labelLarge: TextStyle(fontVariations: [FontVariation('wght', 500)]),
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: background,
      onSurface: foreground,
    ),
    dividerColor: line,
    splashFactory: InkRipple.splashFactory,
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(0),
      thumbVisibility: WidgetStatePropertyAll(false),
      trackVisibility: WidgetStatePropertyAll(false),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(44, 44),
      ),
    ),
  );
}

Route<T> archiveRoute<T>(BuildContext context, WidgetBuilder builder) =>
    PageRouteBuilder<T>(
      transitionDuration: ArchiveStyle.motion(context),
      reverseTransitionDuration: ArchiveStyle.motion(context, 200),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Subtle faceted canvas shared by the archive shell, without image downloads.
class ArchiveBackdrop extends StatelessWidget {
  const ArchiveBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ArchiveFacets(), child: child);
}

class _ArchiveFacets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ArchiveStyle.background,
    );
    final paint = Paint()..color = const Color(0x14000000);
    for (final points in [
      [
        const Offset(.03, 0),
        const Offset(.38, 0),
        const Offset(.92, 1),
        const Offset(.57, 1),
      ],
      [
        const Offset(.72, 0),
        const Offset(1, 0),
        const Offset(.42, 1),
        const Offset(.1, 1),
      ],
    ]) {
      final path = Path()
        ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
