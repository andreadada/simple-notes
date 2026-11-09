import 'dart:convert';

import 'user_task_templates.dart';

/// Manual, unencrypted export/import of only local template definitions.
/// No owner, credentials, tasks or sync operations are serialized.
abstract final class PortableTemplateArchive {
  static const format = 'simple-notes-custom-templates';
  static const schema = 1;
  static const maxBytes = 128 * 1024;

  static List<int> encode(UserTaskTemplateLibrary library) {
    final bytes = utf8.encode(jsonEncode({
      'format': format,
      'schema': schema,
      'library': jsonDecode(library.serialize()),
    }));
    if (bytes.length > maxBytes) {
      throw const FormatException('File modelli superiore a 128 KiB.');
    }
    return bytes;
  }

  static UserTaskTemplateLibrary inspect(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('File modelli superiore a 128 KiB.');
    }
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map<String, dynamic> ||
        raw.length != 3 ||
        raw['format'] != format ||
        raw['schema'] != schema ||
        raw['library'] is! Map<String, dynamic>) {
      throw const FormatException('Formato modelli non supportato.');
    }
    return UserTaskTemplateLibrary.deserialize(jsonEncode(raw['library']));
  }

  /// Validate and prepare all copies in memory before any persistent write.
  static UserTaskTemplateLibrary addCopies(
    UserTaskTemplateLibrary existing,
    UserTaskTemplateLibrary imported,
  ) {
    if (existing.templates.length + imported.templates.length > 50) {
      throw const FormatException(
        'Massimo 50 modelli personali. Nessun dato importato.');
    }
    var next = existing;
    for (final model in imported.templates) {
      next = next.upsert(UserTaskTemplateLibrary.newTemplate(
        title: model.title,
        description: model.description,
        priority: model.priority,
        tags: model.tags,
        subtasks: model.subtasks,
      ));
    }
    return next;
  }
}
