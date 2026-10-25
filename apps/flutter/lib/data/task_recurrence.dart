import 'task_due.dart';
import 'task_due_clock.dart';

/// Recurrence rule stored on the task, not a second task generator.
/// Completing an occurrence advances the same task in one SQLite mutation.
/// The server never fabricates future tasks, avoiding duplicate UUIDs.
class TaskRecurrence {
  const TaskRecurrence._(this.kind, this.interval);
  final String kind;
  final int interval;

  static const none = TaskRecurrence._('none', 1);

  factory TaskRecurrence(String kind, {int interval = 1}) {
    if (!{'none', 'daily', 'weekly', 'monthly'}.contains(kind) ||
        interval < 1 || interval > 12 ||
        (kind == 'none' && interval != 1)) {
      throw const FormatException('Ricorrenza non valida (intervallo 1–12).');
    }
    return TaskRecurrence._(kind, interval);
  }

  factory TaskRecurrence.fromJson(Object? raw) {
    if (raw == null) return none;
    if (raw is! Map) throw const FormatException('Ricorrenza non valida.');
    final data = Map<String, dynamic>.from(raw);
    if (data['kind'] == 'none') return none;
    if (data['interval'] is! int) {
      throw const FormatException('Intervallo ricorrenza non valido.');
    }
    return TaskRecurrence(data['kind'] as String,
        interval: data['interval'] as int);
  }

  Map<String, dynamic> toJson() => {'kind': kind,
    if (kind != 'none') 'interval': interval};

  bool get enabled => kind != 'none';

  /// Always advance *civil* dates, never add 24h UTC across DST.
  /// Monthly recurrence clamps to the target month's last day.
  String nextDate(String date) {
    if (!enabled) throw const FormatException('Ricorrenza disabilitata.');
    final from = DateTime.parse('${date}T12:00:00Z');
    DateTime next;
    if (kind == 'daily') {
      next = DateTime.utc(from.year, from.month, from.day + interval);
    } else if (kind == 'weekly') {
      next = DateTime.utc(from.year, from.month, from.day + interval * 7);
    } else {
      final firstOfMonth = DateTime.utc(from.year, from.month + interval);
      final maxDay = DateTime.utc(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
      next = DateTime.utc(firstOfMonth.year, firstOfMonth.month,
          from.day > maxDay ? maxDay : from.day);
    }
    return '${next.year.toString().padLeft(4, '0')}-'
        '${next.month.toString().padLeft(2, '0')}-'
        '${next.day.toString().padLeft(2, '0')}';
  }

  /// DST gap dates are skipped. In a fold, prefer the matching old UTC
  /// offset (when possible), otherwise the earliest instant; deterministic.
  TaskDue advance(TaskDue due) {
    if (!enabled || !due.modern) {
      throw const FormatException('Aggiungi una scadenza moderna per ripetere.');
    }
    var next = due.date!;
    for (var i = 0; i < 16; i++) {
      next = nextDate(next);
      if (due.kind == 'date') return TaskDue.dateOnly(next);
      final options = TaskDueClock.possibilities(
          next, due.time!, due.timeZone!);
      if (options.isEmpty) continue;
      final matching = options.where((candidate) =>
          candidate.offsetSeconds == due.offsetSeconds);
      final selected = matching.isNotEmpty ? matching.first : options.first;
      return TaskDue.timed(date: next, time: due.time!,
          timeZone: due.timeZone!, instant: selected.instant,
          offsetSeconds: selected.offsetSeconds);
    }
    throw const FormatException('Nessuna occorrenza valida nel fuso IANA.');
  }

  String get label => switch (kind) {
    'daily' => interval == 1 ? 'Ogni giorno' : 'Ogni $interval giorni',
    'weekly' => interval == 1 ? 'Ogni settimana' : 'Ogni $interval settimane',
    'monthly' => interval == 1 ? 'Ogni mese' : 'Ogni $interval mesi',
    _ => 'Non ripetere',
  };
}
