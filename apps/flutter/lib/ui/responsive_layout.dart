/// Layout decisions are based on available content width, not device names.
/// Cards may grow vertically to fit inline-editable content without clipping.
abstract final class NotesResponsivePolicy {
  static const double sidebarBreakpoint = 950;
  static const double detailsBreakpoint = 1200;
  static const double cardGap = 12;

  static bool usesSidebar(double viewportWidth) =>
      viewportWidth >= sidebarBreakpoint;

  static bool usesDetails(double viewportWidth) =>
      viewportWidth >= detailsBreakpoint;

  static int noteColumns(double availableWidth) {
    if (availableWidth >= 1120) return 3;
    if (availableWidth >= 700) return 2;
    return 1;
  }

  static double noteCardWidth(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 0;
    final columns = noteColumns(availableWidth);
    return (availableWidth - cardGap * (columns - 1)) / columns;
  }
}
