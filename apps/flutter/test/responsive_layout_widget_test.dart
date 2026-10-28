import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_notes/main.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Three notes adapt from three desktop columns to one mobile',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ], child: const SimpleNotesApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-notes')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('new-note')));
      await tester.pumpAndSettle();
    }
    final notes = (await db.snapshot()).notes;
    expect(notes.length, 3);
    final cards = [
      for (final n in notes)
        find.byKey(Key('responsive-note-card-${n.id}')),
    ];
    for (final card in cards) expect(card, findsOneWidget);
    expect(tester.getTopLeft(cards[0]).dy, tester.getTopLeft(cards[1]).dy);
    expect(tester.getTopLeft(cards[1]).dy, tester.getTopLeft(cards[2]).dy);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1110, 900);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(cards[0]).dy, tester.getTopLeft(cards[1]).dy);
    expect(tester.getTopLeft(cards[2]).dy,
        greaterThan(tester.getTopLeft(cards[0]).dy));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 850);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-note')), findsOneWidget);
    expect(tester.getTopLeft(cards[1]).dy,
        greaterThan(tester.getTopLeft(cards[0]).dy));
    expect(tester.getTopLeft(cards[2]).dy,
        greaterThan(tester.getTopLeft(cards[1]).dy));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

  testWidgets('Mobile quick entry remains accessible at 320 logical px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ], child: const SimpleNotesApp()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-input')), findsOneWidget);
    expect(find.byKey(const Key('quick-due-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}
