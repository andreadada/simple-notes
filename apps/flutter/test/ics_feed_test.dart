import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/ics_calendar.dart';
import 'package:simple_notes/ui/ics_feed.dart';

List<int> calendarBytes({String summary = 'Evento remoto'}) => utf8.encode([
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'BEGIN:VEVENT',
  'UID:remote-1',
  'SUMMARY:$summary',
  'DTSTART:20261103T090000Z',
  'DTEND:20261103T100000Z',
  'END:VEVENT',
  'END:VCALENDAR',
  '',
].join('\r\n'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const example = 'https://calendar.example.org/private.ics?token=abc';

  test('URL validation is strict, but permits private query token feeds', () {
    expect(IcsFeedPolicy.validate(example).host, 'calendar.example.org');
    expect(IcsFeedPolicy.validate('https://EXAMPLE.org:443/events.ics')
        .port, 443);
    for (final url in [
      'http://calendar.example.org/a.ics',
      'https://localhost/a.ics',
      'https://sub.localhost/a.ics',
      'https://calendar.internal/a.ics',
      'https://calendar.local/a.ics',
      'https://calendar.test/a.ics',
      'https://127.0.0.1/feed.ics',
      'https://[::1]/feed.ics',
      'https://169.254.169.254/latest',
      'https://calendar.example.org:8443/a',
      'https://user:password@calendar.example.org/a',
      'https://calendar.example.org/a#secret',
      'https://calendar.example.org/a ',
      'ftp://calendar.example.org/a',
      'https://example.org:80/a',
    ]) {
      expect(() => IcsFeedPolicy.validate(url), throwsFormatException,
          reason: url);
    }
  });

  test('public DNS address filter rejects private, special and mixed IPs', () {
    for (final value in [
      '127.0.0.1','0.0.0.0','10.1.2.3','172.18.0.1',
      '192.168.0.1','169.254.169.254','100.90.0.1',
      '198.18.0.1','203.0.113.1','224.0.0.1','255.255.255.255',
      '::1','fe80::1','fc00::1','::ffff:127.0.0.1',
      '2001:db8::1','2002:c000:0201::1',
    ]) {
      expect(IcsFeedPolicy.isPublicAddress(InternetAddress(value)), isFalse,
          reason: value);
    }
    expect(IcsFeedPolicy.isPublicAddress(InternetAddress('1.1.1.1')), isTrue);
    expect(IcsFeedPolicy.isPublicAddress(
        InternetAddress('2606:4700:4700::1111')), isTrue);
    expect(() => IcsFeedPolicy.chooseAddress([
      InternetAddress('1.1.1.1'), InternetAddress('127.0.0.1'),
    ]), throwsFormatException);
    expect(() => IcsFeedPolicy.chooseAddress([]), throwsFormatException);
    expect(IcsFeedPolicy.chooseAddress([InternetAddress('8.8.8.8')])
        .address, '8.8.8.8');
  });

  test('redirect policy rejects cross host, downgrade, loops and private', () {
    final original = IcsFeedPolicy.validate(example);
    final visited = {original.toString()};
    final good = IcsFeedPolicy.redirect(
        original, original, '/feeds/new.ics', visited);
    expect(good.host, original.host);
    for (final location in [
      'http://calendar.example.org/plain.ics',
      'https://other.example.org/steal',
      'https://127.0.0.1/admin',
      'https://calendar.example.org:8443/feed',
      '/feeds/new.ics',
      example,
      'https://user:secret@calendar.example.org/file.ics',
    ]) {
      expect(() => IcsFeedPolicy.redirect(
          original, original, location, visited), throwsFormatException,
          reason: location);
    }
  });

  test('subscribe saves only parsed snapshot, metadata, stable source ID', () async {
    var calls = 0;
    final service = IcsFeedService(
      download: (url) async {
        calls++;
        expect(url, example);
        return calendarBytes();
      },
      now: () => DateTime.utc(2026, 11, 2, 14, 30),
    );
    final first = await service.subscribe(const IcsLibrary(), example);
    expect(calls, 1);
    final cal = first.calendars.single;
    expect(cal.kind, IcsSourceKind.url);
    expect(cal.name, 'calendar.example.org');
    expect(cal.sourceUrl, example);
    expect(cal.id, isNotEmpty);
    expect(cal.lastFetchedUtc, DateTime.utc(2026, 11, 2, 14, 30));
    expect(first.onDay(DateTime(2026, 11, 3)).single.title, 'Evento remoto');
    final loaded = IcsLibrary.deserialize(first.serialize());
    expect(loaded.calendars.single.id, cal.id);
    expect(loaded.calendars.single.lastFetchedUtc, cal.lastFetchedUtc);
    expect(loaded.calendars.single.sourceUrl, example);
    final duplicate = await service.subscribe(loaded, example);
    expect(duplicate.calendars, hasLength(1));
    expect(duplicate.calendars.single.id, cal.id);
    expect(calls, 2);
  });

  test('manual refresh updates one URL while preserving unrelated sources',
      () async {
    final file = IcsParser.parse(calendarBytes(summary: 'Dal file'),
        'locale.ics');
    final offline = const IcsLibrary().replace(file);
    final initial = await IcsFeedService(
        download: (_) async => calendarBytes(summary: 'Prima')).subscribe(
        offline, example);
    final fileId = initial.calendars.first.id;
    final feedId = initial.calendars.last.id;
    final updated = await IcsFeedService(
        download: (_) async => calendarBytes(summary: 'Dopo'),
        now: () => DateTime.utc(2026, 11, 3)).refresh(initial, feedId);
    expect(updated.calendars, hasLength(2));
    expect(updated.calendars.first.id, fileId);
    expect(updated.calendars.last.id, feedId);
    expect(updated.calendars.last.events.single.title, 'Dopo');
    expect(updated.calendars.first.events.single.title, 'Dal file');
    expect(updated.removeById(feedId).calendars.single.id, fileId);
    expect(() => IcsLibrary.deserialize(updated.serialize()), returnsNormally);
  });

  test('failed request, invalid ICS and unsafe URL never alter the old cache',
      () async {
    final stored = await IcsFeedService(
        download: (_) async => calendarBytes()).subscribe(
        const IcsLibrary(), example);
    final original = stored.serialize();
    final id = stored.calendars.single.id;
    final errors = [
      (_) async => throw const FormatException('Offline'),
      (_) async => utf8.encode('not an ICS file'),
      (_) async => <int>[],
      (_) async => List<int>.filled(IcsParser.maxBytes + 1, 65),
    ];
    for (final bad in errors) {
      final service = IcsFeedService(download: bad);
      await expectLater(service.refresh(stored, id), throwsFormatException);
      expect(stored.serialize(), original);
      expect(stored.onDay(DateTime(2026, 11, 3)).single.title,
          'Evento remoto');
    }
    var attempts = 0;
    await expectLater(IcsFeedService(download: (url) async {
      attempts++;
      return calendarBytes();
    }).subscribe(stored, 'http://127.0.0.1/secret'),
        throwsFormatException);
    expect(attempts, 0);
  });

  test('schema 3 rejects duplicate feed URL and corrupted refresh metadata',
      () async {
    final one = await IcsFeedService(
        download: (_) async => calendarBytes()).subscribe(
        const IcsLibrary(), example);
    final raw = jsonDecode(one.serialize()) as Map<String, dynamic>;
    final calendars = raw['calendars'] as List;
    final clone = Map<String, dynamic>.from(calendars.single as Map);
    clone['id'] = 'another-id';
    calendars.add(clone);
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
    calendars.removeLast();
    (calendars.single as Map)['lastFetchedUtc'] =
        'not-a-date';
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
    (calendars.single as Map)['lastFetchedUtc'] =
        '2026-11-02T12:00:00';
    expect(() => IcsLibrary.deserialize(jsonEncode(raw)),
        throwsFormatException);
  });

  test('source limit is checked before requesting a new feed', () async {
    var full = const IcsLibrary();
    for (var i = 0; i < IcsLibrary.maxSources; i++) {
      full = full.replace(IcsParser.parse(calendarBytes(), 'file-$i.ics'));
    }
    var fetched = false;
    await expectLater(IcsFeedService(download: (url) async {
      fetched = true;
      return calendarBytes();
    }).subscribe(full, example), throwsFormatException);
    expect(fetched, isFalse);
    expect(full.calendars.length, IcsLibrary.maxSources);
  });
}
