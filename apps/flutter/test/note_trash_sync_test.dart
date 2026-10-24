import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Deleting a note moves it to trash; explicit restore enqueues a '
      'versioned restore instead of an upsert', () async {
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
    await store.addNote();
    final note = container.read(localStoreProvider).notes.single;
    await store.editNote(note.id, title: 'Appunti', body: 'Testo da salvare');
    await store.deleteNote(note.id);

    expect(container.read(localStoreProvider).notes, isEmpty);
    expect(container.read(localStoreProvider).trashedNotes.single.body,
        'Testo da salvare');
    expect((await database.snapshot()).trashedNotes.single.id, note.id);
    expect((await database.pendingOperations()).last.action, 'delete');

    await store.restoreNote(note.id);
    expect(container.read(localStoreProvider).notes.single.id, note.id);
    expect(container.read(localStoreProvider).trashedNotes, isEmpty);
    expect((await database.snapshot()).notes.single.body, 'Testo da salvare');
    expect((await database.pendingOperations()).last.action, 'restore');

    await expectLater(store.restoreNote(note.id), throwsStateError);
    await store.deleteNote(note.id);
    await expectLater(store.deleteNote(note.id), throwsStateError);
  });

  test('A remote note tombstone is kept in trash and stale sync events '
      'cannot silently resurrect it', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final id = 'note-from-remote';
    final payload = {
      'title': 'Nota', 'body': 'Contenuto',
      'createdAt': '2026-10-24T10:00:00Z',
    };
    await database.applyRemote(type: 'note', entityId: id,
        payload: payload, deleted: false, version: 0);
    await database.applyRemote(type: 'note', entityId: id,
        payload: {}, deleted: true, version: 1);
    expect((await database.snapshot()).notes, isEmpty);
    expect((await database.snapshot()).trashedNotes.single.body, 'Contenuto');

    await database.applyRemote(type: 'note', entityId: id,
        payload: payload, deleted: false, version: 0);
    expect((await database.snapshot()).notes, isEmpty);
    expect((await database.snapshot()).trashedNotes.single.title, 'Nota');

    await database.restoreNote(id);
    expect((await database.pendingOperations()).single.action, 'restore');
    expect((await database.snapshot()).notes.single.body, 'Contenuto');
  });
}
