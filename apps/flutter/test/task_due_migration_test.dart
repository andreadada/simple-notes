import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// A populated pre-upgrade SQLite v4 database, not a newly created v5 DB.
/// Drift must preserve outbox IDs, cursor, remote versions and old midnight.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Drift V4 -> V5 preserves legacy due instants and pending operations',
      () async {
    final sqlite = sqlite3.sqlite3.openInMemory();
    sqlite.execute("""
      CREATE TABLE task_entries (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        list_id TEXT,
        priority INTEGER NOT NULL DEFAULT 0,
        tags_json TEXT NOT NULL DEFAULT '[]',
        subtasks_json TEXT NOT NULL DEFAULT '[]',
        due_at INTEGER,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        remote_version INTEGER,
        deleted_at INTEGER
      );
      CREATE TABLE task_list_entries (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        remote_version INTEGER,
        deleted_at INTEGER
      );
      CREATE TABLE note_entries (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        remote_version INTEGER,
        deleted_at INTEGER
      );
      CREATE TABLE pending_mutations (
        operation_id TEXT NOT NULL PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE sync_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      );
      PRAGMA user_version = 4;
    """);
    // Drift DateTimeColumn stores seconds since epoch by default.
    sqlite.execute("""
      INSERT INTO task_entries
          (id, title, due_at, created_at, remote_version)
        VALUES ('legacy', 'Mezzanotte storica', 1792886400, 1792771200, 9),
               ('empty', 'Nessuna scadenza', NULL, 1792771200, 4);
      INSERT INTO pending_mutations
          (operation_id, entity_type, entity_id, action, payload, created_at)
        VALUES ('keep-op', 'task', 'legacy', 'upsert',
                '{"title":"Mezzanotte storica","dueAt":"2026-10-25T00:00:00.000"}',
                1792771300);
      INSERT INTO sync_settings (key, value)
        VALUES ('syncCursor', '88'), ('boundOwnerId', 'same-account');
    """);

    final db = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(db.close);
    final snapshot = await db.snapshot();
    expect(snapshot.tasks.length, 2);
    final old = snapshot.tasks.singleWhere((t) => t.id == 'legacy');
    final empty = snapshot.tasks.singleWhere((t) => t.id == 'empty');
    expect(old.due.kind, 'legacy');
    expect(old.due.date, isNull);
    expect(old.due.instant, isNotNull);
    expect(empty.due.kind, 'none');
    expect(await db.remoteVersionFor('task', 'legacy'), 9);
    expect(await db.remoteVersionFor('task', 'empty'), 4);
    expect(await db.setting('syncCursor'), '88');
    expect(await db.setting('boundOwnerId'), 'same-account');

    final pending = await db.pendingOperations();
    expect(pending.length, 1);
    expect(pending.single.operationId, 'keep-op');
    expect(jsonDecode(pending.single.payload)['dueAt'],
        '2026-10-25T00:00:00.000');

    // Repeat the snapshot: the migration must not run a second time.
    final snapshotAgain = await db.snapshot();
    expect(snapshotAgain.tasks.singleWhere((t) => t.id == 'legacy').due.kind,
        'legacy');
    expect((await db.pendingOperations()).single.operationId, 'keep-op');
  });
}
