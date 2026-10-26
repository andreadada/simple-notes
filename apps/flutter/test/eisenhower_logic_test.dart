import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/eisenhower_logic.dart';

LocalTask task(String id, {int priority = 0,
    TaskDue due = TaskDue.none, bool completed = false,
    DateTime? createdAt}) => LocalTask(
  id: id, title: id, dueAt: null, due: due, completed: completed,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 1),
  priority: priority,
);

void main() {
  final now = DateTime(2026, 10, 26, 12);
  final timed = TaskDue.timed(
    date: '2026-10-27', time: '14:00', timeZone: 'Europe/Rome',
    instant: DateTime.utc(2026, 10, 27, 13), offsetSeconds: 3600);

  test('Four quadrants use synced priority and due, without a new field', () {
    expect(EisenhowerLogic.classify(task('q1', priority: 3, due: timed), now),
        EisenhowerQuadrant.doNow);
    expect(EisenhowerLogic.classify(task('q2', priority: 2), now),
        EisenhowerQuadrant.schedule);
    expect(EisenhowerLogic.classify(task('q3', priority: 1, due: timed), now),
        EisenhowerQuadrant.delegate);
    expect(EisenhowerLogic.classify(task('q4'), now),
        EisenhowerQuadrant.eliminate);
  });

  test('Date-only today, tomorrow and overdue are urgent civil days', () {
    for (final date in ['2026-10-25', '2026-10-26', '2026-10-27']) {
      expect(EisenhowerLogic.isUrgent(task(date,
          due: TaskDue.dateOnly(date)), now), isTrue);
    }
    expect(EisenhowerLogic.isUrgent(task('later',
        due: TaskDue.dateOnly('2026-10-28')), now), isFalse);
    expect(EisenhowerLogic.isUrgent(task('undated'), now), isFalse);
  });

  test('Timed deadline uses 48-hour instant, never date-only midnight', () {
    final base = DateTime.utc(2026, 10, 26, 11);
    TaskDue dated(DateTime instant) => TaskDue.timed(
      date: '2026-10-28', time: '12:00', timeZone: 'UTC',
      instant: instant, offsetSeconds: 0);
    expect(EisenhowerLogic.isUrgent(task('exact',
        due: dated(base.add(const Duration(hours: 48)))), base), isTrue);
    expect(EisenhowerLogic.isUrgent(task('later',
        due: dated(base.add(const Duration(hours: 48, seconds: 1)))), base),
        isFalse);
    expect(EisenhowerLogic.isUrgent(task('late',
        due: TaskDue.legacy(base.subtract(const Duration(days: 3)))),
        base), isTrue);
  });

  test('Completed tasks excluded; priority changes move between quadrants', () {
    final initial = [
      task('a', due: timed, priority: 1),
      task('b', due: timed, priority: 2, completed: true),
      task('c', priority: 3),
    ];
    final groups = EisenhowerLogic.group(initial, now);
    expect(groups[EisenhowerQuadrant.delegate]!.map((t) => t.id), ['a']);
    expect(groups[EisenhowerQuadrant.doNow], isEmpty);
    expect(groups[EisenhowerQuadrant.schedule]!.map((t) => t.id), ['c']);
    expect(groups.values.expand((items) => items).length, 2);
    final promoted = initial.first.copyWith(priority: 3);
    final moved = EisenhowerLogic.group([promoted, ...initial.skip(1)], now);
    expect(moved[EisenhowerQuadrant.doNow]!.single.id, 'a');
    expect(moved[EisenhowerQuadrant.delegate], isEmpty);
  });

  test('Projection does not modify task objects or their payload', () {
    final item = task('preserved', due: timed, priority: 2);
    final before = item.toJson();
    EisenhowerLogic.group([item], now);
    expect(item.toJson(), before);
  });
}
