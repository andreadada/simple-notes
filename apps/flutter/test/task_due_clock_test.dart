import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/task_due_clock.dart';
import 'package:simple_notes/data/task_due_view.dart';

LocalTask _task(TaskDue due, {bool completed = false}) => LocalTask(
  id: 'test', title: 'Task', createdAt: DateTime.utc(2026, 10, 24),
  dueAt: null, due: due, completed: completed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DST spring gap in Rome is rejected without silent normalization', () {
    final candidates = TaskDueClock.possibilities(
      '2026-03-29', '02:30', 'Europe/Rome');
    expect(candidates, isEmpty);
    expect(() => TaskDueClock.resolve('2026-03-29', '02:30', 'Europe/Rome'),
      throwsFormatException);
  });

  test('DST autumn fold in Rome requires an explicit occurrence', () {
    final choices = TaskDueClock.possibilities(
      '2026-10-25', '02:30', 'Europe/Rome');
    expect(choices.length, 2);
    expect(choices[0].instant, DateTime.utc(2026, 10, 25, 0, 30));
    expect(choices[0].offsetSeconds, 7200);
    expect(choices[1].instant, DateTime.utc(2026, 10, 25, 1, 30));
    expect(choices[1].offsetSeconds, 3600);
    expect(choices[0].offsetLabel, '+02:00');
    expect(choices[1].offsetLabel, '+01:00');
    expect(() => TaskDueClock.resolve(
      '2026-10-25', '02:30', 'Europe/Rome'), throwsFormatException);
    final chosen = TaskDueClock.resolve(
      '2026-10-25', '02:30', 'Europe/Rome',
      selectedOffsetSeconds: 3600);
    expect(chosen.kind, 'datetime');
    expect(chosen.instant, DateTime.utc(2026, 10, 25, 1, 30));
    expect(chosen.time, '02:30');
  });

  test('Explicit midnight stays timed; time-less civil date has no instant', () {
    final midnight = TaskDueClock.resolve(
        '2026-10-26', '00:00', 'Europe/Rome');
    expect(midnight.kind, 'datetime');
    expect(midnight.instant, DateTime.utc(2026, 10, 25, 23));
    expect(TaskDue.dateOnly('2026-10-26').instant, isNull);
    expect(taskDueLabel(midnight), contains('00:00'));
    expect(taskDueLabel(TaskDue.dateOnly('2026-10-26')),
      isNot(contains('00:00')));
  });

  test('Invalid IANA zone or invalid 24h input cannot produce an instant', () {
    expect(TaskDueClock.knowsZone('Europe/Rome'), isTrue);
    expect(TaskDueClock.knowsZone('Mars/Olympus'), isFalse);
    expect(() => TaskDueClock.possibilities(
      '2026-10-26', '25:10', 'Europe/Rome'), throwsFormatException);
    expect(() => TaskDueClock.possibilities(
      '2026-10-26', '10:00', 'Mars/Olympus'), throwsA(isA<Exception>()));
  });

  test('Today/Next 7 are civil-day filters across a 25-hour DST day', () {
    // The 2026 autumn DST transition happens on Sunday 25 October.
    final now = DateTime(2026, 10, 24, 12);
    expect(taskInToday(_task(TaskDue.dateOnly('2026-10-24')), now),
      isTrue);
    expect(taskInToday(_task(TaskDue.dateOnly('2026-10-25')), now),
      isFalse);
    expect(taskInNextSevenDays(_task(TaskDue.dateOnly('2026-10-30')), now),
      isTrue);
    expect(taskInNextSevenDays(_task(TaskDue.dateOnly('2026-10-31')), now),
      isFalse);
    expect(taskInToday(_task(TaskDue.dateOnly('2026-10-23')), now),
      isTrue); // overdue included
    expect(taskInNextSevenDays(
      _task(TaskDue.dateOnly('2026-10-25'), completed: true), now), isFalse);
    expect(taskInToday(_task(TaskDue.none), now), isFalse);
  });

  test('Timed task is classified by local viewing day but labeled by IANA wall time', () {
    final due = TaskDueClock.resolve(
      '2026-10-26', '09:15', 'Europe/Rome');
    final label = taskDueLabel(due);
    expect(label, contains('09:15'));
    expect(label, contains('Europe/Rome'));
    final day = taskDueCalendarDay(due);
    expect(day, isNotNull);
    // Calendar view never changes the stored date, time, zone or instant.
    expect(due.date, '2026-10-26');
    expect(due.time, '09:15');
  });

  test('Legacy dates are not silently transformed on display', () {
    final old = TaskDue.legacy(DateTime.utc(2026, 10, 24, 9));
    expect(taskDueLabel(old), contains('storica'));
    expect(old.kind, 'legacy');
  });
}
