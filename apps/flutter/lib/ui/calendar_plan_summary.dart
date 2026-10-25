import '../data/models.dart';
import 'calendar_logic.dart';

/// Sum actual scheduled minutes in the visible civil range.
/// Overlapping slots count separately as planned efforts; this is NOT a
/// free-time / busy-time union metric.
class CalendarPlanSummary {
  const CalendarPlanSummary({
    required this.slotCount,
    required this.plannedMinutes,
    required this.completedMinutes,
  });

  final int slotCount;
  final int plannedMinutes;
  final int completedMinutes;
}

CalendarPlanSummary calendarPlanSummary(
    Iterable<LocalTask> tasks, DateTime selected, CalendarMode mode) {
  late final DateTime first;
  late final DateTime last;
  switch (mode) {
    case CalendarMode.day:
      first = DateTime(selected.year, selected.month, selected.day);
      last = DateTime(selected.year, selected.month, selected.day + 1);
    case CalendarMode.week:
      final week = calendarWeekDays(selected);
      first = DateTime(week.first.year, week.first.month, week.first.day);
      last = DateTime(week.last.year, week.last.month, week.last.day + 1);
    case CalendarMode.month:
      first = DateTime(selected.year, selected.month, 1);
      last = DateTime(selected.year, selected.month + 1, 1);
  }
  final start = first.toUtc();
  final end = last.toUtc();
  var count = 0;
  var minutes = 0;
  var completed = 0;
  for (final task in tasks) {
    for (final slot in task.timeBlocks) {
      final block = slot.block;
      if (!block.end.isAfter(start) || !block.start.isBefore(end)) {
        continue;
      }
      final clippedStart = block.start.isBefore(start) ? start : block.start;
      final clippedEnd = block.end.isAfter(end) ? end : block.end;
      final duration = clippedEnd.difference(clippedStart).inMinutes;
      count++;
      minutes += duration;
      if (task.completed) completed += duration;
    }
  }
  return CalendarPlanSummary(slotCount: count, plannedMinutes: minutes,
      completedMinutes: completed);
}

String calendarMinutesLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return hours == 0 ? '${remainder}m' :
      remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}
