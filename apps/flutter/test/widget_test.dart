import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/main.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Creates task and persists it in SQLite', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(const LocalData()),
    ], child: const SimpleNotesApp()));
    await tester.enterText(find.byKey(const Key('task-input')), 'Comprare il pane');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Comprare il pane'), findsOneWidget);
    final snapshot = await database.snapshot();
    expect(snapshot.tasks.single.title, 'Comprare il pane');
    expect(await database.pendingCount(), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });

  test('Migrates previous SharedPreferences prototype without data loss', () async {
    SharedPreferences.setMockInitialValues({
      'simple_notes.local.v1': '{"tasks":[{"id":"old1","title":"Vecchia attività",'
        '"dueAt":null,"completed":false,"createdAt":"2026-10-21T12:00:00Z"}],"notes":[]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    await db.migrateLegacy(prefs);
    expect((await db.snapshot()).tasks.single.title, 'Vecchia attività');
    expect(prefs.getString('simple_notes.local.v1'), isNull);
    expect(await db.pendingCount(), 1);
    await db.close();
  });
  test('Preserves remote version and blocks switching cloud accounts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final task = LocalTask(
      id: 'example-task',
      title: 'Bozza',
      dueAt: null,
      completed: false,
      createdAt: DateTime.utc(2026, 10, 21),
    );
    await db.upsertTask(task);
    final pending = await db.pendingOperations();
    await db.acknowledge(pending.single, 0);
    expect(await db.remoteVersionFor('task', task.id), 0);
    await db.upsertTask(task.copyWith(title: 'Aggiornata'));
    expect(await db.remoteVersionFor('task', task.id), 0);
    await db.bindOwner('google-user-A');
    await db.bindOwner('google-user-A');
    await expectLater(db.bindOwner('google-user-B'), throwsStateError);
    await db.close();
  });


  test('Only local edits advance auto-sync revision, not remote reloads', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    expect(container.read(localMutationRevisionProvider), 0);
    await container.read(localStoreProvider.notifier).addTask('Auto-sync test');
    expect(container.read(localMutationRevisionProvider), 1);
    expect(await db.pendingCount(), 1);

    // Applying server results never creates fresh local mutations, and
    // must not cause a sync-pull -> reload -> sync feedback loop.
    await container.read(localStoreProvider.notifier).reload();
    expect(container.read(localMutationRevisionProvider), 1);

    final task = container.read(localStoreProvider).tasks.single;
    await container.read(localStoreProvider.notifier).toggleTask(task.id);
    expect(container.read(localMutationRevisionProvider), 2);
    expect(await db.pendingCount(), 2);
  });


  testWidgets('Google account is represented by one avatar menu', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ], child: const SimpleNotesApp()));
    expect(find.byKey(const Key('account-menu-mobile')), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    await tester.tap(find.byKey(const Key('account-menu-mobile')));
    await tester.pumpAndSettle();
    expect(find.text('Accedi con Google'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

}
