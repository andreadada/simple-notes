import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/responsive_layout.dart';

void main() {
  test('Sidebar and detail panels use independent viewport gates', () {
    expect(NotesResponsivePolicy.usesSidebar(390), isFalse);
    expect(NotesResponsivePolicy.usesSidebar(949.99), isFalse);
    expect(NotesResponsivePolicy.usesSidebar(950), isTrue);
    expect(NotesResponsivePolicy.usesDetails(1199), isFalse);
    expect(NotesResponsivePolicy.usesDetails(1200), isTrue);
  });

  test('Note cards use one, two or three real content-width columns', () {
    expect(NotesResponsivePolicy.noteColumns(328), 1);
    expect(NotesResponsivePolicy.noteColumns(699.9), 1);
    expect(NotesResponsivePolicy.noteColumns(700), 2);
    expect(NotesResponsivePolicy.noteColumns(1119.99), 2);
    expect(NotesResponsivePolicy.noteColumns(1120), 3);
    for (final width in [320.0, 700.0, 780.0, 1120.0, 1340.0]) {
      final count = NotesResponsivePolicy.noteColumns(width);
      final card = NotesResponsivePolicy.noteCardWidth(width);
      expect(card, greaterThan(0));
      expect(card * count + (count - 1) * NotesResponsivePolicy.cardGap,
          closeTo(width, 0.001));
    }
  });

  test('Zero-width constraint is safe and never produces negative width', () {
    expect(NotesResponsivePolicy.noteCardWidth(0), 0);
    expect(NotesResponsivePolicy.noteCardWidth(-1), 0);
  });
}
