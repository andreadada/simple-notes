import 'dart:convert';
import '../data/task_due_clock.dart';

String _pad(int v) => v.toString().padLeft(2, '0');
String icsDay(DateTime d) => d.year.toString().padLeft(4,'0')+'-'+_pad(d.month)+'-'+_pad(d.day);
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
    return _pad(d.hour)+':'+_pad(d.minute);
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

class IcsCalendar {
  const IcsCalendar(this.name,this.events);
  final String name;
  final List<IcsEvent> events;
  Map<String,dynamic> toJson() => {
    'name': name, 'events': events.map((e)=>e.toJson()).toList(),
  };
  factory IcsCalendar.fromJson(Map<String,dynamic> raw) {
    final name=raw['name'] as String;
    final events=(raw['events'] as List).map((e)=>IcsEvent.fromJson(
        Map<String,dynamic>.from(e as Map))).toList();
    if(name.isEmpty || events.isEmpty || events.length>IcsParser.maxEvents ||
       events.any((e)=>e.source!=name)) {
      throw const FormatException('Calendario ICS locale non valido.');
    }
    return IcsCalendar(name,List.unmodifiable(events));
  }
}

class IcsLibrary {
  const IcsLibrary([this.calendars=const []]);
  static const maxSources=5;
  final List<IcsCalendar> calendars;
  int get eventCount => calendars.fold(0,(int sum,IcsCalendar c)=>sum+c.events.length);
  List<IcsEvent> onDay(DateTime day) => [
    for(final c in calendars) for(final e in c.events)
      if(e.onDay(day)) e,
  ]..sort((a,b) {
    if(a.allDay!=b.allDay) return a.allDay ? -1 : 1;
    return a.allDay ? a.title.compareTo(b.title) : a.startUtc!.compareTo(b.startUtc!);
  });
  IcsLibrary replace(IcsCalendar calendar) {
    final rest=calendars.where((c)=>c.name!=calendar.name).toList();
    if(rest.length>=maxSources) {
      throw const FormatException('Massimo cinque calendari ICS.');
    }
    return IcsLibrary(List.unmodifiable([...rest,calendar]));
  }
  IcsLibrary remove(String name)=>IcsLibrary(List.unmodifiable(
      calendars.where((c)=>c.name!=name)));
  String serialize()=>jsonEncode({'schema':1,
    'calendars':calendars.map((c)=>c.toJson()).toList()});
  factory IcsLibrary.deserialize(String source) {
    try {
      final data=jsonDecode(source);
      if(data is! Map || data['schema']!=1 || data['calendars'] is! List) {
        throw const FormatException('Versione archivio ICS non supportata.');
      }
      final list=(data['calendars'] as List).map((item)=>
        IcsCalendar.fromJson(Map<String,dynamic>.from(item as Map))).toList();
      if(list.length>maxSources || list.map((c)=>c.name).toSet().length!=list.length) {
        throw const FormatException('Troppi calendari ICS o duplicati.');
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
  static IcsCalendar parse(List<int> bytes,String source) {
    if(bytes.isEmpty || bytes.length>maxBytes ||
       source.trim().isEmpty || source.length>180) {
      throw const FormatException('File ICS vuoto, troppo grande o nome non valido.');
    }
    try {
      final lines=<String>[];
      final raw=utf8.decode(bytes).replaceAll('\r\n','\n').replaceAll('\r','\n');
      for(final line in raw.split('\n')) {
        if((line.startsWith(' ')||line.startsWith('\t')) && lines.isNotEmpty) {
          lines[lines.length-1]+=line.substring(1);
        } else if(line.isNotEmpty) { lines.add(line); }
      }
      if(lines.isEmpty || lines.first!='BEGIN:VCALENDAR' ||
         lines.last!='END:VCALENDAR') {
        throw const FormatException('Intestazione VCALENDAR assente.');
      }
      final stack=<String>[];
      final events=<IcsEvent>[];
      final ids=<String>{};
      Map<String,_Prop>? props;
      for(final line in lines) {
        if(line.startsWith('BEGIN:')) {
          final type=line.substring(6).toUpperCase();
          stack.add(type);
          if(type=='VEVENT' && stack.length==2) props={};
          continue;
        }
        if(line.startsWith('END:')) {
          final type=line.substring(4).toUpperCase();
          if(stack.isEmpty || stack.last!=type) {
            throw const FormatException('Componenti ICS non bilanciati.');
          }
          if(type=='VEVENT' && stack.length==2) {
            if(props==null) throw const FormatException('Evento privo di dati.');
            if(props['STATUS']?.value.toUpperCase()!='CANCELLED') {
              final event=_parseEvent(props,source);
              if(!ids.add(event.uid)) throw const FormatException('UID ICS duplicato.');
              events.add(event);
              if(events.length>maxEvents) {
                throw const FormatException('Massimo 500 eventi ICS.');
              }
            }
            props=null;
          }
          stack.removeLast();
          continue;
        }
        if(stack.length==2 && stack.last=='VEVENT' && props!=null) {
          final colon=line.indexOf(':');
          if(colon<1) throw const FormatException('Proprietà ICS non valida.');
          final header=line.substring(0,colon).split(';');
          final key=header.first.toUpperCase();
          if(const {'RRULE','RDATE','EXDATE','RECURRENCE-ID','DURATION'}
              .contains(key)) {
            throw const FormatException('Ricorrenze ed eccezioni ICS non supportate.');
          }
          if(props.containsKey(key) &&
              const {'UID','SUMMARY','DTSTART','DTEND'}.contains(key)) {
            throw const FormatException('Proprietà evento duplicata.');
          }
          String? zone;
          for(final part in header.skip(1)) {
            if(part.toUpperCase().startsWith('TZID=')) {
              zone=part.substring(5).replaceAll('"','');
            }
          }
          props[key]=_Prop(line.substring(colon+1),zone);
        }
      }
      if(stack.isNotEmpty || events.isEmpty) {
        throw const FormatException('Nessun evento ICS singolo supportato.');
      }
      return IcsCalendar(source.trim(),List.unmodifiable(events));
    } on FormatException { rethrow; }
    catch (_) { throw const FormatException('File ICS non valido.'); }
  }
  static IcsEvent _parseEvent(Map<String,_Prop> props,String source) {
    final uid=props['UID']?.value.trim()??'';
    final title=_unescape(props['SUMMARY']?.value??'').trim();
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
      final day=s.substring(0,4)+'-'+s.substring(4,6)+'-'+s.substring(6,8);
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
    final day=p[0].toString().padLeft(4,'0')+'-'+_pad(p[1])+'-'+_pad(p[2]);
    final time=_pad(p[3])+':'+_pad(p[4]);
    final options=TaskDueClock.possibilities(day,time,prop.zone!);
    if(options.length!=1) throw const FormatException('Orario ICS ambiguo per DST.');
    return (false,options.single.instant.add(Duration(seconds:p[5]))
        .toUtc().toIso8601String());
  }
  static String _unescape(String s)=>s.replaceAllMapped(RegExp(r'\\[nN,;\\]'),
    (m) {final c=m.group(0)!.substring(1);return c.toLowerCase()=='n'?'\n':c;});
}
