import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'models.dart';

/// Portable selection, not a database backup. Does not contain credentials,
/// owner/cursor, pending outbox, tombstones, or device-only focus data.
class PortableArchive {
  const PortableArchive(this.data);
  static const format = 'simple-notes-portable';
  static const schemaVersion = 1;
  static const maxBytes = 8 * 1024 * 1024;
  static const maxRecords = 10000;
  final LocalData data;

  int get recordCount => data.lists.length + data.tasks.length + data.notes.length;

  List<int> encode({DateTime? now}) {
    final document = {
      'format': format,
      'schemaVersion': schemaVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'data': {
        'lists': data.lists.map((item) => item.toJson()).toList(),
        'tasks': data.tasks.map((item) => item.toJson()).toList(),
        'notes': data.notes.map((item) => item.toJson()).toList(),
      },
    };
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(document));
    if (bytes.length > maxBytes) {
      throw const FormatException('Archivio troppo grande (massimo 8 MB).');
    }
    return bytes;
  }

  static PortableArchive decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Archivio troppo grande (massimo 8 MB).');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != format ||
          decoded['schemaVersion'] != schemaVersion) {
        throw const FormatException('Formato o versione archivio non supportati.');
      }
      if (decoded['exportedAt'] is! String ||
          DateTime.tryParse(decoded['exportedAt'] as String) == null) {
        throw const FormatException('Data di esportazione non valida.');
      }
      final raw = decoded['data'];
      if (raw is! Map<String, dynamic> ||
          raw['lists'] is! List || raw['tasks'] is! List ||
          raw['notes'] is! List) {
        throw const FormatException('Sezioni archivio mancanti.');
      }
      final count = (raw['lists'] as List).length +
          (raw['tasks'] as List).length + (raw['notes'] as List).length;
      if (count > maxRecords) {
        throw const FormatException('Troppi elementi nell’archivio.');
      }
      final data = LocalData.fromJson({
        ...raw, 'trashedNotes': <dynamic>[],
      });
      _validate(data);
      return PortableArchive(data);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Archivio JSON danneggiato o non valido.');
    }
  }

  static bool _unique(Iterable<String> ids) {
    final values = ids.toList();
    return values.every((id) => id.trim().isNotEmpty) &&
        values.toSet().length == values.length;
  }

  static void _validate(LocalData data) {
    final listIds = data.lists.map((item) => item.id).toSet();
    if (!_unique(data.lists.map((item) => item.id)) ||
        !_unique(data.tasks.map((item) => item.id)) ||
        !_unique(data.notes.map((item) => item.id))) {
      throw const FormatException('Identificativi duplicati o mancanti.');
    }
    if (data.lists.any((item) => item.title.trim().isEmpty ||
            item.title.length > 255) ||
        data.notes.any((item) => item.title.trim().isEmpty ||
            item.title.length > 255) ||
        data.tasks.any((item) =>
            item.title.trim().isEmpty || item.title.length > 1024 ||
            item.priority < 0 || item.priority > 3 ||
            (item.listId != null && !listIds.contains(item.listId)) ||
            item.tags.length > 16 ||
            item.tags.any((tag) => tag.trim().isEmpty || tag.length > 40) ||
            item.subtasks.length > 50 ||
            item.subtasks.any((sub) => sub.title.trim().isEmpty ||
                sub.title.length > 255) ||
            !_unique(item.subtasks.map((sub) => sub.id)))) {
      throw const FormatException('Contenuti o riferimenti non validi.');
    }
  }

  /// Adds copies, never updating source IDs or existing records. Relationship
  /// IDs are regenerated together so nested tasks remain under their lists.
  LocalData asNewCopies({String Function()? newId}) {
    final fresh = newId ?? () => const Uuid().v4();
    final listMap = <String, String>{};
    final lists = [
      for (final item in data.lists)
        LocalTaskList.fromJson({
          ...item.toJson(), 'id': listMap[item.id] = fresh(),
        }),
    ];
    final tasks = [
      for (final item in data.tasks)
        LocalTask.fromJson({
          ...item.toJson(),
          'id': fresh(),
          'listId': item.listId == null ? null : listMap[item.listId],
          'subtasks': [
            for (final sub in item.subtasks)
              {...sub.toJson(), 'id': fresh()},
          ],
          'timeBlocks': [
            for (final slot in TimeSlotCollection.toJson(item.timeBlocks))
              {...slot, 'id': fresh()},
          ],
        }),
    ];
    final notes = [
      for (final item in data.notes)
        LocalNote.fromJson({...item.toJson(), 'id': fresh()}),
    ];
    return LocalData(lists: lists, tasks: tasks, notes: notes);
  }
}
