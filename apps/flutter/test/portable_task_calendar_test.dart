import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/portable_task_calendar.dart';

void main() {
  final created = DateTime.utc(2026, 11, 9);
  LocalTask task(String id, {TaskDue due = TaskDue.none,
    List<TimeSlot> slots = const [], bool completed = false, String? title}) =>
      LocalTask(id: id, title: title ?? id,
        dueAt: null, due: due, timeBlocks: slots,
        completed: completed, createdAt: created);

  String export(List<LocalTask> tasks) =>
      utf8.decode(PortableTaskCalendar(tasks).encode(
        generatedAt: created));

  test('all-day due remains a civil date and ends at next civil day', () {
    final value = export([task('a',
        due: TaskDue.dateOnly('2026-03-29'))]);
    expect(value, contains('DTSTART;VALUE=DATE:20260329\r\n'));
    expect(value, contains('DTEND;VALUE=DATE:20260330\r\n'));
    expect(value, isNot(contains('DTSTART:20260329T000000Z')));
    expect(value, contains('DTSTAMP:20261109T000000Z'));
    expect(value, contains('METHOD:PUBLISH'));
  });

  test('timed due uses its UTC instant without manufacturing an end', () {
    final value = export([task('t', due: TaskDue.timed(
      date: '2026-11-09', time: '18:00',
      timeZone: 'Europe/Rome', offsetSeconds: 3600,
      instant: DateTime.utc(2026, 11, 9, 17),
    ))]);
    expect(value, contains('DTSTART:20261109T170000Z\r\n'));
    expect(value, isNot(contains('DTEND:')));
  });

  test('time blocks preserve exact UTC start/end and unique stable UIDs', () {
    final t = task('t', slots: [
      TimeSlot(id: 'slot-1', block: TimeBlock(
        start: DateTime.utc(2026, 11, 9, 10),
        end: DateTime.utc(2026, 11, 9, 11),
        timeZone: 'Europe/Rome',
      )),
      TimeSlot(id: 'slot-2', block: TimeBlock(
        start: DateTime.utc(2026, 11, 10, 10),
        end: DateTime.utc(2026, 11, 10, 11),
        timeZone: 'Europe/Rome',
      )),
    ]);
    final value = export([t]);
    expect(RegExp('BEGIN:VEVENT').allMatches(value).length, 2);
    expect(value, contains('DTSTART:20261109T100000Z'));
    expect(value, contains('DTEND:20261109T110000Z'));
    expect(RegExp('UID:[a-f0-9]+@simple-notes.local')
        .allMatches(value).map((m) => m.group(0)).toSet().length, 2);
    expect(export([t]), value);
  });

  test('completed and undated tasks are excluded without mutating source',
      () {
    final values = [
      task('completed', completed: true, due: TaskDue.dateOnly('2026-11-10')),
      task('undated'),
      task('visible', due: TaskDue.dateOnly('2026-11-11')),
    ];
    final output = export(values);
    expect(RegExp('BEGIN:VEVENT').allMatches(output).length, 1);
    expect(output, contains('SUMMARY:visible'));
    expect(values, hasLength(3));
  });

  test('long multilingual titles fold at 75 UTF-8 bytes and escape syntax', () {
    final long = 'Università, studio; schemi\\ note\n'
        "${List.filled(80, 'è').join()}";
    final value = export([task('long',
      due: TaskDue.dateOnly('2026-11-09'), title: long)]);
    expect(value, contains('SUMMARY:Università\\, studio\\; schemi\\\\ note\\n'));
    for (final line in value.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
    expect(value, endsWith('END:VCALENDAR\r\n'));
  });
}
