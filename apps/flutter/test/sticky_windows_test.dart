import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/sticky_windows.dart';

void main() {
  const parent = 'main-engine';
  const note = 'note-123';
  test('Subwindow arguments reject malformed / unrelated processes', () {
    expect(StickyDesktop.parseWindowArguments(''), isNull);
    expect(StickyDesktop.parseWindowArguments('{bad'), isNull);
    expect(StickyDesktop.parseWindowArguments(jsonEncode({
      'type': 'unknown', 'parentId': parent, 'noteId': note,
    })), isNull);
    expect(StickyDesktop.parseWindowArguments(jsonEncode({
      'type': 'sticky', 'parentId': '', 'noteId': note,
    })), isNull);
    expect(StickyDesktop.parseWindowArguments(jsonEncode({
      'type': 'sticky', 'parentId': parent, 'noteId': note,
    })), {'parentId': parent, 'noteId': note});
  });

  test('Sticky writes refuse to overwrite a newer parent copy', () {
    final existing = LocalNote(id: note, title: 'Title',
      body: 'Newer text', createdAt: DateTime.utc(2026));
    StickyConflictGuard.ensureUnchanged(existing, 'body', 'Newer text');
    StickyConflictGuard.ensureUnchanged(existing, 'title', 'Title');
    expect(() => StickyConflictGuard.ensureUnchanged(
      existing, 'body', 'Old text'), throwsStateError);
    expect(() => StickyConflictGuard.ensureUnchanged(
      existing, 'title', 'Changed'), throwsStateError);
    expect(() => StickyConflictGuard.ensureUnchanged(
      existing, 'due', ''), throwsStateError);
    expect(existing.body, 'Newer text');
  });
}
