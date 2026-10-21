import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

part 'app_database.g.dart';

class TaskEntries extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get remoteVersion => integer().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NoteEntries extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get remoteVersion => integer().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PendingMutations extends Table {
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

class SyncSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [TaskEntries, NoteEntries, PendingMutations, SyncSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDatabase());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(syncSettings);
    },
  );

  static QueryExecutor _openDatabase() => LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return NativeDatabase(File(p.join(directory.path, 'simple_notes.sqlite')));
  });

  Future<LocalData> snapshot() async {
    final tasks = await (select(taskEntries)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final notes = await (select(noteEntries)
          ..where((n) => n.deletedAt.isNull()))
        .get();
    return LocalData(
      tasks: tasks.map((t) => LocalTask(
        id: t.id, title: t.title, dueAt: t.dueAt,
        completed: t.completed, createdAt: t.createdAt,
      )).toList(),
      notes: notes.map((n) => LocalNote(
        id: n.id, title: n.title, body: n.body, createdAt: n.createdAt,
      )).toList(),
    );
  }

  Future<void> upsertTask(LocalTask task) => transaction(() async {
    await into(taskEntries).insertOnConflictUpdate(TaskEntriesCompanion.insert(
      id: task.id,
      title: task.title,
      dueAt: Value(task.dueAt),
      completed: Value(task.completed),
      createdAt: task.createdAt,
    ));
    await _enqueue('task', task.id, 'upsert', jsonEncode(task.toJson()));
  });

  Future<void> removeTask(String id) => transaction(() async {
    await (update(taskEntries)..where((t) => t.id.equals(id)))
        .write(TaskEntriesCompanion(deletedAt: Value(DateTime.now())));
    await _enqueue('task', id, 'delete', '{}');
  });

  Future<void> upsertNote(LocalNote note) => transaction(() async {
    await into(noteEntries).insertOnConflictUpdate(NoteEntriesCompanion.insert(
      id: note.id, title: note.title, body: note.body, createdAt: note.createdAt,
    ));
    await _enqueue('note', note.id, 'upsert', jsonEncode(note.toJson()));
  });

  Future<void> removeNote(String id) => transaction(() async {
    await (update(noteEntries)..where((n) => n.id.equals(id)))
        .write(NoteEntriesCompanion(deletedAt: Value(DateTime.now())));
    await _enqueue('note', id, 'delete', '{}');
  });

  Future<void> _enqueue(String type, String id, String action, String body) async {
    await into(pendingMutations).insert(PendingMutationsCompanion.insert(
      operationId: const Uuid().v4(),
      entityType: type,
      entityId: id,
      action: action,
      payload: body,
      createdAt: DateTime.now(),
    ));
  }

  Future<List<PendingMutation>> pendingOperations() async =>
      (select(pendingMutations)
        ..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();

  Future<int?> remoteVersionFor(String type, String id) async {
    if (type == 'task') {
      final row = await (select(taskEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return row?.remoteVersion;
    }
    final row = await (select(noteEntries)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
    return row?.remoteVersion;
  }

  Future<void> acknowledge(PendingMutation op, int version) => transaction(() async {
    if (op.entityType == 'task') {
      await (update(taskEntries)..where((t) => t.id.equals(op.entityId)))
          .write(TaskEntriesCompanion(remoteVersion: Value(version)));
    } else {
      await (update(noteEntries)..where((n) => n.id.equals(op.entityId)))
          .write(NoteEntriesCompanion(remoteVersion: Value(version)));
    }
    await (delete(pendingMutations)..where((p) => p.operationId.equals(op.operationId))).go();
  });

  Future<String?> setting(String keyName) async {
    final row = await (select(syncSettings)..where((s) => s.key.equals(keyName)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String name, String data) =>
      into(syncSettings).insertOnConflictUpdate(
        SyncSettingsCompanion.insert(key: name, value: data));

  Future<void> bindOwner(String ownerId) async {
    final existing = await setting('boundOwnerId');
    if (existing != null && existing != ownerId) {
      throw StateError('Questo archivio locale è già legato a un altro account Google. '
          'Per sicurezza, non verrà sincronizzato con il nuovo account.');
    }
    if (existing == null) await putSetting('boundOwnerId', ownerId);
  }

  // Pull remote state only if there are no unsent edits on the same entity.
  // Skipped remote changes remain accessible on the server, and their
  // local mutations will hit a version conflict rather than overwrite them.
  Future<void> applyRemote({
    required String type,
    required String entityId,
    required Map<String, dynamic> payload,
    required bool deleted,
    required int version,
  }) => transaction(() async {
    final pending = await (select(pendingMutations)
        ..where((p) => p.entityId.equals(entityId))).get();
    if (pending.isNotEmpty) return;
    if (type == 'task') {
      if (deleted) {
        await (update(taskEntries)..where((t) => t.id.equals(entityId)))
            .write(TaskEntriesCompanion(
              deletedAt: Value(DateTime.now()), remoteVersion: Value(version)));
        return;
      }
      final raw = payload['dueAt'] as String?;
      final created = DateTime.tryParse(payload['createdAt'] as String? ?? '');
      await into(taskEntries).insertOnConflictUpdate(TaskEntriesCompanion.insert(
        id: entityId,
        title: payload['title'] as String,
        dueAt: Value(raw == null || raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal()),
        completed: Value(payload['completed'] as bool? ?? false),
        createdAt: created ?? DateTime.now(),
        deletedAt: const Value(null),
        remoteVersion: Value(version),
      ));
    } else if (type == 'note') {
      if (deleted) {
        await (update(noteEntries)..where((n) => n.id.equals(entityId)))
            .write(NoteEntriesCompanion(
              deletedAt: Value(DateTime.now()), remoteVersion: Value(version)));
        return;
      }
      final created = DateTime.tryParse(payload['createdAt'] as String? ?? '');
      await into(noteEntries).insertOnConflictUpdate(NoteEntriesCompanion.insert(
        id: entityId,
        title: payload['title'] as String,
        body: payload['body'] as String? ?? '',
        createdAt: created ?? DateTime.now(),
        deletedAt: const Value(null),
        remoteVersion: Value(version),
      ));
    }
  });

  Future<int> pendingCount() async {
    final entries = await select(pendingMutations).get();
    return entries.length;
  }

  // One-time import from the first prototype. Remove legacy preferences only after
  // SQLite has committed all rows; no cloud or private data is sent by this migration.
  Future<void> migrateLegacy(SharedPreferences prefs) async {
    const key = 'simple_notes.local.v1';
    final raw = prefs.getString(key);
    if (raw == null) return;
    final legacy = LocalData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await transaction(() async {
      for (final task in legacy.tasks) {
        final existing = await (select(taskEntries)
              ..where((t) => t.id.equals(task.id))).getSingleOrNull();
        if (existing == null) await upsertTask(task);
      }
      for (final note in legacy.notes) {
        final existing = await (select(noteEntries)
              ..where((n) => n.id.equals(note.id))).getSingleOrNull();
        if (existing == null) await upsertNote(note);
      }
    });
    await prefs.remove(key);
  }
}
