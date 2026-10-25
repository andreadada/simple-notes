import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../data/task_due_clock.dart';
import 'calendar_logic.dart';

/// P1.3: each gesture creates exactly one mutation on release. Screen
/// displacement is snapped to 15 real (UTC elapsed) minutes, not wall-clock
/// arithmetic that can accidentally choose the wrong DST fold occurrence.
const int calendarSnapMinutes = 15;

int calendarGestureMinutes(double verticalPixels, double pixelsPerHour) {
  if (pixelsPerHour <= 0 || !verticalPixels.isFinite) {
    throw ArgumentError('Invalid timeline scale');
  }
  final slots = verticalPixels * 60 /
      pixelsPerHour / calendarSnapMinutes;
  return slots.round() * calendarSnapMinutes;
}

TimeBlock calendarMoveBlock(TimeBlock block, int minutes) {
  if (minutes % calendarSnapMinutes != 0) {
    throw const FormatException('Usa spostamenti di 15 minuti.');
  }
  return TimeBlock(
    start: block.start.add(Duration(minutes: minutes)),
    end: block.end.add(Duration(minutes: minutes)),
    timeZone: block.timeZone,
  );
}

TimeBlock calendarResizeBlock(TimeBlock block, int minutes) {
  if (minutes % calendarSnapMinutes != 0) {
    throw const FormatException('Usa intervalli di 15 minuti.');
  }
  final result = TimeBlock(
    start: block.start,
    end: block.end.add(Duration(minutes: minutes)),
    timeZone: block.timeZone,
  );
  if (result.duration < const Duration(minutes: calendarSnapMinutes)) {
    throw const FormatException('Durata minima: 15 minuti.');
  }
  return result;
}

/// Moving to another day preserves the local HH:mm in the block's *saved*
/// IANA timezone, but never silently picks an ambiguous or nonexistent time.
/// The exact UTC duration is preserved, including 23/25-hour DST days.
TimeBlock calendarMoveBlockToDay(TimeBlock block, DateTime targetDay) {
  if (!TaskDueClock.knowsZone(block.timeZone)) {
    throw const FormatException('Fuso orario non riconosciuto.');
  }
  final location = tz.getLocation(block.timeZone);
  final original = tz.TZDateTime.from(block.start, location);
  final clock = '${original.hour.toString().padLeft(2, '0')}:'
      '${original.minute.toString().padLeft(2, '0')}';
  final options = TaskDueClock.possibilities(
    calendarDateKey(targetDay), clock, block.timeZone);
  if (options.isEmpty) {
    throw const FormatException(
      'L’orario di origine non esiste nel giorno selezionato (ora legale). '
      'Usa l’editor per scegliere un altro orario.');
  }
  final matchesOffset = options.where((option) =>
      option.offsetSeconds == original.timeZoneOffset.inSeconds);
  if (options.length > 1 && matchesOffset.length != 1) {
    throw const FormatException(
      'L’orario si ripete nel nuovo giorno (ora legale). '
      'Scegli esplicitamente l’occorrenza nell’editor.');
  }
  final instant = options.length == 1
      ? options.single.instant : matchesOffset.single.instant;
  return TimeBlock(start: instant, end: instant.add(block.duration),
      timeZone: block.timeZone);
}

class CalendarHourMark {
  const CalendarHourMark(this.instant, this.label, this.elapsedMinutes);
  final DateTime instant;
  final String label;
  final int elapsedMinutes;
}

/// Midnight boundaries are constructed as local civil dates; duration
/// between UTC instants can be 23, 24 or 25 hours on DST transitions.
class CalendarDayScale {
  CalendarDayScale(DateTime date)
      : start = DateTime(date.year, date.month, date.day).toUtc(),
        end = DateTime(date.year, date.month, date.day + 1).toUtc();

  final DateTime start;
  final DateTime end;

  int get minutes => end.difference(start).inMinutes;

  List<CalendarHourMark> get hours {
    final result = <CalendarHourMark>[];
    DateTime? previous;
    for (int elapsed = 0; elapsed < minutes; elapsed += 60) {
      final utc = start.add(Duration(minutes: elapsed));
      final clock = utc.toLocal();
      final label = '${clock.hour.toString().padLeft(2, '0')}:'
          '${clock.minute.toString().padLeft(2, '0')}';
      final repeated = previous != null && previous.hour == clock.hour;
      result.add(CalendarHourMark(utc,
        repeated ? '$label ${clock.timeZoneName}' : label, elapsed));
      previous = clock;
    }
    return result;
  }

  double topFor(DateTime instant, double pixelsPerHour) =>
      instant.toUtc().difference(start).inMinutes / 60 * pixelsPerHour;

  double getHeight(double pixelsPerHour) =>
      minutes / 60 * pixelsPerHour;
}

class CalendarBlockGeometry {
  const CalendarBlockGeometry({
    required this.task,
    required this.top,
    required this.height,
    required this.lane,
    required this.totalLanes,
  });

  final LocalTask task;
  final double top;
  final double height;
  final int lane;
  final int totalLanes;
}

/// For overlapping blocks, allocate separate columns rather than hiding
/// one block below another. A single global lane count is deliberately
/// predictable across drag frames and narrow mobile widths.
List<CalendarBlockGeometry> calendarBlockLayout(
    Iterable<LocalTask> tasks, CalendarDayScale scale, double pixelsPerHour) {
  final visible = tasks.where((t) =>
    t.timeBlock != null &&
    t.timeBlock!.start.isBefore(scale.end) &&
    t.timeBlock!.end.isAfter(scale.start)).toList()
      ..sort((a, b) => a.timeBlock!.start.compareTo(b.timeBlock!.start));
  final laneEnds = <DateTime>[];
  final lanes = <int>[];
  for (final task in visible) {
    final start = task.timeBlock!.start;
    var lane = laneEnds.indexWhere((end) => !end.isAfter(start));
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(task.timeBlock!.end);
    } else {
      laneEnds[lane] = task.timeBlock!.end;
    }
    lanes.add(lane);
  }
  final count = laneEnds.isEmpty ? 1 : laneEnds.length;
  return [
    for (var i = 0; i < visible.length; i++)
      CalendarBlockGeometry(
        task: visible[i],
        top: scale.topFor(
          visible[i].timeBlock!.start.isBefore(scale.start)
              ? scale.start : visible[i].timeBlock!.start, pixelsPerHour),
        height: (scale.topFor(
            visible[i].timeBlock!.end.isAfter(scale.end)
                ? scale.end : visible[i].timeBlock!.end, pixelsPerHour) -
            scale.topFor(
            visible[i].timeBlock!.start.isBefore(scale.start)
                ? scale.start : visible[i].timeBlock!.start, pixelsPerHour)),
        lane: lanes[i],
        totalLanes: count,
      ),
  ];
}
