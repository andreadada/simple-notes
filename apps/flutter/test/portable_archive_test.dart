import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/data/portable_archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final created = DateTime.utc(2026, 10, 30, 12);
  LocalData fixture() => LocalData(
    lists: [
      LocalTaskList(id: 'list-a', title: 'Lavoro', createdAt: created),
    ],
    tasks: [
      LocalTask(
        id: 'task-a',
        title: 'Consegna',
        description: 'Contenuto',
        dueAt: null,
        due: TaskDue.dateOnly('2026-12-31'),
        recurrence: TaskRecurrence('weekly'),
        completed: false,
        createdAt: created,
        listId: 'list-a',
        priority: 2,
        tags: ['progetto'],
        subtasks: [
          const LocalSubtask(id: 'sub-a', title: 'Test', completed: true),
        ],
        timeBlocks: [
          TimeSlot(id: 'slot-a', block: TimeBlock(
            start: DateTime.utc(2026, 12, 30, 9),
            end: DateTime.utc(2026, 12, 30, 10),
            timeZone: 'Europe/Rome',
          )),
        ],
      ),
    ],
    notes: [
      LocalNote(id: 'note-a', title: 'Promemoria',
          body: 'Testo riservato', createdAt: created),
    ],
    trashedNotes: [
      LocalNote(id: 'trash-a', title: 'Eliminata',
          body: 'Non importare', createdAt: created),
    ],
  );

  test('portable archive exports only active entities and preserves semantics',
      () {
    final bytes = PortableArchive(fixture()).encode(now: created);
    final text = utf8.decode(bytes);
    expect(text, contains('simple-notes-portable'));
    expect(text, isNot(contains('Eliminata')));
    expect(text, isNot(contains('boundOwnerId')));
    expect(text, isNot(contains('operationId')));
    final archive = PortableArchive.decode(bytes);
    expect(archive.recordCount, 3);
    expect(archive.data.trashedNotes, isEmpty);
    final task = archive.data.tasks.single;
    expect(task.due.kind, 'date');
    expect(task.due.date, '2026-12-31');
    expect(task.recurrence.kind, 'weekly');
    expect(task.timeBlocks.single.block.timeZone, 'Europe/Rome');
    expect(task.tags, ['progetto']);
    expect(task.subtasks.single.completed, true);
    expect(archive.data.notes.single.body, 'Testo riservato');
  });

  test('copies use new IDs and remap list, subtask and slot references', () {
    var n = 0;
    final archive = PortableArchive.decode(PortableArchive(fixture()).encode());
    final copies = archive.asNewCopies(newId: () => 'fresh-${++n}');
    expect(copies.lists.single.id, isNot('list-a'));
    expect(copies.tasks.single.id, isNot('task-a'));
    expect(copies.tasks.single.listId, copies.lists.single.id);
    expect(copies.tasks.single.subtasks.single.id, isNot('sub-a'));
    expect(copies.tasks.single.timeBlocks.single.id, isNot('slot-a'));
    expect(copies.tasks.single.due.toJson(), fixture().tasks.single.due.toJson());
    expect(copies.tasks.single.recurrence.kind, 'weekly');
    expect(copies.notes.single.id, isNot('note-a'));
  });

  test('corrupt, future schema and orphan references are rejected', () {
    expect(() => PortableArchive.decode(utf8.encode('not json')),
        throwsFormatException);
    final archive = jsonDecode(utf8.decode(PortableArchive(fixture()).encode()))
        as Map<String, dynamic>;
    archive['schemaVersion'] = 999;
    expect(() => PortableArchive.decode(utf8.encode(jsonEncode(archive))),
        throwsFormatException);
    archive['schemaVersion'] = 1;
    (archive['data'] as Map<String, dynamic>)['tasks'][0]['listId'] = 'missing';
    expect(() => PortableArchive.decode(utf8.encode(jsonEncode(archive))),
        throwsFormatException);
    expect(() => PortableArchive.decode(List<int>.filled(
        PortableArchive.maxBytes + 1, 32)), throwsFormatException);
  });

  test('additive import preserves existing entities and outbox', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final existing = LocalNote(
      id: 'existing', title: 'Non perdere', body: 'originale',
      createdAt: created,
    );
    await db.upsertNote(existing);
    final initial = await db.snapshot();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(initial),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final archive = PortableArchive.decode(PortableArchive(fixture()).encode());
    final count = await container.read(localStoreProvider.notifier)
        .importPortable(archive);
    expect(count, 3);
    final after = await db.snapshot();
    expect(after.lists.length, 1);
    expect(after.tasks.length, 1);
    expect(after.notes.length, 2);
    expect(after.notes.singleWhere((x) => x.id == 'existing').body, 'originale');
    expect(after.tasks.single.listId, after.lists.single.id);
    expect(after.tasks.single.due.date, '2026-12-31');
    expect(await db.pendingCount(), 4); // old note + list/task/note copies
    expect(container.read(localStoreProvider).tasks.length, 1);

    // Re-import is an explicit second copy, never overwriting earlier IDs.
    await container.read(localStoreProvider.notifier).importPortable(archive);
    expect((await db.snapshot()).tasks.length, 2);
    expect(await db.pendingCount(), 7);
  });
}
