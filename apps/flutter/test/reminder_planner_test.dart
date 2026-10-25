import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/reminder_planner.dart';

LocalTask task({
  required String id,
  TaskDue due = TaskDue.none,
  List<TimeSlot> slots = const [],
  bool completed = false,
}) => LocalTask(
  id: id, title: 'Promemoria studio', dueAt: null, due: due,
  timeBlocks: slots, completed: completed,
  createdAt: DateTime.utc(2026, 10, 20),
);

void main() {
  test('Timed task creates stable explicit UTC reminder, date-only never does',
      () {
    final due = TaskDue.timed(
      date: '2026-10-26', time: '10:00',
      timeZone: 'Europe/Rome', offsetSeconds: 3600,
      instant: DateTime.utc(2026, 10, 26, 9),
    );
    final recurring = task(id: 'x', due: due);
    final plan = ReminderPlanner.forTaskDue(recurring,
      ownerId: 'owner-a', now: DateTime.utc(2026, 10, 25),
      leadMinutes: 15);
    expect(plan!.fireAtUtc, DateTime.utc(2026, 10, 26, 8, 45));
    expect(plan.notificationId,
        ReminderPlanner.stableId(plan.key));
    expect(ReminderPlanner.forTaskDue(recurring,
      ownerId: 'owner-a', now: DateTime.utc(2026, 10, 25),
      leadMinutes: 15)!.key, plan.key);
    expect(ReminderPlanner.forTaskDue(
      task(id: 'date', due: TaskDue.dateOnly('2026-10-26')),
      ownerId: 'owner-a', now: DateTime.utc(2026, 10, 25),
      leadMinutes: 0), isNull);
    expect(ReminderPlanner.forTaskDue(
      task(id: 'done', due: due, completed: true),
      ownerId: 'owner-a', now: DateTime.utc(2026, 10, 25),
      leadMinutes: 15), isNull);
  });

  test('Time slots have independent reminder keys and no passed notification',
      () {
    final t = task(id: 'x', slots: [
      TimeSlot(id: 'a', block: TimeBlock(
        start: DateTime.utc(2026, 10, 26, 8),
        end: DateTime.utc(2026, 10, 26, 9), timeZone: 'Europe/Rome')),
      TimeSlot(id: 'b', block: TimeBlock(
        start: DateTime.utc(2026, 10, 26, 12),
        end: DateTime.utc(2026, 10, 26, 13), timeZone: 'Europe/Rome')),
    ]);
    final first = ReminderPlanner.forTimeBlock(t, ownerId: 'user',
      slotId: 'a', now: DateTime.utc(2026, 10, 25), leadMinutes: 15)!;
    final second = ReminderPlanner.forTimeBlock(t, ownerId: 'user',
      slotId: 'b', now: DateTime.utc(2026, 10, 25), leadMinutes: 15)!;
    expect(first.notificationId, isNot(second.notificationId));
    expect(first.fireAtUtc, DateTime.utc(2026, 10, 26, 7, 45));
    expect(ReminderPlanner.forTimeBlock(t,
      ownerId: 'user', slotId: 'a', now: DateTime.utc(2026, 10, 26, 8),
      leadMinutes: 15), isNull);
    expect(ReminderPlanner.forTimeBlock(t,
      ownerId: 'user', slotId: 'not-found',
      now: DateTime.utc(2026, 10, 25), leadMinutes: 0), isNull);
  });

  test('Desired plan caps horizon and notification count without side effects',
      () {
    final t = task(id: 'x', slots: [
      TimeSlot(id: 'a', block: TimeBlock(
        start: DateTime.utc(2026, 10, 26, 8),
        end: DateTime.utc(2026, 10, 26, 9), timeZone: 'Europe/Rome')),
      TimeSlot(id: 'b', block: TimeBlock(
        start: DateTime.utc(2026, 12, 26, 12),
        end: DateTime.utc(2026, 12, 26, 13), timeZone: 'Europe/Rome')),
    ]);
    final plans = ReminderPlanner.desiredSchedule([t],
      ownerId: 'one', now: DateTime.utc(2026, 10, 25),
      dueLeadMinutes: 15, blockLeadMinutes: 0, horizonDays: 14);
    expect(plans, hasLength(1));
    expect(plans.single.key, contains('block:a'));
    expect(() => ReminderPlanner.desiredSchedule([t],
      ownerId: '', now: DateTime.utc(2026, 10, 25),
      dueLeadMinutes: 15, blockLeadMinutes: 0), throwsFormatException);
    expect(() => ReminderPlanner.desiredSchedule([t],
      ownerId: 'one', now: DateTime.utc(2026, 10, 25),
      dueLeadMinutes: 13, blockLeadMinutes: 0), throwsFormatException);
  });

  test('Recurrence changes occurrence key and stable native id', () {
    final first = task(id: 'same', due: TaskDue.timed(
      date: '2026-10-26', time: '10:00', timeZone: 'Europe/Rome',
      instant: DateTime.utc(2026, 10, 26, 9), offsetSeconds: 3600));
    final advanced = task(id: 'same', due: TaskRecurrence('daily')
        .advance(first.due));
    final a = ReminderPlanner.forTaskDue(first, ownerId: 'one',
      now: DateTime.utc(2026, 10, 25), leadMinutes: 0)!;
    final b = ReminderPlanner.forTaskDue(advanced, ownerId: 'one',
      now: DateTime.utc(2026, 10, 25), leadMinutes: 0)!;
    expect(a.key, isNot(b.key));
    expect(a.notificationId, isNot(b.notificationId));
  });
}
