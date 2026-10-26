import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/ui/eisenhower_board.dart';
import 'package:simple_notes/ui/notes_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Eisenhower view is responsive and uses synced LocalStore writes',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final today = DateTime.now();
    final civil = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    await db.upsertTask(LocalTask(
      id: 'matrix-task', title: 'Studio', dueAt: null,
      due: TaskDue.dateOnly(civil), priority: 1,
      completed: false, createdAt: today));
    final snapshot = await db.snapshot();
    var opened = false;

    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(snapshot),
    ], child: MaterialApp(
      builder: (context, child) => FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: child ?? const SizedBox.shrink()),
      home: Scaffold(body: EisenhowerBoard(
        onOpenTask: (_) => opened = true)),
    )));
    expect(find.byKey(const Key('eisenhower-board')), findsOneWidget);
    expect(find.byKey(const Key('eisenhower-doNow')), findsOneWidget);
    expect(find.byKey(const Key('eisenhower-delegate')), findsOneWidget);
    expect(find.byKey(const Key('eisenhower-task-matrix-task')),
        findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EisenhowerBoard)));
    await container.read(localStoreProvider.notifier)
        .setTaskPriority('matrix-task', 3);
    await tester.pumpAndSettle();
    expect(EisenhowerBoard, isNotNull);
    expect(find.byKey(const Key('eisenhower-task-matrix-task')),
        findsOneWidget);
    expect((await db.snapshot()).tasks.single.priority, 3);

    await tester.tap(find.byKey(const Key('eisenhower-open-matrix-task')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);

    // Rebuild at a narrow Android-like viewport, using the same SQLite data.
    tester.view.physicalSize = const Size(390, 820);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eisenhower-doNow')), findsOneWidget);
    expect(find.byKey(const Key('eisenhower-schedule')), findsOneWidget);
    expect(find.byKey(const Key('eisenhower-delegate')), findsOneWidget);
    expect(find.byKey(const Key('eisenhower-eliminate')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
