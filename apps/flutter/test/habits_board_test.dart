import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/ui/habits_board.dart';
import 'package:simple_notes/ui/habits_model.dart';
import 'package:simple_notes/ui/notes_theme.dart';

String key(String owner) =>
    'simple_notes.habits.v1.${sha256.convert(utf8.encode(owner))}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Habit check-in and archive survive reload, isolated per owner',
      (tester) async {
    final date = DateTime.now();
    final start = HabitsState().add('habit-1', 'Leggere', date);
    SharedPreferences.setMockInitialValues({
      key('owner-a'): start.serialize(),
    });
    tester.view.physicalSize = const Size(1060, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget screen(String owner) => MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: HabitsBoard(
          key: ValueKey('habits-$owner'), ownerId: owner)),
      ),
    );

    await tester.pumpWidget(screen('owner-a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habits-board')), findsOneWidget);
    expect(find.text('0 / 1 completate oggi'), findsOneWidget);
    expect(find.byKey(const Key('habit-card-habit-1')), findsOneWidget);
    expect(find.byKey(const Key('habit-weekly-target-habit-1')),
        findsOneWidget);
    expect(find.text('Obiettivo: 7/7'), findsOneWidget);
    await tester.tap(find.byKey(const Key('habit-weekly-target-habit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 giorni / settimana'));
    await tester.pumpAndSettle();
    expect(find.text('Obiettivo: 3/7'), findsOneWidget);
    final afterGoal = await SharedPreferences.getInstance();
    expect(HabitsState.deserialize(afterGoal.getString(key('owner-a'))!)
        .active.single.weeklyTarget, 3);
    await tester.tap(find.byKey(const Key('habit-today-habit-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1 completate oggi'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(HabitsState.deserialize(prefs.getString(key('owner-a'))!)
        .active.single.checked(date), isTrue);

    await tester.tap(find.byKey(const Key('habit-archive-habit-1')));
    await tester.pumpAndSettle();
    expect(find.text('0 / 0 completate oggi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('habits-show-archived')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-restore-habit-1')), findsOneWidget);

    await tester.pumpWidget(screen('owner-b'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-card-habit-1')), findsNothing);
    expect(find.text('0 / 0 completate oggi'), findsOneWidget);
    expect(prefs.getString(key('owner-b')), isNull);

    await tester.pumpWidget(screen('owner-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('habits-show-archived')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('habit-restore-habit-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1 completate oggi'), findsOneWidget);
    expect(HabitsState.deserialize(prefs.getString(key('owner-a'))!)
        .active.single.weeklyTarget, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('Narrow layout and corrupted preferences never wipe storage',
      (tester) async {
    const corrupt = '{"schema":99}';
    SharedPreferences.setMockInitialValues({key('bad'): corrupt});
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.android),
        child: const Scaffold(body: HabitsBoard(ownerId: 'bad'))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habits-load-error')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key('bad')), corrupt);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
