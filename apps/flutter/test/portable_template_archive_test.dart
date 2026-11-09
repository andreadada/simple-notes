import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/portable_template_archive.dart';
import 'package:simple_notes/data/user_task_templates.dart';

void main() {
  UserTaskTemplateLibrary library(String title) =>
      UserTaskTemplateLibrary().upsert(
        UserTaskTemplateLibrary.newTemplate(
          title: title, description: 'Descrizione', priority: 3,
          tags: ['studio', 'università'],
          subtasks: ['Leggere', 'Ripassare'],
        ),
      );

  test('roundtrip and additive import regenerate IDs and preserve content', () {
    final original = library('Esame');
    final file = PortableTemplateArchive.encode(original);
    final decoded = PortableTemplateArchive.inspect(file);
    final existing = library('Precedente');
    final merged = PortableTemplateArchive.addCopies(existing, decoded);
    expect(merged.templates, hasLength(2));
    expect(merged.templates.first.id, existing.templates.first.id);
    expect(merged.templates.last.id, isNot(original.templates.single.id));
    expect(merged.templates.last.title, 'Esame');
    expect(merged.templates.last.tags, ['studio', 'università']);
    expect(merged.templates.last.subtasks, ['Leggere', 'Ripassare']);
    expect(merged.templates.last.priority, 3);
    expect(existing.templates, hasLength(1));
    expect(utf8.decode(file), isNot(contains('pending_mutations')));
  });

  test('invalid format, extra fields, invalid UTF-8 and model fail closed', () {
    expect(() => PortableTemplateArchive.inspect([255]),
        throwsFormatException);
    final value = jsonDecode(utf8.decode(
        PortableTemplateArchive.encode(library('A'))))
        as Map<String, dynamic>;
    final badSchema = Map<String, dynamic>.from(value)..['schema'] = 99;
    expect(() => PortableTemplateArchive.inspect(utf8.encode(
        jsonEncode(badSchema))), throwsFormatException);
    final badRoot = Map<String, dynamic>.from(value)..['owner'] = 'other';
    expect(() => PortableTemplateArchive.inspect(utf8.encode(
        jsonEncode(badRoot))), throwsFormatException);
    final badModel = Map<String, dynamic>.from(value);
    badModel['library'] = {
      'schema': 1, 'templates': [{'id': 'custom-x', 'title': 'Incomplete'}]
    };
    expect(() => PortableTemplateArchive.inspect(utf8.encode(
        jsonEncode(badModel))), throwsFormatException);
  });

  test('capacity and bytes abort without mutating the existing library', () {
    expect(() => PortableTemplateArchive.inspect(
        List<int>.filled(PortableTemplateArchive.maxBytes + 1, 65)),
        throwsFormatException);
    final existing = library('Kept');
    final full = UserTaskTemplateLibrary(templates: [
      for (var i = 0; i < 50; i++)
        UserTaskTemplateLibrary.newTemplate(
          title: 'Temp $i', description: '', subtasks: [])
    ]);
    expect(() => PortableTemplateArchive.addCopies(existing, full),
        throwsFormatException);
    expect(existing.templates.single.title, 'Kept');
  });

  test('empty library roundtrip is valid and imports zero entries', () {
    final source = UserTaskTemplateLibrary();
    final restored = PortableTemplateArchive.inspect(
        PortableTemplateArchive.encode(source));
    final target = library('Existing');
    expect(restored.templates, isEmpty);
    expect(PortableTemplateArchive.addCopies(target, restored)
        .templates.single.id, target.templates.single.id);
  });
}
