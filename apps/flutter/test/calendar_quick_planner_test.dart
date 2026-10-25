import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/calendar_quick_planner.dart';

TimeBlock block(int startHour, int startMinute, int durationMinutes, {
  String zone = 'Europe/Rome',
}) {
  final start = DateTime.utc(2026, 10, 26, startHour, startMinute);
  return TimeBlock(
    start: start, end: start.add(Duration(minutes: durationMinutes)),
    timeZone: zone,
  );
}

LocalTask task(String id, {
  String title = 'Attività', bool completed = false, int priority = 0,
  String description = '', List<String> tags = const [],
  List<LocalSubtask> subtasks = const [], List<TimeSlot> slots = const [],
}) => LocalTask(
  id: id, title: title, dueAt: null, completed: completed,
  createdAt: DateTime.utc(2026, 10, 23),
  priority: priority, description: description, tags: tags,
  subtasks: subtasks, timeBlocks: slots);

void main() {
  test('One-click planner skips overlapping sessions and retains their IDs', () {
    final existing = [
      task('first', slots: [
        TimeSlot(id: 'a', block: block(8, 0, 60)), // 09:00–10:00 Rome
      ]),
      task('second', completed: true, slots: [
        TimeSlot(id: 'b', block: block(9, 0, 30)), // 10:00–10:30 Rome
      ]),
    ];
    final before = existing.map((e) => e.toJson()).toList();
    final proposed = suggestNextFreeBlock(
      tasks: existing,
      day: DateTime(2026, 10, 26),
      now: DateTime.utc(2026, 10, 25),
      timeZone: 'Europe/Rome',
      durationMinutes: 60);
    expect(proposed, isNotNull);
    expect(proposed!.start, DateTime.utc(2026, 10, 26, 9, 30));
    expect(proposed.end, DateTime.utc(2026, 10, 26, 10, 30));
    expect(existing.map((e) => e.toJson()).toList(), before);
  });

  test('Free time accepts touching endpoints and respects local work window', () {
    final proposed = suggestNextFreeBlock(
      tasks: [task('first', slots: [
        TimeSlot(id: 'a', block: block(8, 0, 60)),
      ])],
      day: DateTime(2026, 10, 26),
      now: DateTime.utc(2026, 10, 25),
      timeZone: 'Europe/Rome',
      durationMinutes: 30);
    expect(proposed!.start, DateTime.utc(2026, 10, 26, 9));
    final endOfDay = suggestNextFreeBlock(
      tasks: const [],
      day: DateTime(2026, 10, 26),
      now: DateTime.utc(2026, 10, 26, 18, 15),
      timeZone: 'Europe/Rome',
      durationMinutes: 60);
    expect(endOfDay, isNull); // 19:15 Rome is too late for 60m until 20.
  });

  test('Planner excludes past instants, invalid zones, past dates', () {
    final today = DateTime.utc(2026, 10, 26, 8, 20);
    final p = suggestNextFreeBlock(
      tasks: [], day: DateTime(2026, 10, 26),
      now: today, timeZone: 'Europe/Rome', durationMinutes: 30);
    expect(p!.start, DateTime.utc(2026, 10, 26, 8, 30));
    expect(suggestNextFreeBlock(
      tasks: [], day: DateTime(2026, 10, 25),
      now: today, timeZone: 'Europe/Rome', durationMinutes: 30), isNull);
    expect(() => suggestNextFreeBlock(
      tasks: [], day: today, now: today,
      timeZone: 'Invalid/Zone', durationMinutes: 30), throwsFormatException);
    expect(() => suggestNextFreeBlock(
      tasks: [], day: today, now: today,
      timeZone: 'Europe/Rome', durationMinutes: 17), throwsFormatException);
  });

  test('DST: skip ambiguous fold times and gap instead of guessing UTC', () {
    final fall = suggestNextFreeBlock(
      tasks: [], day: DateTime(2026, 10, 25),
      now: DateTime.utc(2026, 10, 24),
      timeZone: 'Europe/Rome', durationMinutes: 30,
      workStartMinutes: 120, workEndMinutes: 240);
    expect(fall, isNotNull);
    expect(fall!.start, DateTime.utc(2026, 10, 25, 2)); // 03:00 CET
    final spring = suggestNextFreeBlock(
      tasks: [], day: DateTime(2027, 3, 28),
      now: DateTime.utc(2027, 3, 27),
      timeZone: 'Europe/Rome', durationMinutes: 30,
      workStartMinutes: 120, workEndMinutes: 240);
    expect(spring, isNotNull);
    expect(spring!.start, DateTime.utc(2027, 3, 28, 1)); // 03:00 CEST
  });

  test('Filters are view-only, combine status, priority, search in contents', () {
    final all = [
      task('a', title: 'Fisica 2', priority: 2, tags: ['Esame']),
      task('b', title: 'Palestra', completed: true,
          description: 'Riposo domani'),
      task('c', title: 'Spesa', priority: 1,
          subtasks: [const LocalSubtask(id: 'x', title: 'Caffè')]),
    ];
    expect(filterCalendarTasks(all).length, 3);
    expect(filterCalendarTasks(all,
      status: CalendarTaskStatus.open).map((x) => x.id), ['a', 'c']);
    expect(filterCalendarTasks(all,
      status: CalendarTaskStatus.completed).single.id, 'b');
    expect(filterCalendarTasks(all, importantOnly: true).length, 2);
    expect(filterCalendarTasks(all,
      search: '  ESAME ').single.id, 'a');
    expect(filterCalendarTasks(all,
      search: 'caffè').single.id, 'c');
    expect(filterCalendarTasks(all,
      status: CalendarTaskStatus.completed,
      importantOnly: true), isEmpty);
    expect(all.length, 3);
  });
}
