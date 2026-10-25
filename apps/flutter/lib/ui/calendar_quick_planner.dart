import '../data/models.dart';
import '../data/task_due_clock.dart';
import 'calendar_logic.dart';

/// Filters are view-only. They never mutate or delete task records.
enum CalendarTaskStatus { all, open, completed }

List<LocalTask> filterCalendarTasks(
  Iterable<LocalTask> tasks, {
  CalendarTaskStatus status = CalendarTaskStatus.all,
  String search = '',
  bool importantOnly = false,
}) {
  final needle = search.trim().toLowerCase();
  return tasks.where((task) {
    if (status == CalendarTaskStatus.open && task.completed) return false;
    if (status == CalendarTaskStatus.completed && !task.completed) {
      return false;
    }
    if (importantOnly && task.priority < 1) return false;
    if (needle.isEmpty) return true;
    final text = [
      task.title, task.description,
      ...task.tags,
      ...task.subtasks.map((subtask) => subtask.title),
    ].join(' ').toLowerCase();
    return text.contains(needle);
  }).toList();
}

/// Suggests the first free, 15-minute-aligned session within the *civil*
/// working-day window in the given IANA timezone. No UTC +24h assumptions
/// for workday boundaries or the DST spring/fall transitions.
///
/// Existing sessions, including completed tasks and overnight intervals,
/// reserve their time; touching endpoints are not considered overlapping.
/// Returns null without ever writing to local storage or sync outbox.
TimeBlock? suggestNextFreeBlock({
  required Iterable<LocalTask> tasks,
  required DateTime day,
  required DateTime now,
  required String timeZone,
  required int durationMinutes,
  int workStartMinutes = 9 * 60,
  int workEndMinutes = 20 * 60,
}) {
  if (durationMinutes < 15 || durationMinutes > 180 ||
      durationMinutes % 15 != 0 ||
      workStartMinutes < 0 || workEndMinutes > 1440 ||
      workStartMinutes >= workEndMinutes ||
      workStartMinutes % 15 != 0 || workEndMinutes % 15 != 0) {
    throw const FormatException('Durata o orario di pianificazione non valido.');
  }
  if (!TaskDueClock.knowsZone(timeZone)) {
    throw const FormatException('Fuso IANA non riconosciuto.');
  }
  final busy = [
    for (final task in tasks)
      for (final slot in task.timeBlocks) slot.block,
  ]..sort((a, b) => a.start.compareTo(b.start));

  final date = calendarDateKey(day);
  final utcNow = now.toUtc();

  String clock(int total) =>
      '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';

  for (var minute = workStartMinutes;
      minute + durationMinutes <= workEndMinutes; minute += 15) {
    final starts = TaskDueClock.possibilities(
        date, clock(minute), timeZone);
    final ends = TaskDueClock.possibilities(
        date, clock(minute + durationMinutes), timeZone);
    // Never guess between the two occurrences of a DST fold, or silently
    // adjust a nonexistent civil time at a DST gap.
    if (starts.length != 1 || ends.length != 1) continue;
    final start = starts.single.instant;
    final end = ends.single.instant;
    if (start.isBefore(utcNow) ||
        end.difference(start).inMinutes != durationMinutes) {
      continue;
    }
    if (busy.any((block) =>
        block.start.isBefore(end) && block.end.isAfter(start))) {
      continue;
    }
    return TimeBlock(start: start, end: end, timeZone: timeZone);
  }
  return null;
}
