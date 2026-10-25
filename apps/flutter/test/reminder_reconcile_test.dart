import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/reminder_planner.dart';
import 'package:simple_notes/ui/reminder_reconcile.dart';

ReminderPlan plan(String key, int id, {int hour = 12}) => ReminderPlan(
  key: key, notificationId: id, taskId: 'task',
  title: 'Studio', fireAtUtc: DateTime.utc(2026, 10, 26, hour),
  leadMinutes: 15,
);

void main() {
  test('Unchanged ledger does not reschedule duplicate reminders', () {
    final change = ReminderReconciler.diff(
      recorded: {'owner|one': 10},
      desired: [plan('owner|one', 10)],
    );
    expect(change.schedule, isEmpty);
    expect(change.cancelIds, isEmpty);
  });

  test('Completion, deletion and logout cancel stale notifications', () {
    final change = ReminderReconciler.diff(
      recorded: {'owner|one': 10, 'owner|two': 11},
      desired: const [],
    );
    expect(change.cancelIds, [10, 11]);
    expect(change.schedule, isEmpty);
  });

  test('Changing account or occurrence cancels old before scheduling new', () {
    final change = ReminderReconciler.diff(
      recorded: {'owner-a|due|old': 6},
      desired: [plan('owner-b|due|new', 17)],
    );
    expect(change.cancelIds, [6]);
    expect(change.schedule.single.notificationId, 17);
  });

  test('Replacement of notification id for same key is explicit', () {
    final change = ReminderReconciler.diff(
      recorded: {'key': 1}, desired: [plan('key', 3)],
    );
    expect(change.cancelIds, [1]);
    expect(change.schedule.single.notificationId, 3);
  });

  test('Collision of two planned keys is rejected, not silently dropped', () {
    expect(() => ReminderReconciler.diff(recorded: {},
      desired: [plan('a', 9), plan('b', 9)]), throwsFormatException);
  });
}
