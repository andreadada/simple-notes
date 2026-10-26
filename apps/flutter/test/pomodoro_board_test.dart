import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/pomodoro_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Focus timer persists per Google owner without sharing statistics',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget app(String owner) => MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(
          body: PomodoroBoard(
            key: ValueKey('board-$owner'), ownerId: owner)),
      ),
    );

    await tester.pumpWidget(app('google-owner-a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pomodoro-clock')), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('0 sessioni oggi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pomodoro-toggle')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Pausa'), findsOneWidget);

    // A different logged-in account sees a fresh, isolated local focus state.
    await tester.pumpWidget(app('google-owner-b'));
    await tester.pumpAndSettle();
    expect(find.text('Avvia'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('0 sessioni oggi'), findsOneWidget);

    // Reloading the first account restores its running deadline.
    await tester.pumpWidget(app('google-owner-a'));
    await tester.pumpAndSettle();
    expect(find.text('Pausa'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pomodoro-reset')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Layout renders on narrow Android-sized screens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.android),
        child: const Scaffold(body: PomodoroBoard(ownerId: null))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pomodoro-board')), findsOneWidget);
    expect(find.byKey(const Key('pomodoro-clock')), findsOneWidget);
    expect(find.byKey(const Key('pomodoro-today')), findsOneWidget);
    expect(find.byKey(const Key('pomodoro-reset')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
