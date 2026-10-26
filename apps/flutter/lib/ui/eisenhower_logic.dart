import '../data/models.dart';

/// P1.8: deterministic read-only projection of already synchronized fields.
/// Urgency comes from the due date, importance from P2/P3 priority.
/// Editing either field is done by existing LocalStore writes and outbox.
enum EisenhowerQuadrant { doNow, schedule, delegate, eliminate }

extension EisenhowerQuadrantLabel on EisenhowerQuadrant {
  String get label => switch (this) {
    EisenhowerQuadrant.doNow => 'Fai subito',
    EisenhowerQuadrant.schedule => 'Pianifica',
    EisenhowerQuadrant.delegate => 'Delega',
    EisenhowerQuadrant.eliminate => 'Valuta / elimina',
  };

  String get description => switch (this) {
    EisenhowerQuadrant.doNow => 'Urgente · importante',
    EisenhowerQuadrant.schedule => 'Non urgente · importante',
    EisenhowerQuadrant.delegate => 'Urgente · meno importante',
    EisenhowerQuadrant.eliminate => 'Non urgente · meno importante',
  };
}

abstract final class EisenhowerLogic {
  /// P2/P3 are important; normal/P1 are less important.
  static bool isImportant(LocalTask task) => task.priority >= 2;

  /// Timed/legacy due dates: overdue or within 48 hours from now.
  /// Date-only is a CIVIL day (today, tomorrow or overdue), not an invented
  /// midnight instant. An undated task is never automatically urgent.
  static bool isUrgent(LocalTask task, DateTime now) {
    final due = task.due;
    if (due.kind == 'date') {
      final civil = DateTime.tryParse(due.date ?? '');
      if (civil == null) return false;
      final today = DateTime(now.year, now.month, now.day);
      final lastUrgent = DateTime(today.year, today.month, today.day + 1);
      return !DateTime(civil.year, civil.month, civil.day).isAfter(lastUrgent);
    }
    if (due.kind == 'datetime' || due.kind == 'legacy') {
      final instant = due.instant;
      return instant != null &&
          !instant.toUtc().isAfter(now.toUtc().add(const Duration(hours: 48)));
    }
    return false;
  }

  static EisenhowerQuadrant classify(LocalTask task, DateTime now) {
    final urgent = isUrgent(task, now);
    final important = isImportant(task);
    if (urgent && important) return EisenhowerQuadrant.doNow;
    if (important) return EisenhowerQuadrant.schedule;
    if (urgent) return EisenhowerQuadrant.delegate;
    return EisenhowerQuadrant.eliminate;
  }

  /// Excludes completed tasks (including a recurring task advanced to its
  /// next occurrence by LocalStore). Leaves SQLite and sync untouched.
  static Map<EisenhowerQuadrant, List<LocalTask>> group(
      Iterable<LocalTask> tasks, DateTime now) {
    final result = {
      for (final quadrant in EisenhowerQuadrant.values)
        quadrant: <LocalTask>[],
    };
    for (final task in tasks) {
      if (!task.completed) result[classify(task, now)]!.add(task);
    }
    for (final items in result.values) {
      items.sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        if (priority != 0) return priority;
        final aDue = a.due.kind == 'date'
            ? a.due.date : a.due.instant?.toUtc().toIso8601String();
        final bDue = b.due.kind == 'date'
            ? b.due.date : b.due.instant?.toUtc().toIso8601String();
        if (aDue == null && bDue != null) return 1;
        if (aDue != null && bDue == null) return -1;
        if (aDue != null && bDue != null) {
          final order = aDue.compareTo(bDue);
          if (order != 0) return order;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    }
    return result;
  }
}
