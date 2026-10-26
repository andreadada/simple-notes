import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/task_due.dart';
import 'package:simple_notes/ui/countdowns_board.dart';
import 'package:simple_notes/ui/countdowns_model.dart';
import 'package:simple_notes/ui/notes_theme.dart';

String key(String owner) =>
  'simple_notes.countdowns.v1.${sha256.convert(utf8.encode(owner))}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shows countdown, archives without erasing, isolates Google owner',
      (tester) async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 7);
    final date = '${due.year.toString().padLeft(4, '0')}-'
        '${due.month.toString().padLeft(2, '0')}-'
        '${due.day.toString().padLeft(2, '0')}';
    final initial = CountdownsState().add(
      'event-1', 'Esame', TaskDue.dateOnly(date));
    SharedPreferences.setMockInitialValues({key('owner-one'): initial.serialize()});
    tester.view.physicalSize = const Size(950, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget app(String owner) => MaterialApp(
      home: FTheme(data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: CountdownsBoard(
          key: ValueKey('countdown-$owner'), ownerId: owner))),
    );
    await tester.pumpWidget(app('owner-one'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-board')), findsOneWidget);
    expect(find.byKey(const Key('countdown-event-event-1')), findsOneWidget);
    expect(find.text('Esame'), findsWidgets);
    expect(find.byKey(const Key('countdown-remaining-event-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('countdown-archive-event-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-event-event-1')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(CountdownsState.deserialize(prefs.getString(key('owner-one'))!)
      .archived.single.title, 'Esame');

    await tester.pumpWidget(app('owner-two'));
    await tester.pumpAndSettle();
    expect(find.text('Esame'), findsNothing);
    expect(prefs.getString(key('owner-two')), isNull);

    await tester.pumpWidget(app('owner-one'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-toggle-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('countdown-restore-event-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-event-event-1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('Corrupt local state is displayed and never replaced on mobile',
      (tester) async {
    const corrupt = '{"schema":3}';
    SharedPreferences.setMockInitialValues({key('bad'): corrupt});
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: FTheme(data: NotesTheme.forPlatform(TargetPlatform.android),
        child: const Scaffold(body: CountdownsBoard(ownerId: 'bad'))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('countdown-load-error')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key('bad')), corrupt);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
