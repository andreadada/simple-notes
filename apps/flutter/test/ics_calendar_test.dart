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
    expect(() => IcsLibrary.deserialize('{"schema":2,"calendars":[]}'),
      throwsFormatException);
    expect(() => IcsLibrary.deserialize('not json'),throwsFormatException);
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
