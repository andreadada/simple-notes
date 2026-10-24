import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// A single possible UTC instant for a civil clock time in an IANA zone.
class DueOccurrence {
  const DueOccurrence(this.instant, this.offsetSeconds);
  final DateTime instant;
  final int offsetSeconds;

  String get offsetLabel {
    final seconds = offsetSeconds.abs();
    final sign = offsetSeconds < 0 ? '-' : '+';
    return '$sign${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
        '${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}';
  }
}

/// Always resolve a *civil* day + HH:mm in the selected IANA time zone.
/// Do not use DateTime(year, month, day, ...) for a remote time zone.
/// 0 possibilities = DST gap; 2 possibilities = DST fold.
abstract final class TaskDueClock {
  static bool _ready = false;

  static void _initialize() {
    if (!_ready) {
      tz_data.initializeTimeZones();
      _ready = true;
    }
  }

  static bool knowsZone(String zone) {
    _initialize();
    try {
      tz.getLocation(zone);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> deviceZone() async {
    _initialize();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      if (knowsZone(info.identifier)) return info.identifier;
    } catch (_) {
      // Missing platform plugin (widget tests/web) or a Windows zone ID
      // that cannot be resolved to IANA; explicit user selection required.
    }
    return null;
  }

  static List<DueOccurrence> possibilities(
      String date, String clock, String zone) {
    TaskDue.dateOnly(date); // validates exact civil YYYY-MM-DD
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(clock)) {
      throw const FormatException('Inserisci l’orario nel formato HH:mm.');
    }
    final parts = clock.split(':').map(int.parse).toList();
    if (parts[0] > 23 || parts[1] > 59) {
      throw const FormatException('L’orario deve essere tra 00:00 e 23:59.');
    }
    _initialize();
    final location = tz.getLocation(zone);
    final civil = date.split('-').map(int.parse).toList();
    final naiveUtc = DateTime.utc(
      civil[0], civil[1], civil[2], parts[0], parts[1]);
    final offsets = <int>{};
    // Enumerate offsets on both sides of a transition. This also copes with
    // uncommon non-hourly shifts; never silently roll a DST gap forward.
    for (var h = -48; h <= 48; h += 4) {
      final sample = naiveUtc.add(Duration(hours: h));
      offsets.add(tz.TZDateTime.from(sample, location)
          .timeZoneOffset.inSeconds);
    }
    final options = <DueOccurrence>[];
    for (final offset in offsets) {
      final candidate = naiveUtc.subtract(Duration(seconds: offset));
      final local = tz.TZDateTime.from(candidate, location);
      if (local.year == civil[0] && local.month == civil[1] &&
          local.day == civil[2] && local.hour == parts[0] &&
          local.minute == parts[1] &&
          local.timeZoneOffset.inSeconds == offset) {
        options.add(DueOccurrence(candidate, offset));
      }
    }
    options.sort((a, b) => a.instant.compareTo(b.instant));
    return options;
  }

  /// Offsets must be explicitly chosen when the same local time occurs twice.
  static TaskDue resolve(String date, String clock, String zone,
      {int? selectedOffsetSeconds}) {
    final options = possibilities(date, clock, zone);
    if (options.isEmpty) {
      throw const FormatException(
          'Questo orario non esiste nel fuso selezionato (ora legale).');
    }
    if (options.length > 1 && selectedOffsetSeconds == null) {
      throw const FormatException(
          'Orario ripetuto: scegli la prima o la seconda occorrenza.');
    }
    final selected = options.where((o) =>
        selectedOffsetSeconds == null ||
        o.offsetSeconds == selectedOffsetSeconds).firstOrNull;
    if (selected == null) {
      throw const FormatException('Occorrenza oraria non valida.');
    }
    return TaskDue.timed(date: date, time: clock, timeZone: zone,
        instant: selected.instant, offsetSeconds: selected.offsetSeconds);
  }
}
