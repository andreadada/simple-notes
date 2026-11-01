import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/ics_calendar.dart';

List<int> ics(List<String> events) => utf8.encode([
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  ...events,
  'END:VCALENDAR',
  '',
].join('\r\n'));

List<String> event({
  String id='id-1',
  String summary='Visita',
  String start='DTSTART:20261103T090000Z',
  String end='DTEND:20261103T100000Z',
  List<String> extra=const [],
}) => ['BEGIN:VEVENT','UID:$id','SUMMARY:$summary',start,end,...extra,'END:VEVENT'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UTC events are read-only and use exclusive end/day boundaries', () {
    final cal=IcsParser.parse(ics(event()),'work.ics');
    final lib=IcsLibrary([cal]);
    final e=cal.events.single;
    expect(e.uid,'id-1');
    expect(e.startUtc,DateTime.utc(2026,11,3,9));
    expect(e.allDay,false);
    expect(e.onDay(DateTime(2026,11,3)),true);
    expect(e.onDay(DateTime(2026,11,4)),false);
    expect(lib.onDay(DateTime(2026,11,3)).single.source,'work.ics');
  });

  test('all-day multi-day ends exclusively and keeps no fabricated hours', () {
    final c=IcsParser.parse(ics(event(
      start:'DTSTART;VALUE=DATE:20261103',
      end:'DTEND;VALUE=DATE:20261106',
    )),'holidays.ics');
    final e=c.events.single;
    expect(e.allDay,true);
    expect(e.startUtc,isNull);
    expect(e.clock,'Tutto il giorno');
    expect(e.onDay(DateTime(2026,11,3)),true);
    expect(e.onDay(DateTime(2026,11,5)),true);
    expect(e.onDay(DateTime(2026,11,6)),false);
  });

  test('IANA TZID resolves winter and summer offsets correctly', () {
    final c=IcsParser.parse(ics([
      ...event(id:'w',start:'DTSTART;TZID=Europe/Rome:20261103T090000',
        end:'DTEND;TZID=Europe/Rome:20261103T100000'),
      ...event(id:'s',start:'DTSTART;TZID=Europe/Rome:20260703T090000',
        end:'DTEND;TZID=Europe/Rome:20260703T100000'),
    ]),'rome.ics');
    final winter=c.events.singleWhere((x)=>x.uid=='w');
    final summer=c.events.singleWhere((x)=>x.uid=='s');
    expect(winter.startUtc,DateTime.utc(2026,11,3,8));
    expect(summer.startUtc,DateTime.utc(2026,7,3,7));
  });

  test('rejects DST gaps, folds, floating times and unknown zones', () {
    for(final start in [
      'DTSTART;TZID=Europe/Rome:20260329T023000',
      'DTSTART;TZID=Europe/Rome:20261025T023000',
      'DTSTART:20261103T090000',
      'DTSTART;TZID=Local/Unlisted:20261103T090000',
    ]) {
      expect(() => IcsParser.parse(ics(event(start:start)), 'bad.ics'),
        throwsFormatException);
    }
  });

  test('unfolds lines and decodes escaped punctuation', () {
    final c=IcsParser.parse(ics(event(summary:r'Prima\, parte\; seconda\n' '\r\n ' r'Terza')), 'text.ics');
    expect(c.events.single.title, 'Prima, parte; seconda\nTerza');
  });

  test('rejects unsupported recurrences rather than displaying partial data', () {
    for(final extra in [
      ['RRULE:FREQ=WEEKLY;COUNT=5'],
      ['RDATE:20261104T100000Z'],
      ['RECURRENCE-ID:20261103T090000Z'],
      ['DURATION:PT1H'],
    ]) {
      expect(() => IcsParser.parse(ics(event(extra:extra)),'recur.ics'),
        throwsFormatException);
    }
  });

  test('invalid intervals, duplicate UIDs, broken structure and size fail', () {
    expect(() => IcsParser.parse(ics([
      ...event(),...event(summary:'Altra visita'),
    ]),'same.ics'),throwsFormatException);
    expect(() => IcsParser.parse(ics(event(
      end:'DTEND:20261103T080000Z')),'bad.ics'),throwsFormatException);
    expect(() => IcsParser.parse(utf8.encode('wrong'),'bad.ics'),
      throwsFormatException);
    expect(() => IcsParser.parse(List<int>.filled(
      IcsParser.maxBytes+1,32),'big.ics'),throwsFormatException);
    expect(() => IcsParser.parse(ics(event(start:'DTSTART:20260230T100000Z')),
      'invalid.ics'),throwsFormatException);
  });

  test('file replacement affects only that overlay, removal never other data', () {
    final first=IcsParser.parse(ics(event()),'same.ics');
    final second=IcsParser.parse(ics(event(id:'2')),'other.ics');
    final library=IcsLibrary().replace(first).replace(second);
    expect(library.eventCount,2);
    final next=library.replace(IcsParser.parse(ics(event(
      summary:'Nuovo')), 'same.ics'));
    expect(next.eventCount,2);
    expect(next.calendars.singleWhere((c)=>c.name=='same.ics')
        .events.single.title,'Nuovo');
    expect(next.remove('same.ics').calendars.single.name,'other.ics');
  });

  test('versioned persistence round-trip and account keys remain isolated', () {
    final cal=IcsParser.parse(ics(event()),'a.ics');
    final old=IcsLibrary([cal]);
    final restored=IcsLibrary.deserialize(old.serialize());
    expect(restored.onDay(DateTime(2026,11,3)).single.title,'Visita');
    expect(icsOwnerKey('google-a'),isNot(icsOwnerKey('google-b')));
    expect(icsOwnerKey(null),isNot(icsOwnerKey('google-a')));
    expect(() => IcsLibrary.deserialize('{"schema":4,"calendars":[]}'),
      throwsFormatException);
    expect(() => IcsLibrary.deserialize('not json'),throwsFormatException);
  });

  test('legacy schema 1 is read without writes and lazily upgrades to 2', () {
    final oldCalendar = IcsParser.parse(ics(event()), 'legacy.ics');
    final legacy = jsonEncode({
      'schema': 1,
      'calendars': [
        {'name': oldCalendar.name,
         'events': oldCalendar.events.map((e) => e.toJson()).toList()},
      ],
    });
    final first = IcsLibrary.deserialize(legacy);
    final again = IcsLibrary.deserialize(legacy);
    expect(first.calendars.single.kind, IcsSourceKind.file);
    expect(first.calendars.single.sourceUrl, isNull);
    expect(first.calendars.single.id, startsWith('file-'));
    expect(first.calendars.single.id, again.calendars.single.id);
    expect(jsonDecode(legacy)['schema'], 1); // Loading does not rewrite.
    expect(first.onDay(DateTime(2026, 11, 3)).single.uid, 'id-1');

    final updated = first.replace(IcsParser.parse(
        ics(event(summary: 'Aggiornata')), 'legacy.ics'));
    expect(updated.calendars.single.id, first.calendars.single.id);
    expect(updated.calendars.single.events.single.title, 'Aggiornata');
    final saved = updated.serialize();
    expect(jsonDecode(saved)['schema'], 3);
    expect(IcsLibrary.deserialize(saved).calendars.single.id,
        first.calendars.single.id);
  });

  test('new imports have stable ids through reimport and round-trip', () {
    final initial = const IcsLibrary().replace(
        IcsParser.parse(ics(event()), 'file.ics'));
    final id = initial.calendars.single.id;
    expect(id, isNotEmpty);
    final second = initial.replace(IcsParser.parse(
        ics(event(summary: 'Corretto')), 'file.ics'));
    expect(second.calendars.single.id, id);
    expect(IcsLibrary.deserialize(second.serialize()).calendars.single.id, id);
  });

  test('URL metadata is distinct from file labels; removal uses identity', () {
    final parsed = IcsParser.parse(ics(event()), 'shared.ics');
    final fileLibrary = const IcsLibrary().replace(parsed);
    final fileId = fileLibrary.calendars.single.id;
    final feed = IcsCalendar('shared.ics', parsed.events,
        id: 'subscription-example', kind: IcsSourceKind.url,
        sourceUrl: 'https://calendar.example.org/personal.ics');
    final combined = fileLibrary.replace(feed);
    expect(combined.calendars.length, 2);
    final restored = IcsLibrary.deserialize(combined.serialize());
    expect(restored.calendars.map((c) => c.kind).toSet(),
        {IcsSourceKind.file, IcsSourceKind.url});
    expect(restored.removeById(fileId).calendars.single.id,
        'subscription-example');
    expect(restored.removeById('subscription-example').calendars.single.id,
        fileId);
    // Metadata support does not activate URL fetching or event editing.
    expect(restored.calendars.last.sourceUrl,
        'https://calendar.example.org/personal.ics');
  });

  test('rejects duplicate identity, unknown kinds and unsafe URL metadata', () {
    final first = IcsParser.parse(ics(event()), 'first.ics');
    final second = IcsParser.parse(ics(event()), 'second.ics');
    final library = const IcsLibrary().replace(first).replace(second);
    final raw = jsonDecode(library.serialize()) as Map<String, dynamic>;
    final entries = raw['calendars'] as List;
    final head = entries.first as Map<String, dynamic>;
    final tail = entries.last as Map<String, dynamic>;
    tail['id'] = head['id'];
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
    tail['id'] = 'valid-other';
    tail['kind'] = 'unsupported';
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
    tail['kind'] = 'url';
    tail['sourceUrl'] = 'http://127.0.0.1/private.ics';
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
    tail['sourceUrl'] = 'https://user:secret@example.org/calendar.ics';
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
    tail['sourceUrl'] = 'https://example.org/calendar.ics#fragment';
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
  });


  test('daily COUNT expands lazily and maintains all-day end-exclusive', () {
    final cal = IcsParser.parse(ics(event(
      start:'DTSTART;VALUE=DATE:20261103', end:'DTEND;VALUE=DATE:20261105',
      extra:['RRULE:FREQ=DAILY;COUNT=3'],
    )), 'daily.ics');
    expect(cal.events, isEmpty);
    expect(cal.series, hasLength(1));
    final lib = IcsLibrary([cal]);
    expect(lib.onDay(DateTime(2026, 11, 3)), hasLength(1));
    expect(lib.onDay(DateTime(2026, 11, 4)), hasLength(2));
    expect(lib.onDay(DateTime(2026, 11, 5)), hasLength(2));
    expect(lib.onDay(DateTime(2026, 11, 6)), hasLength(1));
    expect(lib.onDay(DateTime(2026, 11, 7)), isEmpty);
  });

  test('WEEKLY BYDAY with COUNT includes correct weekdays only', () {
    final lib = IcsLibrary([IcsParser.parse(ics(event(
      extra:['RRULE:FREQ=WEEKLY;BYDAY=TU,TH;COUNT=4'],
    )), 'weekly.ics')]);
    for (final date in [3, 5, 10, 12]) {
      expect(lib.onDay(DateTime(2026, 11, date)), hasLength(1));
    }
    for (final date in [4, 6, 13, 17]) {
      expect(lib.onDay(DateTime(2026, 11, date)), isEmpty);
    }
  });

  test('MONTHLY and YEARLY skip nonexistent civil dates', () {
    final monthly = IcsLibrary([IcsParser.parse(ics(event(
      start:'DTSTART;VALUE=DATE:20270131',
      end:'DTEND;VALUE=DATE:20270201',
      extra:['RRULE:FREQ=MONTHLY;COUNT=3'],
    )), 'monthly.ics')]);
    for (final month in [1, 3, 5]) {
      expect(monthly.onDay(DateTime(2027, month, 31)), hasLength(1));
    }
    expect(monthly.onDay(DateTime(2027, 2, 28)), isEmpty);
    expect(monthly.onDay(DateTime(2027, 6, 30)), isEmpty);

    final yearly = IcsLibrary([IcsParser.parse(ics(event(
      start:'DTSTART;VALUE=DATE:20240229',
      end:'DTEND;VALUE=DATE:20240301',
      extra:['RRULE:FREQ=YEARLY;COUNT=3'],
    )), 'leap.ics')]);
    expect(yearly.onDay(DateTime(2024, 2, 29)), hasLength(1));
    expect(yearly.onDay(DateTime(2028, 2, 29)), hasLength(1));
    expect(yearly.onDay(DateTime(2032, 2, 29)), hasLength(1));
    expect(yearly.onDay(DateTime(2036, 2, 29)), isEmpty);
  });

  test('IANA recurrence preserves wall clock across DST transitions', () {
    final daily = IcsLibrary([IcsParser.parse(ics(event(
      start:'DTSTART;TZID=Europe/Rome:20260327T090000',
      end:'DTEND;TZID=Europe/Rome:20260327T100000',
      extra:['RRULE:FREQ=DAILY;COUNT=4'],
    )), 'rome.ics')]);
    expect(daily.onDay(DateTime(2026,3,27)).single.startUtc,
        DateTime.utc(2026,3,27,8));
    expect(daily.onDay(DateTime(2026,3,29)).single.startUtc,
        DateTime.utc(2026,3,29,7));

    final gap = IcsLibrary([IcsParser.parse(ics(event(
      start:'DTSTART;TZID=Europe/Rome:20260328T023000',
      end:'DTEND;TZID=Europe/Rome:20260328T030000',
      extra:['RRULE:FREQ=DAILY;COUNT=3'],
    )), 'gap.ics')]);
    expect(gap.onDay(DateTime(2026,3,29)), isEmpty);
    expect(gap.onDay(DateTime(2026,3,30)), hasLength(1));
    expect(gap.onDay(DateTime(2026,3,31)), hasLength(1));
    expect(gap.onDay(DateTime(2026,4,1)), isEmpty);

    final fold = IcsLibrary([IcsParser.parse(ics(event(
      start:'DTSTART;TZID=Europe/Rome:20261024T023000',
      end:'DTEND;TZID=Europe/Rome:20261024T033000',
      extra:['RRULE:FREQ=DAILY;COUNT=3'],
    )), 'fold.ics')]);
    expect(fold.onDay(DateTime(2026,10,25)).single.startUtc,
        DateTime.utc(2026,10,25,0,30));
  });

  test('EXDATE wins over RDATE and duplicate RRULE occurrence', () {
    final lib = IcsLibrary([IcsParser.parse(ics(event(
      extra:[
        'RRULE:FREQ=DAILY;COUNT=3',
        'RDATE:20261104T090000Z,20261110T090000Z',
        'EXDATE:20261104T090000Z',
      ],
    )), 'exceptions.ics')]);
    expect(lib.onDay(DateTime(2026,11,3)), hasLength(1));
    expect(lib.onDay(DateTime(2026,11,4)), isEmpty);
    expect(lib.onDay(DateTime(2026,11,5)), hasLength(1));
    expect(lib.onDay(DateTime(2026,11,10)), hasLength(1));
  });

  test('RECURRENCE-ID moves and cancels individual instances', () {
    final master = event(extra:['RRULE:FREQ=DAILY;COUNT=4']);
    final move = [
      'BEGIN:VEVENT','UID:id-1',
      'RECURRENCE-ID:20261104T090000Z',
      'SUMMARY:Spostata',
      'DTSTART:20261107T110000Z',
      'DTEND:20261107T120000Z',
      'END:VEVENT',
    ];
    final cancel = [
      'BEGIN:VEVENT','UID:id-1',
      'RECURRENCE-ID:20261105T090000Z',
      'STATUS:CANCELLED','END:VEVENT',
    ];
    final cal = IcsParser.parse(ics([...master,...move,...cancel]),'moved.ics');
    final lib = IcsLibrary([cal]);
    expect(lib.onDay(DateTime(2026,11,3)), hasLength(1));
    expect(lib.onDay(DateTime(2026,11,4)), isEmpty);
    expect(lib.onDay(DateTime(2026,11,5)), isEmpty);
    expect(lib.onDay(DateTime(2026,11,6)), hasLength(1));
    expect(lib.onDay(DateTime(2026,11,7)).single.title,'Spostata');
    final restored = IcsLibrary.deserialize(
        const IcsLibrary().replace(cal).serialize());
    expect(restored.onDay(DateTime(2026,11,7)).single.title,'Spostata');
  });

  test('legacy schema 2 loads but future schema 3 writes only on action', () {
    final cal = IcsParser.parse(ics(event()),'legacy2.ics');
    final saved = const IcsLibrary().replace(cal).serialize();
    final map = jsonDecode(saved) as Map<String,dynamic>;
    map['schema'] = 2;
    final previous = jsonEncode(map);
    final loaded = IcsLibrary.deserialize(previous);
    expect(loaded.onDay(DateTime(2026,11,3)), hasLength(1));
    expect(jsonDecode(previous)['schema'],2);
    expect(jsonDecode(loaded.serialize())['schema'],3);
  });

  test('fail closed for unsupported RRULE, invalid overrides or periods', () {
    for (final extra in [
      ['RRULE:FREQ=HOURLY;COUNT=2'],
      ['RRULE:FREQ=WEEKLY;BYSETPOS=1;COUNT=3'],
      ['RRULE:FREQ=DAILY;COUNT=2;UNTIL=20261104T090000Z'],
      ['RRULE:FREQ=DAILY;COUNT=0'],
      ['RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=2'],
      ['RRULE:FREQ=DAILY;UNTIL=20261104'],
      ['RRULE:FREQ=DAILY;COUNT=2','RDATE;VALUE=PERIOD:20261105T090000Z/20261105T100000Z'],
    ]) {
      expect(() => IcsParser.parse(ics(event(extra:extra)), 'bad.ics'),
          throwsFormatException);
    }
    expect(() => IcsParser.parse(ics([
      ...event(extra:['RRULE:FREQ=DAILY;COUNT=3']),
      'BEGIN:VEVENT','UID:id-1','RECURRENCE-ID;RANGE=THISANDFUTURE:20261104T090000Z',
      'STATUS:CANCELLED','END:VEVENT',
    ]), 'range.ics'), throwsFormatException);
  });

  test('limits imported file count and do not write on parse failures', () {
    var lib=const IcsLibrary();
    for(var i=0;i<IcsLibrary.maxSources;i++) {
      lib=lib.replace(IcsParser.parse(ics(event()),'calendar$i.ics'));
    }
    expect(() => lib.replace(IcsParser.parse(ics(event()),'overflow.ics')),
      throwsFormatException);
    expect(lib.calendars.length,5);
  });
}
