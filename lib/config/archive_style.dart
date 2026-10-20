import 'package:flutter/material.dart';

class ArchiveStyle {
  static const background = Color(0xff101113);
  static const foreground = Color(0xffe9edf0);
  static const muted = Color(0xffaeb7c1);
  static const accent = Color(0xff7de2ed);
  static const line = Color(0x40ffffff);

  static Duration motion(BuildContext context, [int milliseconds = 260]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
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
      thickness: WidgetStatePropertyAll(3),
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
