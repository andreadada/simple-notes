import '../data/models.dart';

/// P1.7 domain only: no plugin, permission or background scheduling yet.
/// A ReminderPlan is a pure desired-state instruction for a future native
/// Android/Windows scheduler. Do not imply delivery without OS integration.
class ReminderPlan {
  const ReminderPlan({
    required this.key,
    required this.notificationId,
    required this.taskId,
    required this.fireAtUtc,
    required this.title,
    required this.leadMinutes,
  });

  final String key;
  final int notificationId;
  final String taskId;
  final DateTime fireAtUtc;
  final String title;
  final int leadMinutes;
}

abstract final class ReminderPlanner {
  /// Explicit choices only. Exact alarms and permission prompts are handled
  /// by platform adapters, never from a pure scheduling function.
  static const allowedLeadMinutes = {0, 5, 15, 30, 60, 1440};

  /// Notification ids must remain stable across restarts and between
  /// reschedules for an identical occurrence. 31-bit positive FNV-1a.
  static int stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = (hash ^ unit) * 0x01000193 & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  static ReminderPlan? forTaskDue(
    LocalTask task, {
    required String ownerId,
    required DateTime now,
    required int leadMinutes,
  }) {
    _validate(ownerId, leadMinutes);
    // Date-only has no clock. Never fabricate a midnight notification.
    if (task.completed || task.due.kind != 'datetime' ||
        task.due.instant == null) {
      return null;
    }
    return _build(task, ownerId, 'due', task.due.instant!,
        now, leadMinutes);
  }

  static ReminderPlan? forTimeBlock(
    LocalTask task, {
    required String ownerId,
    required String slotId,
    required DateTime now,
    required int leadMinutes,
  }) {
    _validate(ownerId, leadMinutes);
    if (task.completed) {
      return null;
    }
    final slot = task.timeBlocks.where((s) => s.id == slotId).firstOrNull;
    if (slot == null) {
      return null;
    }
    return _build(task, ownerId, 'block:${slot.id}',
        slot.block.start, now, leadMinutes);
  }

  static void _validate(String ownerId, int leadMinutes) {
    if (ownerId.trim().isEmpty || !allowedLeadMinutes.contains(leadMinutes)) {
      throw const FormatException('Impostazione promemoria non valida.');
    }
  }

  static ReminderPlan? _build(
    LocalTask task, String ownerId, String kind, DateTime target,
    DateTime now, int leadMinutes,
  ) {
    final utcTarget = target.toUtc();
    final fireAtUtc = utcTarget.subtract(Duration(minutes: leadMinutes));
    if (!fireAtUtc.isAfter(now.toUtc())) {
      return null;
    }
    final key = '$ownerId|${task.id}|$kind|'
        '${utcTarget.toIso8601String()}|$leadMinutes';
    return ReminderPlan(
      key: key,
      notificationId: stableId(key),
      taskId: task.id,
      title: task.title,
      fireAtUtc: fireAtUtc,
      leadMinutes: leadMinutes,
    );
  }

  /// Desired local schedule for all tasks. The native adapter must diff
  /// this against its own persisted ledger and cancel orphaned notifications.
  static List<ReminderPlan> desiredSchedule(
    Iterable<LocalTask> tasks, {
    required String ownerId,
    required DateTime now,
    required int dueLeadMinutes,
    required int blockLeadMinutes,
    int horizonDays = 14,
    int maxNotifications = 100,
  }) {
    if (horizonDays < 1 || horizonDays > 90 ||
        maxNotifications < 1 || maxNotifications > 500) {
      throw const FormatException('Orizzonte promemoria non valido.');
    }
    final plans = <ReminderPlan>[];
    final latest = now.toUtc().add(Duration(days: horizonDays));
    for (final task in tasks) {
      final due = forTaskDue(task, ownerId: ownerId, now: now,
          leadMinutes: dueLeadMinutes);
      if (due != null && !due.fireAtUtc.isAfter(latest)) {
        plans.add(due);
      }
      for (final slot in task.timeBlocks) {
        final scheduled = forTimeBlock(task, ownerId: ownerId,
            slotId: slot.id, now: now, leadMinutes: blockLeadMinutes);
        if (scheduled != null && !scheduled.fireAtUtc.isAfter(latest)) {
          plans.add(scheduled);
        }
      }
    }
    plans.sort((a, b) {
      final order = a.fireAtUtc.compareTo(b.fireAtUtc);
      return order != 0 ? order : a.key.compareTo(b.key);
    });
    // Avoid even rare ID collisions within the bounded OS schedule.
    final ids = <int>{};
    final result = <ReminderPlan>[];
    for (final plan in plans) {
      if (!ids.add(plan.notificationId)) {
        continue;
      }
      result.add(plan);
      if (result.length == maxNotifications) {
        break;
      }
    }
    return result;
  }
}
