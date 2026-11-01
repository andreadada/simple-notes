/// Bounded, deliberately strict RFC5545 recurrence-rule subset.
/// Unsupported BY* expansions are rejected instead of showing partial data.
enum IcsFrequency { daily, weekly, monthly, yearly }

DateTime icsCivil(String day) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
    throw const FormatException('Data civile ICS non valida.');
  }
  final p = day.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]);
  if (d.year != p[0] || d.month != p[1] || d.day != p[2]) {
    throw const FormatException('Data civile ICS inesistente.');
  }
  return d;
}

String icsCivilKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class IcsRule {
  IcsRule._(this.frequency, this.interval, this.count, this.until,
      this.weekdays, this.raw);
  final IcsFrequency frequency;
  final int interval;
  final int? count;
  final String? until; // Inclusive DATE or UTC DATE-TIME.
  final List<int> weekdays; // ISO weekdays 1-7, only for WEEKLY.
  final String raw;

  static IcsRule parse(String raw, {required bool allDay,
      required String anchorDay, required int anchorWeekday}) {
    final parts = <String, String>{};
    for (final piece in raw.split(';')) {
      final eq = piece.indexOf('=');
      if (eq < 1 || eq == piece.length - 1) {
        throw const FormatException('RRULE ICS non valida.');
      }
      final key = piece.substring(0, eq).toUpperCase();
      if (!const {'FREQ', 'INTERVAL', 'COUNT', 'UNTIL', 'BYDAY'}
          .contains(key) || parts.containsKey(key)) {
        throw const FormatException('Parte RRULE non supportata o duplicata.');
      }
      parts[key] = piece.substring(eq + 1).toUpperCase();
    }
    const freqs = {
      'DAILY': IcsFrequency.daily, 'WEEKLY': IcsFrequency.weekly,
      'MONTHLY': IcsFrequency.monthly, 'YEARLY': IcsFrequency.yearly,
    };
    final frequency = freqs[parts['FREQ']];
    if (frequency == null) {
      throw const FormatException('FREQ ICS non supportata.');
    }
    int positive(String? value, int fallback, int max) {
      if (value == null) return fallback;
      final number = int.tryParse(value);
      if (number == null || number < 1 || number > max ||
          !RegExp(r'^\d+$').hasMatch(value)) {
        throw const FormatException('Valore RRULE fuori limite.');
      }
      return number;
    }
    final interval = positive(parts['INTERVAL'], 1, 100);
    final count = parts['COUNT'] == null ? null :
        positive(parts['COUNT'], 1, 500);
    if (count != null && parts['UNTIL'] != null) {
      throw const FormatException('COUNT e UNTIL non possono coesistere.');
    }
    final until = parts['UNTIL'];
    if (until != null) {
      if (allDay) {
        if (!RegExp(r'^\d{8}$').hasMatch(until)) {
          throw const FormatException('UNTIL richiede VALUE=DATE.');
        }
        final key = '${until.substring(0, 4)}-${until.substring(4, 6)}-'
            '${until.substring(6, 8)}';
        icsCivil(key);
        if (key.compareTo(anchorDay) < 0) {
          throw const FormatException('UNTIL precede DTSTART.');
        }
      } else if (!RegExp(r'^\d{8}T\d{6}Z$').hasMatch(until)) {
        throw const FormatException('UNTIL richiede un istante UTC.');
      } else {
        final y = int.parse(until.substring(0, 4));
        final m = int.parse(until.substring(4, 6));
        final d = int.parse(until.substring(6, 8));
        final h = int.parse(until.substring(9, 11));
        final min = int.parse(until.substring(11, 13));
        final sec = int.parse(until.substring(13, 15));
        final parsed = DateTime.utc(y, m, d, h, min, sec);
        if (parsed.year != y || parsed.month != m || parsed.day != d ||
            parsed.hour != h || parsed.minute != min || parsed.second != sec) {
          throw const FormatException('UNTIL UTC non valida.');
        }
      }
    }
    const codes = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4,
      'FR': 5, 'SA': 6, 'SU': 7};
    final weekdays = <int>[];
    if (parts['BYDAY'] != null) {
      if (frequency != IcsFrequency.weekly) {
        throw const FormatException('BYDAY supportato solo con WEEKLY.');
      }
      for (final code in parts['BYDAY']!.split(',')) {
        final weekday = codes[code];
        if (weekday == null || weekdays.contains(weekday)) {
          throw const FormatException('BYDAY non supportato.');
        }
        weekdays.add(weekday);
      }
      weekdays.sort();
      if (!weekdays.contains(anchorWeekday)) {
        throw const FormatException('DTSTART non coincide con BYDAY.');
      }
    } else if (frequency == IcsFrequency.weekly) {
      weekdays.add(anchorWeekday);
    }
    return IcsRule._(frequency, interval, count, until,
        List.unmodifiable(weekdays), raw);
  }

  /// Pure civil-date matching; DST gaps are filtered by the instance resolver.
  bool matches(String date, String anchorDay) {
    final day = icsCivil(date);
    final anchor = icsCivil(anchorDay);
    if (day.isBefore(anchor)) return false;
    switch (frequency) {
      case IcsFrequency.daily:
        return day.difference(anchor).inDays % interval == 0;
      case IcsFrequency.weekly:
        final a = anchor.subtract(Duration(days: anchor.weekday - 1));
        final b = day.subtract(Duration(days: day.weekday - 1));
        return (b.difference(a).inDays ~/ 7) % interval == 0 &&
            weekdays.contains(day.weekday);
      case IcsFrequency.monthly:
        final months = (day.year - anchor.year) * 12 +
            day.month - anchor.month;
        return months % interval == 0 && day.day == anchor.day;
      case IcsFrequency.yearly:
        return (day.year - anchor.year) % interval == 0 &&
            day.month == anchor.month && day.day == anchor.day;
    }
  }
}
