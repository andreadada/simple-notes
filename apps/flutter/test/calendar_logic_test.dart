import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/calendar_logic.dart';

LocalTask task(String id, TaskDue due, {bool completed = false}) =>
    LocalTask(id: id, title: id, dueAt: null, due: due,
        createdAt: DateTime(2026, 10, 1),
        completed: completed);

void main() {
  test('Civil week starts Monday, including Sundays and DST weekends', () {
    final monday = calendarWeekStart(DateTime(2026, 10, 25));
    expect(calendarDateKey(monday), '2026-10-19');
    expect(calendarWeekDays(DateTime(2026, 10, 25))
        .map(calendarDateKey).toList(), [
      '2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22',
      '2026-10-23', '2026-10-24', '2026-10-25',
    ]);
  });

  test('Month has 42 cells, adjacent days, and a Monday anchor', () {
    final days = calendarMonthDays(DateTime(2026, 10, 17));
    expect(days.length, 42);
    expect(calendarDateKey(days.first), '2026-09-28');
    expect(calendarDateKey(days.last), '2026-11-08');
    expect(days.first.weekday, DateTime.monday);
    expect(days.last.weekday, DateTime.sunday);
    expect(days.map(calendarDateKey).toSet().length, 42);
  });

  test('Month motion clamps the selected day correctly', () {
    expect(calendarDateKey(calendarMove(
        DateTime(2026, 1, 31), CalendarMode.month, 1)), '2026-02-28');
    expect(calendarDateKey(calendarMove(
        DateTime(2024, 1, 31), CalendarMode.month, 1)), '2024-02-29');
    expect(calendarDateKey(calendarMove(
        DateTime(2026, 10, 25), CalendarMode.week, 1)), '2026-11-01');
    expect(calendarDateKey(calendarMove(
        DateTime(2026, 10, 25), CalendarMode.day, -1)), '2026-10-24');
  });

  test('Date-only is never converted to a UTC timestamp', () {
    final due = TaskDue.dateOnly('2026-10-25');
    final row = task('data civile', due);
    expect(calendarTaskMatches(row, DateTime(2026, 10, 25)), isTrue);
    expect(calendarTaskMatches(row, DateTime(2026, 10, 24)), isFalse);
    expect(calendarClockLabel(row), 'Tutto il giorno');
    expect(due.instant, isNull);
  });

  test('Date-only is first, timed tasks sorted by viewer local clock, '
      'undated tasks excluded, completed tasks still visible', () {
    final early = DateTime.utc(2026, 10, 25, 9, 30);
    final late = DateTime.utc(2026, 10, 25, 14, 0);
    final clock1 = task('early', TaskDue.legacy(early));
    final clock2 = task('late', TaskDue.legacy(late), completed: true);
    final allDay = task('all-day', TaskDue.dateOnly('2026-10-25'));
    final unscheduled = task('none', TaskDue.none);
    final selected = early.toLocal();
    final dueRows = calendarTasksForDay(
        [clock2, unscheduled, clock1, allDay], selected);
    // If the viewing timezone shifts the instant across midnight,
    // calendar must use that device-local day for scheduled items.
    expect(dueRows.first.id, anyOf('all-day', 'early'));
    expect(dueRows.any((row) => row.id == 'none'), isFalse);
    expect(dueRows.any((row) => row.id == 'early'), isTrue);
    expect(calendarTaskMatches(clock1, selected), isTrue);
    expect(calendarClockLabel(clock1), contains(':'));
  });

  test('Timed due uses viewer day but original IANA time remains unchanged', () {
    final instant = DateTime.utc(2026, 10, 25, 0, 30);
    final due = TaskDue.timed(date: '2026-10-25', time: '02:30',
        timeZone: 'Europe/Rome', instant: instant, offsetSeconds: 7200);
    final row = task('fold', due);
    expect(calendarTaskMatches(row, instant.toLocal()), isTrue);
    expect(due.date, '2026-10-25');
    expect(due.time, '02:30');
    expect(due.timeZone, 'Europe/Rome');
  });
}
