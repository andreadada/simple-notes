import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Simple Notes' design tokens. Forui is the baseline for new screens.
/// The existing Material widgets remain as transitional interoperability.
abstract final class NotesPalette {
  static const accent = Color(0xFF547AFF);
  static const background = Color(0xFF181818);
  static const sidebar = Color(0xFF202020);
  static const surface = Color(0xFF252525);
  static const muted = Color(0xFF303030);
  static const foreground = Color(0xFFF5F5F5);
  static const secondaryText = Color(0xFFA0A0A0);
  static const border = Color(0xFF343434);
}

abstract final class NotesTheme {
  /// Touch targets on Android; compact controls on Windows/macOS/Linux.
  static FThemeData forPlatform(TargetPlatform platform) {
    final touch = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia
        => true,
      _ => false,
    };
    final base = touch ? FTheme.neutral.dark.touch : FTheme.neutral.dark.desktop;
    return FThemeData(
      touch: touch,
      breakpoints: base.breakpoints,
      typography: base.typography,
      icons: base.icons,
      style: base.style,
      colors: base.colors.copyWith(
        background: NotesPalette.background,
        foreground: NotesPalette.foreground,
        card: NotesPalette.surface,
        muted: NotesPalette.muted,
        mutedForeground: NotesPalette.secondaryText,
        secondary: NotesPalette.sidebar,
        border: NotesPalette.border,
        primary: NotesPalette.accent,
        primaryForeground: Colors.white,
      ),
    );
  }
}
