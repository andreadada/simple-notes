import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../data/task_due_clock.dart';
import 'ics_recurring_event.dart';
import 'ics_recurrence_rule.dart';

/// Owner-scoped local key; no raw Google ID is stored in preferences keys.
String icsOwnerKey(String? owner) =>
    'simple_notes.ics.v1.${sha256.convert(utf8.encode(owner ?? 'signed-out-local'))}';

String _pad(int v) => v.toString().padLeft(2, '0');
String icsDay(DateTime d) => "${d.year.toString().padLeft(4, '0')}-${_pad(d.month)}-${_pad(d.day)}";
bool _validDay(String s) {
  final d = DateTime.tryParse(s);
  return RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(s) && d != null && icsDay(d) == s;
}

/// External event; an exclusive end, never an editable task or outbox item.
class IcsEvent {
  const IcsEvent({required this.uid, required this.title, required this.source,
      this.startDay, this.endDay, this.startUtc, this.endUtc});
  final String uid, title, source;
  final String? startDay, endDay;
  final DateTime? startUtc, endUtc;
  bool get allDay => startDay != null;
  bool onDay(DateTime d) {
    if (allDay) {
      final key = icsDay(d);
      return key.compareTo(startDay!) >= 0 && key.compareTo(endDay!) < 0;
    }
    final a = DateTime(d.year,d.month,d.day).toUtc();
    final b = DateTime(d.year,d.month,d.day+1).toUtc();
    return startUtc!.isBefore(b) && endUtc!.isAfter(a);
  }
  String get clock {
    if (allDay) return 'Tutto il giorno';
    final d = startUtc!.toLocal();
    return '${_pad(d.hour)}:${_pad(d.minute)}';
  }
  Map<String,dynamic> toJson() => {
    'uid': uid, 'title': title, 'source': source,
    'startDay': startDay, 'endDay': endDay,
    'startUtc': startUtc?.toIso8601String(), 'endUtc': endUtc?.toIso8601String(),
  };
  factory IcsEvent.fromJson(Map<String,dynamic> raw) {
    final item = IcsEvent(
      uid: raw['uid'] as String, title: raw['title'] as String,
      source: raw['source'] as String,
      startDay: raw['startDay'] as String?, endDay: raw['endDay'] as String?,
      startUtc: raw['startUtc'] == null ? null :
        DateTime.parse(raw['startUtc'] as String).toUtc(),
      endUtc: raw['endUtc'] == null ? null :
        DateTime.parse(raw['endUtc'] as String).toUtc(),
    );
    if (item.uid.isEmpty || item.title.trim().isEmpty || item.source.isEmpty ||
        (item.allDay
          ? item.endDay == null || !_validDay(item.startDay!) ||
              !_validDay(item.endDay!) ||
              item.startDay!.compareTo(item.endDay!) >= 0 ||
              item.startUtc != null || item.endUtc != null
          : item.startUtc == null || item.endUtc == null ||
              item.endDay != null || !item.endUtc!.isAfter(item.startUtc!))) {
      throw const FormatException('Evento ICS locale non valido.');
    }
    return item;
  }
}

/// A stable source identity is distinct from the display name and event UID.
/// URL feeds are fetched only after an explicit user action.
enum IcsSourceKind { file, url }

String _legacyFileId(String name) =>
    'file-${sha256.convert(utf8.encode(name)).toString().substring(0, 32)}';

bool _validSubscriptionUrl(String? text) {
  if (text == null || text.length > 2048) return false;
  final uri = Uri.tryParse(text);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
      uri.userInfo.isEmpty && !uri.hasFragment;
}

class IcsCalendar {
  /// The parser returns an unnamed-in-storage file candidate (id='').
  /// The library assigns an identity on import, preserving it on reimport.
  const IcsCalendar(this.name, this.events,
      {this.id = '', this.kind = IcsSourceKind.file, this.sourceUrl,
       this.series = const [], this.lastFetchedUtc});
  final String id, name;
  final IcsSourceKind kind;
  /// Private feed URL; never expose full URLs with query tokens in UI/logs.
  final String? sourceUrl;
  /// Optional last successful refresh time; null for legacy URL metadata.
  final DateTime? lastFetchedUtc;
  final List<IcsEvent> events;
  final List<IcsRecurringEvent> series;

  IcsCalendar withId(String value) =>
      IcsCalendar(name, events, id: value, kind: kind, sourceUrl: sourceUrl,
          series: series, lastFetchedUtc: lastFetchedUtc);

  Map<String, dynamic> toJson() => {
    'id': id.isEmpty ? _legacyFileId(name) : id,
    'kind': kind.name,
    'name': name,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (lastFetchedUtc != null)
      'lastFetchedUtc': lastFetchedUtc!.toUtc().toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
    if (series.isNotEmpty)
      'series': series.map((item) => item.toJson()).toList(),
  };

  factory IcsCalendar.fromJson(Map<String, dynamic> raw,
      {required int schema}) {
    final name = raw['name'] as String;
    final id = schema == 1 ? _legacyFileId(name) : raw['id'] as String;
    final kind = schema == 1 ? IcsSourceKind.file :
        IcsSourceKind.values.byName(raw['kind'] as String);
    final sourceUrl = schema == 1 ? null : raw['sourceUrl'] as String?;
    final rawFetched = raw['lastFetchedUtc'] as String?;
    final fetched = rawFetched == null ? null : DateTime.parse(rawFetched);
    if (rawFetched != null && (!fetched!.isUtc ||
        fetched.toIso8601String() != rawFetched)) {
      throw const FormatException('Timestamp refresh ICS non valido.');
    }
    final events = (raw['events'] as List).map((e) =>
        IcsEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final series = schema == 3 && raw['series'] != null
        ? (raw['series'] as List).map((item) => IcsRecurringEvent.fromJson(
            Map<String, dynamic>.from(item as Map))).toList()
        : <IcsRecurringEvent>[];
    if (name.trim().isEmpty || name.length > 180 ||
        !RegExp(r'^[a-zA-Z0-9._:-]{1,128}$').hasMatch(id) ||
        (events.isEmpty && series.isEmpty) ||
        events.length + series.length > IcsParser.maxEvents ||
        events.any((e) => e.source != name) ||
        series.any((s) => s.master.source != name) ||
        {...events.map((e) => e.uid), ...series.map((s) => s.master.uid)}
            .length != events.length + series.length ||
        (kind == IcsSourceKind.file &&
            (sourceUrl != null || fetched != null)) ||
        (kind == IcsSourceKind.url && !_validSubscriptionUrl(sourceUrl))) {
      throw const FormatException('Sorgente calendario ICS non valida.');
    }
    return IcsCalendar(name, List.unmodifiable(events), id: id,
        kind: kind, sourceUrl: sourceUrl, series: List.unmodifiable(series),
        lastFetchedUtc: fetched);
  }
}

class IcsLibrary {
  const IcsLibrary([this.calendars = const []]);
  static const maxSources = 5;
  final List<IcsCalendar> calendars;
  int get eventCount => calendars.fold(
      0, (int sum, IcsCalendar c) => sum + c.events.length + c.series.length);
  List<IcsEvent> onDay(DateTime day) => [
    for (final c in calendars) ...[
      for (final e in c.events) if (e.onDay(day)) e,
      for (final group in c.series) ...group.onDay(day),
    ],
  ]..sort((a, b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.allDay ? a.title.compareTo(b.title) :
        a.startUtc!.compareTo(b.startUtc!);
  });

  /// File reimports reuse identity by filename; URL sources match by id only.
  /// No changes are persisted until the caller confirms and saves.
  IcsLibrary replace(IcsCalendar calendar) {
    IcsCalendar? existing;
    for (final item in calendars) {
      if ((calendar.id.isNotEmpty && item.id == calendar.id) ||
          (calendar.kind == IcsSourceKind.file &&
           item.kind == IcsSourceKind.file && item.name == calendar.name) ||
          (calendar.kind == IcsSourceKind.url &&
           item.kind == IcsSourceKind.url &&
           item.sourceUrl == calendar.sourceUrl)) {
        existing = item;
        break;
      }
    }
    if (existing != null && existing.kind != calendar.kind) {
      throw const FormatException('Tipo sorgente ICS non compatibile.');
    }
    final id = existing == null ?
        (calendar.id.isEmpty ? const Uuid().v4() : calendar.id) :
        (existing.id.isEmpty ? _legacyFileId(existing.name) : existing.id);
    final candidate = IcsCalendar.fromJson(calendar.withId(id).toJson(),
        schema: 3);
    final rest = calendars.where((c) => !identical(c, existing)).toList();
    if (rest.length >= maxSources) {
      throw const FormatException('Massimo cinque calendari ICS.');
    }
    return IcsLibrary(List.unmodifiable([...rest, candidate]));
  }

  /// Remove exactly one source, even if a future URL feed shares a file label.
  IcsLibrary removeById(String id) => IcsLibrary(List.unmodifiable(
      calendars.where((c) => c.id != id)));

  /// Compatibility helper for pre-P2.3 file-only callers.
  IcsLibrary remove(String name) => IcsLibrary(List.unmodifiable(
      calendars.where((c) =>
          !(c.kind == IcsSourceKind.file && c.name == name))));

  /// Schema 3 is written only on an explicit user action, never on load.
  String serialize() => jsonEncode({
    'schema': 3,
    'calendars': calendars.map((c) => c.toJson()).toList(),
  });

  factory IcsLibrary.deserialize(String source) {
    try {
      final data = jsonDecode(source);
      if (data is! Map ||
          (data['schema'] != 1 && data['schema'] != 2 &&
           data['schema'] != 3) ||
          data['calendars'] is! List) {
        throw const FormatException('Versione archivio ICS non supportata.');
      }
      final schema = data['schema'] as int;
      final list = (data['calendars'] as List).map((item) =>
          IcsCalendar.fromJson(Map<String, dynamic>.from(item as Map),
              schema: schema)).toList();
      final ids = list.map((c) => c.id).toSet();
      final filenames = list.where((c) => c.kind == IcsSourceKind.file)
          .map((c) => c.name).toSet();
      final fileCount =
          list.where((c) => c.kind == IcsSourceKind.file).length;
      final urls = list.where((c) => c.kind == IcsSourceKind.url)
          .map((c) => c.sourceUrl).toSet();
      final urlCount = list.where((c) => c.kind == IcsSourceKind.url).length;
      if (list.length > maxSources || ids.length != list.length ||
          filenames.length != fileCount || urls.length != urlCount) {
        throw const FormatException('Troppe sorgenti ICS o identificativi duplicati.');
      }
      return IcsLibrary(List.unmodifiable(list));
    } on FormatException { rethrow; }
    catch (_) { throw const FormatException('Calendari ICS non leggibili.'); }
  }
}

class _Prop {
  const _Prop(this.value,this.zone);
  final String value;
  final String? zone;
}

/// Bounded RFC5545 subset; fails closed on unsupported recurrences/floating
/// times, unknown TZIDs and ambiguous/nonexistent local DST times.
class IcsParser {
  static const maxBytes=1024*1024;
  static const maxEvents=500;
  static IcsCalendar parse(List<int> bytes, String source) {
    if (bytes.isEmpty || bytes.length > maxBytes ||
        source.trim().isEmpty || source.length > 180) {
      throw const FormatException('File ICS vuoto, troppo grande o nome non valido.');
    }
    try {
      final name = source.trim();
      final lines = <String>[];
      final raw = utf8.decode(bytes).replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      for (final line in raw.split('\n')) {
        if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
          lines[lines.length - 1] += line.substring(1);
        } else if (line.isNotEmpty) {
          lines.add(line);
        }
      }
      if (lines.isEmpty || lines.first != 'BEGIN:VCALENDAR' ||
          lines.last != 'END:VCALENDAR') {
        throw const FormatException('Intestazione VCALENDAR assente.');
      }
      final stack = <String>[];
      final components = <Map<String, _Prop>>[];
      Map<String, _Prop>? props;
      for (final line in lines) {
        if (line.startsWith('BEGIN:')) {
          final type = line.substring(6).toUpperCase();
          stack.add(type);
          if (type == 'VEVENT' && stack.length == 2) props = {};
          continue;
        }
        if (line.startsWith('END:')) {
          final type = line.substring(4).toUpperCase();
          if (stack.isEmpty || stack.last != type) {
            throw const FormatException('Componenti ICS non bilanciati.');
          }
          if (type == 'VEVENT' && stack.length == 2) {
            if (props == null) {
              throw const FormatException('Evento privo di dati.');
            }
            components.add(props);
            if (components.length > maxEvents) {
              throw const FormatException('Massimo 500 componenti VEVENT.');
            }
            props = null;
          }
          stack.removeLast();
          continue;
        }
        if (stack.length == 2 && stack.last == 'VEVENT' && props != null) {
          final colon = line.indexOf(':');
          if (colon < 1) throw const FormatException('Proprietà ICS non valida.');
          final header = line.substring(0, colon).split(';');
          final key = header.first.toUpperCase();
          if (key == 'DURATION') {
            throw const FormatException('DURATION ICS non supportata.');
          }
          if (props.containsKey(key) &&
              !const {'RDATE', 'EXDATE'}.contains(key)) {
            throw const FormatException('Proprietà VEVENT duplicata.');
          }
          String? zone;
          for (final part in header.skip(1)) {
            if (part.toUpperCase().startsWith('TZID=')) {
              zone = part.substring(5).replaceAll('"', '');
            }
            if (key == 'RECURRENCE-ID' &&
                part.toUpperCase().startsWith('RANGE=')) {
              throw const FormatException('THISANDFUTURE non supportato.');
            }
            if (part.toUpperCase().startsWith('VALUE=PERIOD')) {
              throw const FormatException('RDATE PERIOD non supportato.');
            }
          }
          final value = line.substring(colon + 1);
          if (props.containsKey(key)) {
            final previous = props[key]!;
            if (previous.zone != zone) {
              throw const FormatException('TZID multipli sulla stessa proprietà.');
            }
            props[key] = _Prop('${previous.value},$value', zone);
          } else {
            props[key] = _Prop(value, zone);
          }
        }
      }
      if (stack.isNotEmpty || components.isEmpty) {
        throw const FormatException('Nessun evento ICS supportato.');
      }
      final grouped = <String, List<Map<String, _Prop>>>{};
      for (final item in components) {
        final uid = item['UID']?.value.trim() ?? '';
        if (uid.isEmpty) throw const FormatException('UID ICS assente.');
        grouped.putIfAbsent(uid, () => []).add(item);
      }
      final singles = <IcsEvent>[];
      final series = <IcsRecurringEvent>[];
      for (final entry in grouped.entries) {
        final masters = entry.value.where((c) =>
            !c.containsKey('RECURRENCE-ID')).toList();
        if (masters.length != 1) {
          throw const FormatException('VEVENT master duplicato o assente.');
        }
        final props = masters.single;
        final overrides = entry.value.where((c) =>
            c.containsKey('RECURRENCE-ID')).toList();
        if (props['STATUS']?.value.toUpperCase() == 'CANCELLED') {
          if (overrides.isNotEmpty) {
            throw const FormatException('Master cancellato con eccezioni.');
          }
          continue;
        }
        final master = _parseEvent(props, name);
        final repeating = props.containsKey('RRULE') ||
            props.containsKey('RDATE') || props.containsKey('EXDATE');
        if (!repeating) {
          if (overrides.isNotEmpty) {
            throw const FormatException('RECURRENCE-ID senza serie.');
          }
          singles.add(master);
          continue;
        }
        final start = props['DTSTART']!;
        final rawStart = start.value;
        final anchorDay = '${rawStart.substring(0, 4)}-'
            '${rawStart.substring(4, 6)}-${rawStart.substring(6, 8)}';
        final clock = master.allDay ? null :
            '${rawStart.substring(9, 11)}:${rawStart.substring(11, 13)}:'
            '${rawStart.substring(13, 15)}';
        final rule = props['RRULE'] == null ? null :
            IcsRule.parse(props['RRULE']!.value,
                allDay: master.allDay, anchorDay: anchorDay,
                anchorWeekday: icsCivil(anchorDay).weekday);
        List<String> exceptionKeys(String key) {
          final prop = props[key];
          if (prop == null) return [];
          final keys = <String>[];
          for (final value in prop.value.split(',')) {
            final parsed = _parseDate(_Prop(value, prop.zone));
            if (parsed.$1 != master.allDay) {
              throw const FormatException('Tipo EXDATE/RDATE non coincidente.');
            }
            if (keys.contains(parsed.$2)) {
              throw const FormatException('Data eccezione duplicata.');
            }
            keys.add(parsed.$2);
          }
          return keys;
        }
        final moves = <String, IcsEvent>{};
        final cancelled = <String>[];
        for (final change in overrides) {
          if (change.containsKey('RRULE') ||
              change.containsKey('RDATE') ||
              change.containsKey('EXDATE')) {
            throw const FormatException('Ricorrenze annidate non supportate.');
          }
          final original = _parseDate(change['RECURRENCE-ID']!);
          if (original.$1 != master.allDay ||
              moves.containsKey(original.$2) ||
              cancelled.contains(original.$2)) {
            throw const FormatException('RECURRENCE-ID duplicato o invalido.');
          }
          if (change['STATUS']?.value.toUpperCase() == 'CANCELLED') {
            cancelled.add(original.$2);
          } else {
            moves[original.$2] = _parseEvent(change, name,
                fallbackTitle: master.title);
          }
        }
        series.add(IcsRecurringEvent(master: master,
            anchorDay: anchorDay, clock: clock, zone: start.zone,
            rule: rule, rdates: exceptionKeys('RDATE'),
            exdates: exceptionKeys('EXDATE'),
            cancelled: cancelled, overrides: moves));
      }
      if (singles.isEmpty && series.isEmpty) {
        throw const FormatException('Nessun evento ICS attivo.');
      }
      return IcsCalendar(name, List.unmodifiable(singles),
          series: List.unmodifiable(series));
    } on FormatException { rethrow; }
    catch (_) { throw const FormatException('File ICS non valido.'); }
  }
  static IcsEvent _parseEvent(Map<String,_Prop> props,String source,
      {String? fallbackTitle}) {
    final uid=props['UID']?.value.trim()??'';
    final title=_unescape(props['SUMMARY']?.value??fallbackTitle??'').trim();
    if(uid.isEmpty || title.isEmpty || title.length>512 ||
       props['DTSTART']==null || props['DTEND']==null) {
      throw const FormatException('UID, SUMMARY, DTSTART, DTEND obbligatori.');
    }
    final a=_parseDate(props['DTSTART']!);
    final b=_parseDate(props['DTEND']!);
    if(a.$1!=b.$1 || a.$2.compareTo(b.$2)>=0) {
      throw const FormatException('Intervallo evento ICS invalido.');
    }
    return a.$1 ? IcsEvent(uid:uid,title:title,source:source,
        startDay:a.$2,endDay:b.$2)
      : IcsEvent(uid:uid,title:title,source:source,
        startUtc:DateTime.parse(a.$2),endUtc:DateTime.parse(b.$2));
  }
  /// (allDay, ISO civil date or UTC instant)
  static (bool,String) _parseDate(_Prop prop) {
    final s=prop.value;
    if(RegExp(r'^\d{8}$').hasMatch(s)) {
      final day='${s.substring(0,4)}-${s.substring(4,6)}-${s.substring(6,8)}';
      if(prop.zone!=null || !_validDay(day)) {
        throw const FormatException('Data ICS non valida.');
      }
      return (true,day);
    }
    final match=RegExp(r'^(\d{4})(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)(Z?)$').firstMatch(s);
    if(match==null) throw const FormatException('Formato data ICS non supportato.');
    final p=List.generate(6,(i)=>int.parse(match.group(i+1)!));
    final date=DateTime.utc(p[0],p[1],p[2],p[3],p[4],p[5]);
    if(date.year!=p[0] || date.month!=p[1] || date.day!=p[2] ||
       date.hour!=p[3] || date.minute!=p[4] || date.second!=p[5]) {
      throw const FormatException('Data/ora ICS impossibile.');
    }
    if(match.group(7)=='Z') {
      if(prop.zone!=null) throw const FormatException('TZID con UTC non valido.');
      return (false,date.toIso8601String());
    }
    if(prop.zone==null || !TaskDueClock.knowsZone(prop.zone!)) {
      throw const FormatException('Orario floating o timezone non IANA.');
    }
    final day="${p[0].toString().padLeft(4,'0')}-${_pad(p[1])}-${_pad(p[2])}";
    final time='${_pad(p[3])}:${_pad(p[4])}';
    final options=TaskDueClock.possibilities(day,time,prop.zone!);
    if(options.length!=1) throw const FormatException('Orario ICS ambiguo per DST.');
    return (false,options.single.instant.add(Duration(seconds:p[5]))
        .toUtc().toIso8601String());
  }
  static String _unescape(String s)=>s.replaceAllMapped(RegExp(r'\\[nN,;\\]'),
    (m) {final c=m.group(0)!.substring(1);return c.toLowerCase()=='n'?'\n':c;});
}
