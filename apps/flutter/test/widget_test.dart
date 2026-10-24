import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/inline_editable_title.dart';
import 'package:simple_notes/ui/inline_editable_body.dart';
import 'package:simple_notes/ui/inline_quick_add.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/main.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';

Future<void> _noopInline(String value) async {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Inline fields are transparent and show an underline',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true, fillColor: Color(0xFF242424),
        ),
      ),
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: Column(children: [
          InlineEditableTitle(
            value: 'Attività',
            style: const TextStyle(fontSize: 18),
            semanticsLabel: 'Titolo',
            onSave: (value) async {},
          ),
          InlineEditableBody(
            value: 'Una descrizione',
            semanticsLabel: 'Descrizione',
            onSave: (value) async {},
          ),
          InlineQuickAdd(onAdd: (value) async {}),
        ])),
      ),
    ));
    final titleField = tester.widget<TextField>(find.descendant(
      of: find.byType(InlineEditableTitle),
      matching: find.byType(TextField),
    ));
    final bodyField = tester.widget<TextField>(find.descendant(
      of: find.byType(InlineEditableBody),
      matching: find.byType(TextField),
    ));
    final quickField = tester.widget<TextField>(
        find.byKey(const Key('inline-quick-add-input')));
    for (final field in [titleField, bodyField, quickField]) {
      final decoration = field.decoration!;
      expect(decoration.filled, isFalse);
      expect(decoration.fillColor, Colors.transparent);
      expect(decoration.enabledBorder, isA<UnderlineInputBorder>());
      expect(decoration.focusedBorder, isA<UnderlineInputBorder>());
    }
  });

  testWidgets('Underline follows text and placeholder lengths', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InlineEditableTitle(
              key: const Key('short-title'),
              value: 'A',
              style: const TextStyle(fontSize: 18),
              semanticsLabel: 'Short title',
              onSave: (text) async {},
            ),
            InlineEditableTitle(
              key: const Key('long-title'),
              value: 'Una attività lunga',
              style: const TextStyle(fontSize: 18),
              semanticsLabel: 'Long title',
              onSave: (text) async {},
            ),
            const SizedBox(width: 340, child: InlineEditableBody(
              value: '', semanticsLabel: 'Body', hint: 'Scrivi...',
              onSave: _noopInline,
            )),
            const SizedBox(width: 340, child: InlineQuickAdd(
              onAdd: _noopInline,
              hint: 'Nuovo sottotask...',
            )),
          ],
        )),
      ),
    ));
    final short = tester.getSize(
      find.byKey(const Key('short-title'))).width;
    final long = tester.getSize(
      find.byKey(const Key('long-title'))).width;
    expect(short, lessThan(40));
    expect(long, greaterThan(short * 2));
    final shortUnderline = tester.getSize(find.descendant(
      of: find.byKey(const Key('short-title')),
      matching: find.byKey(const Key('inline-glyph-underline')),
    )).width;
    expect(shortUnderline, lessThan(40));
    final body = tester.getSize(find.descendant(
      of: find.byType(InlineEditableBody),
      matching: find.byKey(const Key('inline-glyph-underline')),
    )).width;
    expect(body, lessThan(120));
    // Even a tight Expanded/SizedBox parent cannot stretch the underline.
    expect(tester.getSize(find.byType(InlineEditableBody)).width, 340);
    final quick = tester.getSize(find.descendant(
      of: find.byType(InlineQuickAdd),
      matching: find.byKey(const Key('inline-glyph-underline')),
    )).width;
    expect(quick, lessThan(200));
    final titleInput = tester.widget<TextField>(find.descendant(
      of: find.byKey(const Key('short-title')),
      matching: find.byType(TextField)));
    final bodyInput = tester.widget<TextField>(find.descendant(
      of: find.byType(InlineEditableBody),
      matching: find.byType(TextField)));
    expect(titleInput.decoration!.hintStyle!.color!.a, lessThan(1));
    expect(bodyInput.decoration!.hintStyle!.color!.a, lessThan(1));
  });

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


  test('Forui themes share Simple Notes design tokens', () {
    final desktop = NotesTheme.forPlatform(TargetPlatform.windows);
    final touch = NotesTheme.forPlatform(TargetPlatform.android);
    expect(desktop.colors.primary, NotesPalette.accent);
    expect(touch.colors.primary, NotesPalette.accent);
    expect(desktop.colors.background, NotesPalette.background);
    expect(touch.colors.background, NotesPalette.background);
  });

  testWidgets('Forui provides the desktop sidebar and task search',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final database = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(const LocalData()),
    ], child: const SimpleNotesApp()));
    await tester.pump();
    expect(find.byType(FTheme), findsOneWidget);
    expect(find.byType(FSidebar), findsOneWidget);
    expect(find.byType(FTextField), findsOneWidget);
    expect(find.byKey(const Key('task-input')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });


  testWidgets('Due date picker uses Forui dialog and calendar', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(const LocalData()),
    ], child: const SimpleNotesApp()));

    await tester.tap(find.byTooltip('Imposta data'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forui-date-dialog')), findsOneWidget);
    expect(find.byType(FDialog), findsOneWidget);
    expect(find.byType(FCalendar), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);

    // The chosen calendar day must be retained for a newly created task.
    await tester.tap(find.byKey(const Key('confirm-due-date')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-input')),
        'Attività con scadenza');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final task = (await database.snapshot()).tasks.single;
    expect(task.dueAt, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });

  testWidgets('Task editor is a Forui dialog with editable title',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final database = AppDatabase(NativeDatabase.memory());
    await database.upsertTask(LocalTask(
      id: 'modal-test-task',
      title: 'Attività originale',
      dueAt: null,
      completed: false,
      createdAt: DateTime.utc(2026, 10, 23),
    ));
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(await database.snapshot()),
    ], child: const SimpleNotesApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inline-task-row-modal-test-task')));
    await tester.pumpAndSettle();
    final inlineTitle = find.descendant(
      of: find.byKey(const Key('inline-task-title-modal-test-task')),
      matching: find.byType(TextField),
    );
    expect(inlineTitle, findsOneWidget);
    await tester.enterText(inlineTitle, 'Aggiornata direttamente');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await database.snapshot()).tasks.single.title,
        'Aggiornata direttamente');

    await tester.tap(find.byKey(const Key('advanced-task-editor')));
    await tester.pumpAndSettle();
    expect(find.byType(FDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('edit-task-title')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit-task-title')), 'Titolo aggiornato');
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect((await database.snapshot()).tasks.single.title, 'Titolo aggiornato');

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });


  test('All simple attributes write to SQLite and preserve outbox', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(const LocalData()),
    ]);
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final store = container.read(localStoreProvider.notifier);
    await store.addTask('Test inline');
    final task = container.read(localStoreProvider).tasks.single;
    await store.renameTask(task.id, 'Nome modificato direttamente');
    await store.setTaskDescription(task.id, 'Descrizione locale');
    await store.setTaskPriority(task.id, 3);
    await store.setTaskTags(task.id, 'università, urgente');
    await store.addSubtask(task.id, 'Preparare');
    final sub = container.read(localStoreProvider).tasks.single.subtasks.single;
    await store.renameSubtask(task.id, sub.id, 'Ripassare');
    await store.addNote();
    final note = container.read(localStoreProvider).notes.single;
    await store.renameNote(note.id, 'Nota modificata direttamente');
    await store.setNoteBody(note.id, 'Corpo modificato inline');
    await store.reload();

    final data = await database.snapshot();
    expect(data.tasks.single.title, 'Nome modificato direttamente');
    expect(data.tasks.single.description, 'Descrizione locale');
    expect(data.tasks.single.priority, 3);
    expect(data.tasks.single.tags, ['università', 'urgente']);
    expect(data.tasks.single.subtasks.single.title, 'Ripassare');
    expect(data.notes.single.title, 'Nota modificata direttamente');
    expect(data.notes.single.body, 'Corpo modificato inline');
    expect(await database.pendingCount(), greaterThanOrEqualTo(10));
  });

  testWidgets('Notes expose inline title and body, without edit dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    await db.upsertNote(LocalNote(
      id: 'inline-note-test', title: 'Nota iniziale', body: 'Testo',
      createdAt: DateTime.utc(2026, 10, 24),
    ));
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(await db.snapshot()),
    ], child: const SimpleNotesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-notes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inline-note-title-inline-note-test')),
        findsOneWidget);
    expect(find.byKey(const Key('inline-note-body-inline-note-test')),
        findsOneWidget);
    expect(find.text('Modifica nota'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

  test('Task description persists offline and survives a DB reload', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(const LocalData()),
    ]);
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(localStoreProvider.notifier).addTask('Esame');
    final task = container.read(localStoreProvider).tasks.single;
    await container.read(localStoreProvider.notifier).editTask(
      task.id, title: task.title, description: 'Capitoli 1–4',
    );
    expect((await database.snapshot()).tasks.single.description, 'Capitoli 1–4');
    expect((await database.pendingOperations()).last.payload,
        contains('Capitoli 1–4'));
    await container.read(localStoreProvider.notifier).reload();
    expect(container.read(localStoreProvider).tasks.single.description,
        'Capitoli 1–4');
  });


  testWidgets('Forui sidebar creates and selects a synced task list',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
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
    await tester.tap(find.byKey(const Key('create-list')));
    await tester.pumpAndSettle();
    expect(find.byType(FDialog), findsOneWidget);
    await tester.enterText(find.byKey(const Key('list-title')), 'Università');
    await tester.tap(find.byKey(const Key('save-list')));
    await tester.pumpAndSettle();
    expect((await db.snapshot()).lists.single.title, 'Università');
    final newListId = (await db.snapshot()).lists.single.id;
    await tester.tap(find.byKey(Key('list-$newListId')));
    await tester.pumpAndSettle();
    final inline = find.byKey(Key('inline-list-title-$newListId'));
    expect(inline, findsOneWidget);
    expect(find.byKey(const Key('rename-list')), findsNothing);
    final titleInput = find.descendant(
      of: inline, matching: find.byType(TextField));
    await tester.enterText(titleInput, 'Università e lavoro');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await db.snapshot()).lists.single.title, 'Università e lavoro');
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

}
