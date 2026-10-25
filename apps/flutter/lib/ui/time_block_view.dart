import 'package:timezone/timezone.dart' as tz;
import '../data/models.dart';
import '../data/task_due_clock.dart';
import 'calendar_logic.dart';

/// These projections always use the *device's* calendar day. Displayed wall
/// times can use the saved IANA zone without changing the stored instants.
class ScheduledSlot {
  const ScheduledSlot({required this.task, required this.slot});
  final LocalTask task;
  final TimeSlot slot;
}

List<ScheduledSlot> calendarTimeSlotsForDay(
    Iterable<LocalTask> tasks, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = DateTime(date.year, date.month, date.day + 1);
  final slots = <ScheduledSlot>[];
  for (final task in tasks) {
    for (final slot in task.timeBlocks) {
      if (slot.block.start.toLocal().isBefore(end) &&
          slot.block.end.toLocal().isAfter(start)) {
        slots.add(ScheduledSlot(task: task, slot: slot));
      }
    }
  }
  slots.sort((a, b) {
    final c = a.slot.block.start.compareTo(b.slot.block.start);
    return c != 0 ? c : a.slot.id.compareTo(b.slot.id);
  });
  return slots;
}

/// Legacy public name: tasks with multiple blocks can appear multiple times.
List<LocalTask> calendarBlocksForDay(Iterable<LocalTask> tasks, DateTime date) =>
    calendarTimeSlotsForDay(tasks, date).map((s) => s.task).toList();

String timeBlockLabel(TimeBlock? block) {
  if (block == null) return 'Pianifica blocco';
  TaskDueClock.knowsZone(block.timeZone);
  final location = tz.getLocation(block.timeZone);
  String hhmm(DateTime instant) {
    final local = tz.TZDateTime.from(instant, location);
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  final start = tz.TZDateTime.from(block.start, location);
  final finish = tz.TZDateTime.from(block.end, location);
  final endDate = calendarDateKey(finish);
  final startDate = calendarDateKey(start);
  return '${hhmm(block.start)}–${hhmm(block.end)}'
      '${startDate == endDate ? '' : ' (giorno successivo)'}'
      ' · ${block.timeZone}';
}
