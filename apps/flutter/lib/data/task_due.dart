/// A civil date is not an instant. A legacy dueAt is never reclassified
/// based on its clock time: midnight might have been intentional.
class TaskDue {
  final String kind;
  final String? date;
  final String? time;
  final String? timeZone;
  final DateTime? instant;
  final int? offsetSeconds;

  const TaskDue._(this.kind, this.date, this.time, this.timeZone,
      this.instant, this.offsetSeconds);

  static const none = TaskDue._('none', null, null, null, null, null);

  static TaskDue legacy(DateTime? value) => value == null
      ? none : TaskDue._('legacy', null, null, null, value.toUtc(), null);

  static TaskDue dateOnly(String value) {
    _validateDate(value);
    return TaskDue._('date', value, null, null, null, null);
  }

  static TaskDue timed({
    required String date,
    required String time,
    required String timeZone,
    required DateTime instant,
    required int offsetSeconds,
  }) {
    _validateDate(date);
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      throw const FormatException('Orario HH:mm non valido');
    }
    final clock = time.split(':').map(int.parse).toList();
    if (clock[0] > 23 || clock[1] > 59 || timeZone.trim().isEmpty ||
        instant.toUtc().second != 0 || instant.toUtc().millisecond != 0) {
      throw const FormatException('Scadenza con orario non valida');
    }
    // ZoneRules on the server validates IANA gap/fold and the selected offset.
    return TaskDue._('datetime', date, time, timeZone, instant.toUtc(),
        offsetSeconds);
  }

  static void _validateDate(String date) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('Data civile non valida');
    }
    final parsed = DateTime.tryParse(date);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Data civile non valida');
    }
  }

  factory TaskDue.fromJson(Object? raw, {DateTime? oldDueAt}) {
    if (raw == null) return TaskDue.legacy(oldDueAt);
    if (raw is! Map) throw const FormatException('due non valido');
    final value = Map<String, dynamic>.from(raw);
    return switch (value['kind']) {
      'none' => TaskDue.none,
      'date' => TaskDue.dateOnly(value['date'] as String),
      'legacy' => TaskDue.legacy(DateTime.parse(value['instant'] as String)),
      'datetime' => TaskDue.timed(
          date: value['date'] as String,
          time: value['time'] as String,
          timeZone: value['timeZone'] as String,
          instant: DateTime.parse(value['instant'] as String),
          offsetSeconds: value['offsetSeconds'] as int,
        ),
      _ => throw const FormatException('Tipo scadenza sconosciuto'),
    };
  }

  factory TaskDue.fromStorage({
    required String kind,
    String? date,
    String? time,
    String? timeZone,
    int? offsetSeconds,
    DateTime? dueAt,
  }) => switch (kind) {
    'none' => TaskDue.none,
    'date' => TaskDue.dateOnly(date!),
    'datetime' => TaskDue.timed(
        date: date!, time: time!, timeZone: timeZone!,
        instant: dueAt!, offsetSeconds: offsetSeconds!),
    'legacy' => TaskDue.legacy(dueAt),
    _ => throw const FormatException('due_kind sconosciuto'),
  };

  /// Only for UI display. A date-only's local midnight must NEVER enter sync.
  DateTime? get displayLocal {
    if (kind == 'date') {
      final parts = date!.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2]);
    }
    return instant?.toLocal();
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (date != null) 'date': date,
    if (time != null) 'time': time,
    if (timeZone != null) 'timeZone': timeZone,
    if (instant != null) 'instant': instant!.toUtc().toIso8601String(),
    if (offsetSeconds != null) 'offsetSeconds': offsetSeconds,
  };

  bool get modern => kind == 'date' || kind == 'datetime';
}
