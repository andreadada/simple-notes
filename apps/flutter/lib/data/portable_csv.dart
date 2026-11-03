import 'dart:convert';

import 'models.dart';

/// CSV views of active local entities. CSV is not a backup and cannot be
/// imported back into Simple Notes; no sync metadata or credentials appear.
enum CsvDataset {
  tasks('Attività', 'attivita'),
  notes('Note', 'note'),
  lists('Liste', 'liste');

  const CsvDataset(this.label, this.filePart);
  final String label;
  final String filePart;
}

class PortableCsv {
  const PortableCsv(this.data);

  /// Export bounds prevent generating unreasonably large in-memory payloads.
  static const maxBytes = 8 * 1024 * 1024;
  static const maxRecords = 10000;
  final LocalData data;

  int count(CsvDataset dataset) => switch (dataset) {
        CsvDataset.tasks => data.tasks.length,
        CsvDataset.notes => data.notes.length,
        CsvDataset.lists => data.lists.length,
      };

  /// UTF-8 BOM for Excel interoperability, RFC4180 comma + CRLF + escaping.
  /// All columns are quoted and spreadsheet formula-like values are prefixed
  /// with an apostrophe *before* quoting, including whitespace-prefixed ones.
  List<int> encode(CsvDataset dataset) {
    if (count(dataset) > maxRecords) {
      throw const FormatException('Troppi elementi per l’esportazione CSV.');
    }
    final buffer = StringBuffer('\uFEFF');
    final rows = _rows(dataset);
    for (final row in rows) {
      buffer.write(row.map(_cell).join(','));
      buffer.write('\r\n');
      // Stop before constructing an excessively large byte array.
      if (buffer.length > maxBytes) {
        throw const FormatException('CSV troppo grande (massimo 8 MB).');
      }
    }
    final bytes = utf8.encode(buffer.toString());
    if (bytes.length > maxBytes) {
      throw const FormatException('CSV troppo grande (massimo 8 MB).');
    }
    return bytes;
  }

  Iterable<List<String>> _rows(CsvDataset dataset) sync* {
    switch (dataset) {
      case CsvDataset.tasks:
        yield const [
          'id', 'title', 'description', 'completed', 'created_at_utc',
          'list_id', 'list_title', 'priority', 'tags',
          'due_kind', 'due_date', 'due_time', 'due_timezone',
          'due_instant_utc', 'due_offset_seconds',
          'recurrence_kind', 'recurrence_interval',
          'time_blocks_json', 'subtasks_json',
        ];
        final titles = {for (final list in data.lists) list.id: list.title};
        for (final item in data.tasks) {
          yield [
            item.id,
            item.title,
            item.description,
            item.completed ? 'true' : 'false',
            _utc(item.createdAt),
            item.listId ?? '',
            titles[item.listId] ?? '',
            item.priority.toString(),
            jsonEncode(item.tags),
            item.due.kind,
            item.due.date ?? '',
            item.due.time ?? '',
            item.due.timeZone ?? '',
            item.due.instant == null ? '' : _utc(item.due.instant!),
            item.due.offsetSeconds?.toString() ?? '',
            item.recurrence.kind,
            item.recurrence.enabled ? item.recurrence.interval.toString() : '',
            jsonEncode(TimeSlotCollection.toJson(item.timeBlocks)),
            jsonEncode(item.subtasks.map((sub) => sub.toJson()).toList()),
          ];
        }
      case CsvDataset.notes:
        yield const ['id', 'title', 'body', 'created_at_utc'];
        // The snapshot includes trashedNotes separately; never export them.
        for (final item in data.notes) {
          yield [item.id, item.title, item.body, _utc(item.createdAt)];
        }
      case CsvDataset.lists:
        yield const ['id', 'title', 'created_at_utc', 'task_count'];
        final counts = <String, int>{};
        for (final task in data.tasks) {
          final id = task.listId;
          if (id != null) counts[id] = (counts[id] ?? 0) + 1;
        }
        for (final item in data.lists) {
          yield [
            item.id,
            item.title,
            _utc(item.createdAt),
            (counts[item.id] ?? 0).toString(),
          ];
        }
    }
  }

  static String _utc(DateTime value) => value.toUtc().toIso8601String();

  static String _cell(String value) {
    // Excel and other spreadsheet programs can evaluate cells after CSV
    // import, even when quoted. Include leading whitespace/control chars.
    final visible = value.replaceFirst(
      RegExp(r'^[\s\u200B-\u200D\uFEFF]*'), '');
    final dangerous = visible.isNotEmpty &&
        '=+-@'.contains(visible.substring(0, 1));
    final startsControl = value.startsWith('\t') ||
        value.startsWith('\r') || value.startsWith('\n');
    final safe = (dangerous || startsControl) ? "'$value" : value;
    return '"${safe.replaceAll('"', '""')}"';
  }
