import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/ui/kanban_board.dart';
import 'package:simple_notes/ui/notes_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kanban columns reflect persisted move and stay usable on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(1150, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final list = LocalTaskList(
      id: 'school', title: 'Scuola', createdAt: DateTime.utc(2026));
    final task = LocalTask(id: 'kanban-task', title: 'Esame',
      dueAt: null, completed: false, createdAt: DateTime.utc(2026, 10, 26));
    await db.upsertList(list);
    await db.upsertTask(task);
    final snapshot = await db.snapshot();
    var opened = false;
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(snapshot),
    ], child: MaterialApp(
      builder: (context, child) => FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: child ?? const SizedBox.shrink()),
      home: Scaffold(body: KanbanBoard(
        onOpenTask: (_) => opened = true,
        onCreateList: () {},
      )),
    )));
    expect(find.byKey(const Key('kanban-board')), findsOneWidget);
    expect(find.byKey(const Key('kanban-column-inbox')), findsOneWidget);
    expect(find.byKey(const Key('kanban-column-school')), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('kanban-column-inbox')),
      matching: find.byKey(const Key('kanban-task-kanban-task'))),
      findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(KanbanBoard)));
    await container.read(localStoreProvider.notifier)
        .setTaskList('kanban-task', 'school');
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: find.byKey(const Key('kanban-column-school')),
      matching: find.byKey(const Key('kanban-task-kanban-task'))),
      findsOneWidget);
    expect((await db.snapshot()).tasks.single.listId, 'school');
    expect(await db.pendingCount(), greaterThan(0));

    await tester.tap(find.byKey(const Key('kanban-open-kanban-task')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);

    tester.view.physicalSize = const Size(390, 820);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kanban-board')), findsOneWidget);
    expect(find.byKey(const Key('kanban-column-inbox')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
