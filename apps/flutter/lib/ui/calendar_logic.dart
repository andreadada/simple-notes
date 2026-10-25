import '../data/models.dart';
import '../data/task_due_view.dart';

/// P1.1: calendar is a projection of existing due dates, not a second
/// scheduling source. Never turn date-only into midnight UTC.
enum CalendarMode { day, week, month }

DateTime calendarCivil(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String calendarDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime calendarWeekStart(DateTime value) =>
    DateTime(value.year, value.month, value.day - value.weekday + 1);

List<DateTime> calendarWeekDays(DateTime value) {
  final monday = calendarWeekStart(value);
  return List.generate(7,
      (index) => DateTime(monday.year, monday.month, monday.day + index));
}

/// Always six complete Monday–Sunday rows. Month navigation is civil-date
/// arithmetic, not Duration(days: 30) across DST.
List<DateTime> calendarMonthDays(DateTime value) {
  final monday = calendarWeekStart(DateTime(value.year, value.month, 1));
  return List.generate(42,
      (index) => DateTime(monday.year, monday.month, monday.day + index));
}

DateTime calendarMove(DateTime value, CalendarMode mode, int delta) {
  if (mode == CalendarMode.day) {
    return DateTime(value.year, value.month, value.day + delta);
  }
  if (mode == CalendarMode.week) {
    return DateTime(value.year, value.month, value.day + (delta * 7));
  }
  final target = DateTime(value.year, value.month + delta, 1);
  final last = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month,
      value.day > last ? last : value.day);
}

DateTime? calendarTaskCivilDay(LocalTask task) =>
    taskDueCalendarDay(task.due);

bool calendarTaskMatches(LocalTask task, DateTime date) {
  final due = calendarTaskCivilDay(task);
  return due != null && calendarDateKey(due) == calendarDateKey(date);
}

int _calendarTimeOrder(LocalTask task) {
  if (task.due.kind == 'date') return -1;
  final instant = task.due.instant;
  if (instant == null) return -1;
  final local = instant.toLocal();
  return local.hour * 60 + local.minute;
}

List<LocalTask> calendarTasksForDay(Iterable<LocalTask> tasks, DateTime date) =>
    tasks.where((task) => calendarTaskMatches(task, date)).toList()
      ..sort((a, b) {
        final time = _calendarTimeOrder(a).compareTo(_calendarTimeOrder(b));
        if (time != 0) return time;
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        return a.createdAt.compareTo(b.createdAt);
      });

/// For timed events the day/time follows the device's local timezone.
/// The editor and detail label still show the original IANA wall time.
String calendarClockLabel(LocalTask task) {
  if (task.due.kind == 'date') return 'Tutto il giorno';
  final value = task.due.instant?.toLocal();
  if (value == null) return 'Senza orario';
  final clock = '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
  return task.due.kind == 'legacy' ? '$clock · storica' : clock;
}
