import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/ui/ics_calendar.dart';
import 'package:simple_notes/ui/ics_calendar_controls.dart';
import 'package:simple_notes/ui/ics_source_details.dart';
import 'package:simple_notes/ui/notes_theme.dart';

List<int> fixture() => utf8.encode([
  'BEGIN:VCALENDAR', 'VERSION:2.0',
  'BEGIN:VEVENT', 'UID:fixture-1', 'SUMMARY:Esame',
  'DTSTART:20261103T090000Z', 'DTEND:20261103T100000Z',
  'END:VEVENT', 'END:VCALENDAR', '',
].join('\r\n'));

IcsLibrary fixtureLibrary() {
  final local = IcsParser.parse(fixture(), 'universita.ics');
  final remote = IcsParser.parse(fixture(), 'calendar.example.org');
  return const IcsLibrary().replace(local).replace(
    IcsCalendar('calendar.example.org', remote.events,
      id: 'feed-example', kind: IcsSourceKind.url,
      sourceUrl: 'https://calendar.example.org/private.ics?token=PRIVATE',
      lastFetchedUtc: DateTime.utc(2026, 11, 2, 12, 30)),
  );
}

Widget harness({required String owner,
    required void Function(IcsLibrary) onChanged}) => MaterialApp(
  builder: (context, child) => FTheme(
    data: NotesTheme.forPlatform(TargetPlatform.windows),
    child: child ?? const SizedBox.shrink(),
  ),
  home: Scaffold(body: SingleChildScrollView(child:
      IcsCalendarControls(ownerId: owner, onChanged: onChanged))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('source details exclude URL path/query and show last successful fetch',
      () {
    final source = fixtureLibrary().calendars.last;
    expect(icsSourceKindLabel(source), 'Feed HTTPS · calendar.example.org');
    expect(icsSourceEventCount(source), '1 eventi · 0 serie');
    expect(icsSourceRefreshLabel(source),
        contains('Ultimo aggiornamento riuscito:'));
    final details = '${icsSourceKindLabel(source)} '
        '${icsSourceRefreshLabel(source)}';
    expect(details, isNot(contains('PRIVATE')));
    expect(details, isNot(contains('private.ics')));
    final local = fixtureLibrary().calendars.first;
    expect(icsSourceKindLabel(local), 'File locale');
    expect(icsSourceRefreshLabel(local), contains('Importazione locale'));
    final unknown = IcsCalendar('example.org', source.events,
      kind: IcsSourceKind.url, sourceUrl: source.sourceUrl);
    expect(icsSourceRefreshLabel(unknown),
        'Ultimo aggiornamento non disponibile');
  });

  testWidgets('source manager opens only on request and never displays URL',
      (tester) async {
    tester.view.physicalSize = const Size(1050, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      icsOwnerKey('owner-A'): fixtureLibrary().serialize(),
    });
    var received = const IcsLibrary();
    await tester.pumpWidget(harness(owner: 'owner-A',
      onChanged: (value) => received = value));
    await tester.pumpAndSettle();
    expect(received.calendars, hasLength(2));
    expect(find.byKey(const Key('calendar-manage-ics')), findsOneWidget);
    expect(find.byKey(const Key('ics-source-name-feed-example')), findsNothing);
    await tester.tap(find.byKey(const Key('calendar-manage-ics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ics-source-name-feed-example')),
        findsOneWidget);
    expect(find.byKey(const Key('calendar-refresh-ics-feed-example')),
        findsOneWidget);
    expect(find.byKey(const Key('calendar-remove-ics-feed-example')),
        findsOneWidget);
    expect(find.textContaining('calendar.example.org'), findsWidgets);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(find.textContaining('private.ics'), findsNothing);
  });

  testWidgets('inline name persists and leaves feed and file identity intact',
      (tester) async {
    tester.view.physicalSize = const Size(1050, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      icsOwnerKey('owner-A'): fixtureLibrary().serialize(),
    });
    IcsLibrary? changed;
    await tester.pumpWidget(harness(owner: 'owner-A',
      onChanged: (value) => changed = value));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-manage-ics')));
    await tester.pumpAndSettle();
    final id = changed!.calendars.first.id;
    final field = find.descendant(
      of: find.byKey(Key('ics-source-name-$id')),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Calendario studi');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final current = changed!.calendars.first;
    expect(current.id, id);
    expect(current.name, 'universita.ics');
    expect(current.label, 'Calendario studi');
    expect(current.events.single.source, 'universita.ics');
    expect(changed!.onDay(DateTime(2026, 11, 3)).first.source,
        'Calendario studi');
    final prefs = await SharedPreferences.getInstance();
    final persisted = IcsLibrary.deserialize(
        prefs.getString(icsOwnerKey('owner-A'))!);
    expect(persisted.calendars.first.label, 'Calendario studi');
    expect(persisted.calendars.last.id, 'feed-example');
    expect(persisted.calendars.last.sourceUrl, contains('PRIVATE'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('account switch resets and reloads sources independently',
      (tester) async {
    tester.view.physicalSize = const Size(1050, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      icsOwnerKey('owner-A'): fixtureLibrary().serialize(),
      icsOwnerKey('owner-B'): const IcsLibrary().serialize(),
    });
    IcsLibrary? received;
    await tester.pumpWidget(harness(owner: 'owner-A',
      onChanged: (value) => received = value));
    await tester.pumpAndSettle();
    expect(received!.calendars, hasLength(2));
    await tester.tap(find.byKey(const Key('calendar-manage-ics')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness(owner: 'owner-B',
      onChanged: (value) => received = value));
    await tester.pumpAndSettle();
    expect(received!.calendars, isEmpty);
    expect(find.byKey(const Key('ics-source-name-feed-example')), findsNothing);
    expect(find.textContaining('PRIVATE'), findsNothing);
  });
}
