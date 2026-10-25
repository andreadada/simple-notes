import 'reminder_planner.dart';

/// Pure diff between the device ledger and the desired future reminders.
/// No permission requests, plugin calls or persistence here.
class ReminderChanges {
  const ReminderChanges({required this.cancelIds, required this.schedule});
  final List<int> cancelIds;
  final List<ReminderPlan> schedule;
}

abstract final class ReminderReconciler {
  static ReminderChanges diff({
    required Map<String, int> recorded,
    required Iterable<ReminderPlan> desired,
  }) {
    final expected = <String, ReminderPlan>{};
    final ids = <int>{};
    for (final plan in desired) {
      if (!ids.add(plan.notificationId) &&
          !expected.containsKey(plan.key)) {
        throw const FormatException('Collisione ID promemoria.');
      }
      expected[plan.key] = plan;
    }
    final obsolete = <int>[];
    for (final entry in recorded.entries) {
      final match = expected[entry.key];
      if (match == null || match.notificationId != entry.value) {
        obsolete.add(entry.value);
      }
    }
    // Cancel before scheduling, especially across account switches.
    obsolete.sort();
    final added = expected.values.where((plan) =>
        recorded[plan.key] != plan.notificationId).toList()
      ..sort((a, b) {
        final value = a.fireAtUtc.compareTo(b.fireAtUtc);
        return value == 0 ? a.key.compareTo(b.key) : value;
      });
    return ReminderChanges(cancelIds: obsolete, schedule: added);
  }
}
