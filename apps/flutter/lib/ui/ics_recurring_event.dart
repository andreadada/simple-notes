import '../data/task_due_clock.dart';
import 'ics_calendar.dart';
import 'ics_recurrence_rule.dart';

/// One VEVENT master, a bounded RRULE, and optional instance changes.
/// No eager expansion at import: a day query visits only a few civil dates.
class IcsRecurringEvent {
  IcsRecurringEvent({
    required this.master, required this.anchorDay, required this.clock,
    required this.zone, required this.rule, this.rdates = const [],
    this.exdates = const [], this.cancelled = const [],
    this.overrides = const {},
  }) {
    _validate();
  }
  final IcsEvent master;
  final String anchorDay;
  /// HH:mm:ss from DTSTART for timed recurrence, null for all-day.
  final String? clock;
  /// null means UTC for timed recurrence; non-null is an IANA TZID.
  final String? zone;
  final IcsRule? rule;
  final List<String> rdates, exdates, cancelled;
  /// Original recurrence key -> moved/replaced instance.
  final Map<String, IcsEvent> overrides;

  bool get allDay => master.allDay;
  int get _spanDays => allDay
      ? icsCivil(master.endDay!).difference(icsCivil(master.startDay!)).inDays
      : ((master.endUtc!.difference(master.startUtc!).inHours + 23) ~/ 24) + 1;

  void _validate() {
    icsCivil(anchorDay);
    if ((allDay && (clock != null || zone != null ||
          anchorDay != master.startDay)) ||
        (!allDay && (clock == null ||
          !RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(clock!) ||
          (zone != null && !TaskDueClock.knowsZone(zone!)))) ||
        _spanDays > 7 || _spanDays < 1 ||
        rule == null && rdates.isEmpty ||
        [rdates.length, exdates.length, cancelled.length, overrides.length]
            .any((n) => n > 100)) {
      throw const FormatException('Serie ICS non supportata o troppo lunga.');
    }
    if (rule != null) {
      IcsRule.parse(rule!.raw, allDay: allDay, anchorDay: anchorDay,
          anchorWeekday: icsCivil(anchorDay).weekday);
    }
    for (final key in [...rdates, ...exdates, ...cancelled,
        ...overrides.keys]) {
      if (!_validKey(key)) {
        throw const FormatException('Eccezione ICS non valida.');
      }
    }
    if (overrides.values.any((event) =>
        event.source != master.source || event.uid != master.uid ||
        event.allDay != master.allDay)) {
      throw const FormatException('Override ICS con UID o tipo incompatibile.');
    }
  }

  bool _validKey(String key) {
    if (allDay) {
      try { icsCivil(key); return true; } catch (_) { return false; }
    }
    try {
      final parsed = DateTime.parse(key);
      return parsed.isUtc && parsed.toIso8601String() == key;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'master': master.toJson(), 'anchorDay': anchorDay,
    'clock': clock, 'zone': zone, 'rrule': rule?.raw,
    'rdates': rdates, 'exdates': exdates, 'cancelled': cancelled,
    'overrides': overrides.map((key, e) => MapEntry(key, e.toJson())),
  };

  factory IcsRecurringEvent.fromJson(Map<String, dynamic> raw) {
    try {
      final master = IcsEvent.fromJson(
          Map<String, dynamic>.from(raw['master'] as Map));
      final anchor = raw['anchorDay'] as String;
      final text = raw['rrule'] as String?;
      final rule = text == null ? null : IcsRule.parse(text,
          allDay: master.allDay, anchorDay: anchor,
          anchorWeekday: icsCivil(anchor).weekday);
      List<String> keys(String key) =>
          (raw[key] as List).map((e) => e as String).toList();
      final moves = (raw['overrides'] as Map).map((key, value) =>
          MapEntry(key as String, IcsEvent.fromJson(
              Map<String, dynamic>.from(value as Map))));
      return IcsRecurringEvent(master: master, anchorDay: anchor,
          clock: raw['clock'] as String?, zone: raw['zone'] as String?,
          rule: rule, rdates: keys('rdates'), exdates: keys('exdates'),
          cancelled: keys('cancelled'), overrides: moves);
    } on FormatException { rethrow; }
    catch (_) { throw const FormatException('Serie ICS locale non leggibile.'); }
  }

  /// Canonical occurrence identity: DATE for all-day, UTC instant otherwise.
  /// A DST gap has no instance, and a DST fold uses the first valid instant.
  String? _keyFor(String day) {
    if (allDay) return day;
    final date = icsCivil(day);
    final t = clock!.split(':').map(int.parse).toList();
    if (zone == null) {
      return DateTime.utc(date.year, date.month, date.day,
          t[0], t[1], t[2]).toIso8601String();
    }
    final possibilities = TaskDueClock.possibilities(
        day, '${clock!.substring(0, 2)}:${clock!.substring(3, 5)}', zone!);
    if (possibilities.isEmpty) return null;
    return possibilities.first.instant.add(
        Duration(seconds: t[2])).toUtc().toIso8601String();
  }

  /// Last valid COUNT occurrence, computed once per imported source.
  /// Iterate periods (not every day), cap the search to avoid runaway files.
  late final String? _lastCountKey = _computeLastCountKey();

  String? _computeLastCountKey() {
    final r = rule;
    if (r?.count == null) return null;
    final anchor = icsCivil(anchorDay);
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    var accepted = 0;
    for (var period = 0; period < 2500; period++) {
      final candidates = <DateTime>[];
      switch (r!.frequency) {
        case IcsFrequency.daily:
          candidates.add(anchor.add(Duration(days: period * r.interval)));
        case IcsFrequency.weekly:
          final start = monday.add(Duration(days: period * 7 * r.interval));
          for (final weekday in r.weekdays) {
            candidates.add(start.add(Duration(days: weekday - 1)));
          }
        case IcsFrequency.monthly:
          final first = DateTime.utc(anchor.year,
              anchor.month + period * r.interval, 1);
          final target = DateTime.utc(first.year, first.month, anchor.day);
          if (target.month == first.month) candidates.add(target);
        case IcsFrequency.yearly:
          final year = anchor.year + period * r.interval;
          final target = DateTime.utc(year, anchor.month, anchor.day);
          if (target.year == year && target.month == anchor.month) {
            candidates.add(target);
          }
      }
      for (final date in candidates) {
        if (date.isBefore(anchor)) continue;
        final key = _keyFor(icsCivilKey(date));
        if (key == null) continue;
        if (++accepted == r.count) return key;
      }
    }
    throw const FormatException('COUNT ICS supera il limite di espansione.');
  }

  bool _untilAllows(String key) {
    final until = rule?.until;
    if (until == null) return true;
    if (allDay) {
      final day = '${until.substring(0, 4)}-${until.substring(4, 6)}-'
          '${until.substring(6, 8)}';
      return key.compareTo(day) <= 0;
    }
    final text = until;
    final last = DateTime.utc(int.parse(text.substring(0, 4)),
        int.parse(text.substring(4, 6)), int.parse(text.substring(6, 8)),
        int.parse(text.substring(9, 11)), int.parse(text.substring(11, 13)),
        int.parse(text.substring(13, 15)));
    return !DateTime.parse(key).isAfter(last);
  }

  IcsEvent _instance(String key) {
    if (allDay) {
      final end = icsCivil(key).add(Duration(days: _spanDays));
      return IcsEvent(uid: '${master.uid}#${key}', title: master.title,
          source: master.source, startDay: key, endDay: icsCivilKey(end));
    }
    final start = DateTime.parse(key);
    final end = start.add(master.endUtc!.difference(master.startUtc!));
    return IcsEvent(uid: '${master.uid}#${key}', title: master.title,
        source: master.source, startUtc: start, endUtc: end);
  }

  /// A range is never materialized. Only dates whose instances could
  /// overlap the requested local day are considered.
  List<IcsEvent> onDay(DateTime day) {
    final blocked = {...exdates, ...cancelled};
    final seen = <String>{};
    final result = <IcsEvent>[];
    void append(String key) {
      if (!seen.add(key) || blocked.contains(key) ||
          overrides.containsKey(key)) return;
      final item = _instance(key);
      if (item.onDay(day)) result.add(item);
    }

    final center = DateTime.utc(day.year, day.month, day.day);
    for (var delta = -(_spanDays + 2); delta <= 2; delta++) {
      final date = icsCivilKey(center.add(Duration(days: delta)));
      if (date.compareTo(anchorDay) < 0) continue;
      if (rule != null && !rule!.matches(date, anchorDay)) continue;
      if (rule == null && date != anchorDay) continue;
      final key = _keyFor(date);
      if (key == null || !_untilAllows(key)) continue;
      final cutoff = _lastCountKey;
      if (cutoff != null) {
        final after = allDay
            ? key.compareTo(cutoff) > 0
            : DateTime.parse(key).isAfter(DateTime.parse(cutoff));
        if (after) continue;
      }
      append(key);
    }
    // RDATE entries may be located before the master start.
    for (final key in rdates) append(key);
    for (final entry in overrides.entries) {
      if (!blocked.contains(entry.key) && entry.value.onDay(day)) {
        result.add(entry.value);
      }
    }
    return result;
  }
}
