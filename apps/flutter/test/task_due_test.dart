import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A civil due date never becomes a UTC midnight', () {
    final due = TaskDue.dateOnly('2026-10-26');
    expect(due.kind, 'date');
    expect(due.instant, isNull);
    expect(due.displayLocal!.day, 26);
    final encoded = jsonEncode(due.toJson());
    expect(encoded, isNot(contains('instant')));
    final decoded = TaskDue.fromJson(jsonDecode(encoded));
    expect(decoded.date, '2026-10-26');
    expect(decoded.instant, isNull);
  });

  test('Explicit midnight is timed, not date-only', () {
    final due = TaskDue.timed(
      date: '2026-10-26',
      time: '00:00',
      timeZone: 'Europe/Rome',
      instant: DateTime.utc(2026, 10, 25, 23),
      offsetSeconds: 3600,
    );
    expect(due.kind, 'datetime');
    expect(due.toJson()['time'], '00:00');
    expect(due.toJson()['offsetSeconds'], 3600);
  });

  test('Rome DST fold preserves both instants distinctly', () {
    final first = TaskDue.timed(
      date: '2026-10-25', time: '02:30', timeZone: 'Europe/Rome',
      instant: DateTime.utc(2026, 10, 25, 0, 30),
      offsetSeconds: 7200,
    );
    final second = TaskDue.timed(
      date: '2026-10-25', time: '02:30', timeZone: 'Europe/Rome',
      instant: DateTime.utc(2026, 10, 25, 1, 30),
      offsetSeconds: 3600,
    );
    expect(first.instant, isNot(second.instant));
    expect(TaskDue.fromJson(first.toJson()).offsetSeconds, 7200);
    expect(TaskDue.fromJson(second.toJson()).offsetSeconds, 3600);
  });

  test('Legacy local midnight remains a legacy instant', () {
    final source = DateTime(2026, 10, 24);
    final legacy = TaskDue.legacy(source);
    expect(legacy.kind, 'legacy');
    expect(legacy.instant, source.toUtc());
    expect(legacy.date, isNull);
    final fromOldWire = TaskDue.fromJson(null, oldDueAt: source);
    expect(fromOldWire.kind, 'legacy');
    expect(fromOldWire.toJson()['instant'], isNotNull);
  });

  test('Invalid civil day and clock format are rejected', () {
    expect(() => TaskDue.dateOnly('2026-02-30'), throwsFormatException);
    expect(() => TaskDue.dateOnly('2026-10-2'), throwsFormatException);
    expect(() => TaskDue.timed(
      date: '2026-10-25', time: '25:00', timeZone: 'Europe/Rome',
      instant: DateTime.utc(2026, 10, 25), offsetSeconds: 3600,
    ), throwsFormatException);
  });

  test('Drift v5 stores date-only, timed and legacy without losing outbox',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 10, 24);
    final variants = [
      TaskDue.dateOnly('2026-10-26'),
      TaskDue.timed(
        date: '2026-10-25', time: '02:30', timeZone: 'Europe/Rome',
        instant: DateTime.utc(2026, 10, 25, 0, 30),
        offsetSeconds: 7200,
      ),
      TaskDue.legacy(DateTime.utc(2026, 10, 24, 22)),
      TaskDue.none,
    ];
    for (var i = 0; i < variants.length; i++) {
      await db.upsertTask(LocalTask(
        id: 'due-$i', title: 'Scadenza $i', completed: false,
        createdAt: now, dueAt: null, due: variants[i],
      ));
    }
    expect(await db.pendingCount(), 4);
    final before = await db.pendingOperations();
    final snapshot = await db.snapshot();
    expect(snapshot.tasks.length, 4);
    for (var i = 0; i < variants.length; i++) {
      final task = snapshot.tasks.singleWhere((task) => task.id == 'due-$i');
      expect(task.due.kind, variants[i].kind);
      expect(task.due.date, variants[i].date);
      expect(task.due.instant, variants[i].instant);
    }
    expect((await db.pendingOperations()).map((op) => op.operationId).toList(),
        before.map((op) => op.operationId).toList());

    // A name-only edit must not overwrite the date-only due as legacy midnight.
    final task = snapshot.tasks.singleWhere((row) => row.id == 'due-0');
    await db.upsertTask(task.copyWith(title: 'Rinominata'));
    expect((await db.snapshot()).tasks
        .singleWhere((row) => row.id == 'due-0').due.kind, 'date');
    expect(await db.pendingCount(), 5);
  });

  test('Old task JSON and pending mutations remain readable', () {
    final old = {
      'id': 'old', 'title': 'Legacy',
      'createdAt': '2026-10-24T11:00:00.000',
      'dueAt': '2026-10-24T00:00:00.000',
      'completed': false,
    };
    final task = LocalTask.fromJson(old);
    expect(task.due.kind, 'legacy');
    expect(task.toJson()['due']['kind'], 'legacy');
    expect(task.copyWith(title: 'Edited').due.kind, 'legacy');
  });
}
