import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/ui/calendar_logic.dart';
import 'package:simple_notes/ui/calendar_plan_summary.dart';

void main() {
  test('Day and week totals count independent slots, including completed', () {
    final tasks = [
      LocalTask(
        id: 'one', title: 'Done', completed: true,
        dueAt: null, createdAt: DateTime.utc(2026, 10, 20),
        timeBlocks: [
          TimeSlot(id: 'a', block: TimeBlock(
            start: DateTime.utc(2026, 10, 26, 8),
            end: DateTime.utc(2026, 10, 26, 9, 30),
            timeZone: 'Europe/Rome')),
          TimeSlot(id: 'b', block: TimeBlock(
            start: DateTime.utc(2026, 10, 26, 12),
            end: DateTime.utc(2026, 10, 26, 13),
            timeZone: 'Europe/Rome')),
        ],
      ),
      LocalTask(
        id: 'two', title: 'Pending', completed: false,
        dueAt: null, createdAt: DateTime.utc(2026, 10, 20),
        timeBlocks: [TimeSlot(id: 'c', block: TimeBlock(
          start: DateTime.utc(2026, 10, 26, 14),
          end: DateTime.utc(2026, 10, 26, 15),
          timeZone: 'Europe/Rome'))],
      ),
    ];
    final day = calendarPlanSummary(tasks, DateTime(2026, 10, 26),
        CalendarMode.day);
    expect(day.slotCount, 3);
    expect(day.plannedMinutes, 210);
    expect(day.completedMinutes, 150);
    final week = calendarPlanSummary(tasks, DateTime(2026, 10, 26),
        CalendarMode.week);
    expect(week.plannedMinutes, 210);
    expect(calendarMinutesLabel(210), '3h 30m');
    expect(calendarMinutesLabel(60), '1h');
    expect(calendarMinutesLabel(15), '15m');
  });

  test('Slots crossing month boundary contribute only visible minutes', () {
    final block = TimeBlock(
      start: DateTime(2026, 10, 31, 23, 30).toUtc(),
      end: DateTime(2026, 11, 1, 0, 30).toUtc(),
      timeZone: 'Europe/Rome');
    final task = LocalTask(
      id: 'midnight', title: 'Long study', completed: false,
      dueAt: null, createdAt: DateTime(2026, 10, 31),
      timeBlocks: [TimeSlot(id: 'a', block: block)]);
    expect(calendarPlanSummary([task], DateTime(2026, 10, 31),
        CalendarMode.month).plannedMinutes, 30);
    expect(calendarPlanSummary([task], DateTime(2026, 11, 1),
        CalendarMode.month).plannedMinutes, 30);
  });
}
