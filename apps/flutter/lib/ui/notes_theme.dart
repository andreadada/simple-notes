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
  static const inlineUnderline = Color(0xFF676C76);
  // Subdued placeholder: 72% opaque, independently of Material theme defaults.
  static const placeholder = Color(0xB8A0A0A0);
}

abstract final class NotesTheme {
  static const inlineBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: NotesPalette.inlineUnderline, width: 1),
  );
  static const inlineFocusedBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: NotesPalette.accent, width: 1.5),
  );
  // For inline controls the real line is painted to the measured glyph width.
  // This invisible shape prevents InputDecorator from drawing a full-width line.
  static const invisibleInlineBorder = UnderlineInputBorder(
    borderSide: BorderSide.none,
  );

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

/// Keeps the underline tied to *rendered characters*, rather than the available
/// width of an Expanded row. One pixel is reserved for the insertion caret.
abstract final class InlineTextMetrics {
  static double fieldWidth(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final available = maxWidth.isFinite && maxWidth >= 1
        ? maxWidth : MediaQuery.sizeOf(context).width * 0.75;
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
}

/// Paints only the visible glyph-width portion of the underline. Flutter
/// InputDecorator can impose a larger minimum layout width than TextPainter
/// reports, so a native UnderlineInputBorder cannot guarantee this rule.
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
                  ? NotesPalette.accent : NotesPalette.inlineUnderline),
            ),
          ),
        ),
      ],
    ),
  );
}
