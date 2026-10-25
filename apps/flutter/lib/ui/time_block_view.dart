import 'package:timezone/timezone.dart' as tz;
import '../data/models.dart';
import '../data/task_due_clock.dart';
import 'calendar_logic.dart';

/// These projections always use the *device's* calendar day. Displayed wall
/// times can use the saved IANA zone without changing the stored instants.
List<LocalTask> calendarBlocksForDay(Iterable<LocalTask> tasks, DateTime date) {
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = DateTime(date.year, date.month, date.day + 1);
  return tasks.where((task) {
    final block = task.timeBlock;
    return block != null && block.start.toLocal().isBefore(endOfDay) &&
        block.end.toLocal().isAfter(startOfDay);
  }).toList()..sort((a, b) =>
      a.timeBlock!.start.compareTo(b.timeBlock!.start));
}

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
