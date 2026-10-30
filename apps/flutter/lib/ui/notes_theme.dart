import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Theme tokens shared between Material and Forui. Colors are resolved from
/// the local BuildContext, never from a global mutable palette.
@immutable
class NotesColors {
  const NotesColors({
    required this.accent,
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.muted,
    required this.foreground,
    required this.secondaryText,
    required this.border,
    required this.inlineUnderline,
    required this.placeholder,
  });

  final Color accent;
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color muted;
  final Color foreground;
  final Color secondaryText;
  final Color border;
  final Color inlineUnderline;
  final Color placeholder;
}

/// Dark-mode constants are retained for backward compatibility with tests
/// and historical helpers. New UI must use NotesPalette.of(context).
abstract final class NotesPalette {
  static const accent = Color(0xFF547AFF);
  static const background = Color(0xFF181818);
  static const sidebar = Color(0xFF202020);
  static const surface = Color(0xFF252525);
  static const muted = Color(0xFF303030);
  static const foreground = Color(0xFFF5F5F5);
  static const secondaryText = Color(0xFFA0A0A0);
  static const border = Color(0xFF343434);
  static const inlineUnderline = Color(0xFF676C76);
  static const placeholder = Color(0xB8A0A0A0);

  static const dark = NotesColors(
    accent: accent, background: background, sidebar: sidebar,
    surface: surface, muted: muted, foreground: foreground,
    secondaryText: secondaryText, border: border,
    inlineUnderline: inlineUnderline, placeholder: placeholder,
  );
  static const light = NotesColors(
    accent: Color(0xFF315AD6),
    background: Color(0xFFF8F9FC),
    sidebar: Color(0xFFF0F2F7),
    surface: Color(0xFFFFFFFF),
    muted: Color(0xFFE8EDF5),
    foreground: Color(0xFF172033),
    secondaryText: Color(0xFF4B5567),
    border: Color(0xFFD3DBE7),
    inlineUnderline: Color(0xFF78869C),
    placeholder: Color(0xB84B5567),
  );

  static NotesColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? light : dark;
}

abstract final class NotesTheme {
  static const inlineBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: NotesPalette.inlineUnderline, width: 1),
  );
  static const inlineFocusedBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: NotesPalette.accent, width: 1.5),
  );
  static const invisibleInlineBorder = UnderlineInputBorder(
    borderSide: BorderSide.none,
  );

  static ThemeData material(Brightness brightness) {
    final palette = brightness == Brightness.light
        ? NotesPalette.light : NotesPalette.dark;
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
        surface: palette.background,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.inlineUnderline)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.inlineUnderline)),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  /// Touch targets on Android; compact controls on Windows/macOS/Linux.
  static FThemeData forPlatform(TargetPlatform platform,
      {Brightness brightness = Brightness.dark}) {
    final touch = switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia
        => true,
      _ => false,
    };
    final base = switch ((brightness, touch)) {
      (Brightness.light, true) => FTheme.neutral.light.touch,
      (Brightness.light, false) => FTheme.neutral.light.desktop,
      (Brightness.dark, true) => FTheme.neutral.dark.touch,
      (Brightness.dark, false) => FTheme.neutral.dark.desktop,
    };
    final palette = brightness == Brightness.light
        ? NotesPalette.light : NotesPalette.dark;
    return FThemeData(
      touch: touch,
      breakpoints: base.breakpoints,
      typography: base.typography,
      icons: base.icons,
      style: base.style,
      colors: base.colors.copyWith(
        background: palette.background,
        foreground: palette.foreground,
        card: palette.surface,
        muted: palette.muted,
        mutedForeground: palette.secondaryText,
        secondary: palette.sidebar,
        border: palette.border,
        primary: palette.accent,
        primaryForeground: Colors.white,
      ),
    );
  }
}

/// Keeps the underline tied to *rendered characters*, rather than the available
/// width of an Expanded row. One pixel is reserved for the insertion caret.
abstract final class InlineTextMetrics {
  static double fieldWidth(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final available = maxWidth.isFinite
        ? (maxWidth >= 1 ? maxWidth : 1.0)
        : MediaQuery.sizeOf(context).width * 0.75;
    var longest = 0.0;
    for (final line in text.split('\n')) {
      final painter = TextPainter(
        text: TextSpan(text: line, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > longest) longest = painter.width;
      painter.dispose();
    }
    return (longest + 1).clamp(1.0, available).toDouble();
  }

  /// The painted underline follows the glyphs. The real editor needs extra
  /// caret/selection space: making its viewport exactly glyphWidth clipped
  /// the final letters of titles and wrapped placeholder descriptions.
  /// This reserve belongs to the *TextField*, not the underline.
  static double inputWidth({
    required double glyphWidth,
    required double maxWidth,
  }) {
    const caretAndSelectionReserve = 18.0;
    if (!maxWidth.isFinite) return glyphWidth + caretAndSelectionReserve;
    final available = maxWidth >= 1 ? maxWidth : 1.0;
    return (glyphWidth + caretAndSelectionReserve)
        .clamp(1.0, available).toDouble();
  }
}

/// Paints only the glyph-width portion of the underline. The field itself is
/// deliberately wider to fit the full text and the caret without clipping;
/// its invisible native border must never determine the line length.
class InlineGlyphUnderline extends StatelessWidget {
  const InlineGlyphUnderline({
    super.key,
    required this.glyphWidth,
    required this.focusNode,
    required this.child,
  });

  final double glyphWidth;
  final FocusNode focusNode;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: focusNode,
    builder: (context, _) => Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          start: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SizedBox(
              key: const Key('inline-glyph-underline'),
              width: glyphWidth,
              height: focusNode.hasFocus ? 1.5 : 1,
              child: ColoredBox(color: focusNode.hasFocus
                  ? NotesPalette.of(context).accent : NotesPalette.of(context).inlineUnderline),
            ),
          ),
        ),
      ],
    ),
  );
}
