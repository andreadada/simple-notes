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
}
