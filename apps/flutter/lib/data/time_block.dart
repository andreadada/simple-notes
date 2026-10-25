/// A scheduled focus interval distinct from a task's due date.
/// UTC instants preserve DST fold choices; IANA zone is retained for display.
class TimeBlock {
  final DateTime start;
  final DateTime end;
  final String timeZone;

  TimeBlock({required DateTime start, required DateTime end,
      required this.timeZone})
      : start = start.toUtc(), end = end.toUtc() {
    if (timeZone.isEmpty || timeZone.length > 128 ||
        !this.end.isAfter(this.start) ||
        this.end.difference(this.start) > const Duration(hours: 24) ||
        this.start.second != 0 || this.end.second != 0 ||
        this.start.millisecond != 0 || this.end.millisecond != 0 ||
        this.start.microsecond != 0 || this.end.microsecond != 0) {
      throw const FormatException('Intervallo orario non valido.');
    }
  }

  Duration get duration => end.difference(start);

  factory TimeBlock.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Blocco orario non valido.');
    }
    final data = Map<String, dynamic>.from(value);
    if (data['kind'] == 'none') {
      throw const FormatException('Il blocco con kind none è assente.');
    }
    if (data['kind'] != 'range') {
      throw const FormatException('Tipo blocco orario sconosciuto.');
    }
    return TimeBlock(
      start: DateTime.parse(data['start'] as String),
      end: DateTime.parse(data['end'] as String),
      timeZone: data['timeZone'] as String,
    );
  }

  static TimeBlock? optionalFromJson(Object? value) {
    if (value == null) return null; // Compatible with historic sync payloads.
    if (value is Map && value['kind'] == 'none') return null;
    return TimeBlock.fromJson(value);
  }

  Map<String, dynamic> toJson() => {
    'kind': 'range',
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'timeZone': timeZone,
  };
}
