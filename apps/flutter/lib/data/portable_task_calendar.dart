import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'models.dart';

/// One-way RFC 5545 calendar export; never authorizes or syncs external APIs.
/// The file contains task titles and scheduling metadata: treat as personal.
class PortableTaskCalendar {
  const PortableTaskCalendar(this.tasks);

  static const maxEvents = 10000;
  static const maxBytes = 8 * 1024 * 1024;
  final Iterable<LocalTask> tasks;

  List<int> encode({DateTime? generatedAt}) {
    final timestamp = _timestamp((generatedAt ?? DateTime.now()).toUtc());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Simple Notes//Offline calendar export//IT',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:Simple Notes',
    ];
    var events = 0;
    for (final task in tasks) {
      if (task.completed) continue;
      if (task.due.kind != 'none') {
        final rawDay = task.due.kind == 'date' ? task.due.date : null;
        final day = rawDay == null ? null : _civil(rawDay);
        final instant = task.due.instant;
        if (day != null) {
          _addEvent(lines, key: '${task.id}/due', title: task.title,
            stamp: timestamp,
            start: 'DTSTART;VALUE=DATE:$day',
            end: 'DTEND;VALUE=DATE:${_nextDay(day)}');
          events++;
        } else if (instant != null) {
          _addEvent(lines, key: '${task.id}/due', title: task.title,
            stamp: timestamp, start: 'DTSTART:${_timestamp(instant)}');
          events++;
        }
      }
      for (final slot in task.timeBlocks) {
        _addEvent(lines,
          key: '${task.id}/block/${slot.id}',
          title: task.title, stamp: timestamp,
          start: 'DTSTART:${_timestamp(slot.block.start)}',
          end: 'DTEND:${_timestamp(slot.block.end)}');
        events++;
      }
      if (events > maxEvents) {
        throw const FormatException('Troppi eventi per il calendario.');
      }
      if (lines.fold<int>(0, (n, value) => n + value.length) > maxBytes) {
        throw const FormatException('Calendario troppo grande.');
      }
    }
    lines.add('END:VCALENDAR');
    final folded = lines.map(_fold).join('\r\n');
    final bytes = utf8.encode('$folded\r\n');
    if (bytes.length > maxBytes) {
      throw const FormatException('Calendario troppo grande (8 MB).');
    }
    return bytes;
  }

  static void _addEvent(List<String> lines, {
    required String key,
    required String title,
    required String stamp,
    required String start,
    String? end,
  }) {
    final digest = crypto.sha256.convert(utf8.encode(key));
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:$digest@simple-notes.local',
      'DTSTAMP:$stamp',
      'SUMMARY:${_escape(title)}',
      start,
      if (end != null) end,
      'END:VEVENT',
    ]);
  }

  static String _civil(String source) {
    final date = DateTime.tryParse(source);
    if (date == null || source.length != 10 ||
        date.toIso8601String().substring(0, 10) != source) {
      throw const FormatException('Scadenza civile non valida.');
    }
    return source.replaceAll('-', '');
  }

  static String _nextDay(String compact) {
    final year = int.parse(compact.substring(0, 4));
    final month = int.parse(compact.substring(4, 6));
    final day = int.parse(compact.substring(6, 8));
    final tomorrow = DateTime.utc(year, month, day + 1);
    return '${tomorrow.year.toString().padLeft(4, '0')}'
        '${tomorrow.month.toString().padLeft(2, '0')}'
        '${tomorrow.day.toString().padLeft(2, '0')}';
  }

  static String _timestamp(DateTime time) {
    final value = time.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}'
        '${two(value.month)}${two(value.day)}T'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}Z';
  }

  static String _escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');

  /// Fold at <=75 *UTF-8 octets*, never splitting a multibyte code point.
  /// A continuation starts with one space (counted in the 75-octet limit).
  static String _fold(String line) {
    final parts = <String>[];
    var segment = '';
    var usedBytes = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final width = utf8.encode(character).length;
      if (usedBytes + width > 75) {
        parts.add(segment);
        segment = ' ';
        usedBytes = 1;
      }
      segment += character;
      usedBytes += width;
    }
    parts.add(segment);
    return parts.join('\r\n');
  }
}
