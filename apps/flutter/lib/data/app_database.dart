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
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get listId => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get subtasksJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get remoteVersion => integer().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TaskListEntries extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
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

@DriftDatabase(tables: [
  TaskEntries, TaskListEntries, NoteEntries, PendingMutations, SyncSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDatabase());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(syncSettings);
      if (from < 3) await m.addColumn(taskEntries, taskEntries.description);
      if (from < 4) {
        await m.createTable(taskListEntries);
        await m.addColumn(taskEntries, taskEntries.listId);
        await m.addColumn(taskEntries, taskEntries.priority);
        await m.addColumn(taskEntries, taskEntries.tagsJson);
        await m.addColumn(taskEntries, taskEntries.subtasksJson);
      }
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
    final lists = await (select(taskListEntries)
          ..where((l) => l.deletedAt.isNull())).get();
    return LocalData(
      lists: lists.map((l) => LocalTaskList(
        id: l.id, title: l.title, createdAt: l.createdAt,
      )).toList(),
      tasks: tasks.map((t) => LocalTask(
        id: t.id, title: t.title, description: t.description,
        dueAt: t.dueAt,
        listId: t.listId,
        priority: t.priority,
        tags: (jsonDecode(t.tagsJson) as List<dynamic>).cast<String>(),
        subtasks: (jsonDecode(t.subtasksJson) as List<dynamic>)
            .map((item) => LocalSubtask.fromJson(item as Map<String, dynamic>))
            .toList(),
        completed: t.completed, createdAt: t.createdAt,
      )).toList(),
      notes: notes.map((n) => LocalNote(
        id: n.id, title: n.title, body: n.body, createdAt: n.createdAt,
      )).toList(),
    );
  }

  Future<void> upsertTask(LocalTask task) => transaction(() async {
    final previous = await (select(taskEntries)..where((t) => t.id.equals(task.id)))
        .getSingleOrNull();
    await into(taskEntries).insertOnConflictUpdate(TaskEntriesCompanion.insert(
      id: task.id,
      title: task.title,
      description: Value(task.description),
      listId: Value(task.listId),
      priority: Value(task.priority),
      tagsJson: Value(jsonEncode(task.tags)),
      subtasksJson: Value(jsonEncode(
          task.subtasks.map((item) => item.toJson()).toList())),
      dueAt: Value(task.dueAt),
      completed: Value(task.completed),
      createdAt: task.createdAt,
      remoteVersion: Value(previous?.remoteVersion),
      deletedAt: const Value(null),
    ));
    await _enqueue('task', task.id, 'upsert', jsonEncode(task.toJson()));
  });

  Future<void> removeTask(String id) => transaction(() async {
    await (update(taskEntries)..where((t) => t.id.equals(id)))
        .write(TaskEntriesCompanion(deletedAt: Value(DateTime.now())));
    await _enqueue('task', id, 'delete', '{}');
  });

  Future<void> upsertList(LocalTaskList list) => transaction(() async {
    final previous = await (select(taskListEntries)
        ..where((row) => row.id.equals(list.id))).getSingleOrNull();
    await into(taskListEntries).insertOnConflictUpdate(
      TaskListEntriesCompanion.insert(
        id: list.id, title: list.title, createdAt: list.createdAt,
        remoteVersion: Value(previous?.remoteVersion),
        deletedAt: const Value(null),
      ),
    );
    await _enqueue('list', list.id, 'upsert', jsonEncode(list.toJson()));
  });

  Future<void> removeList(String id) => transaction(() async {
    await (update(taskListEntries)..where((row) => row.id.equals(id)))
        .write(TaskListEntriesCompanion(deletedAt: Value(DateTime.now())));
    await _enqueue('list', id, 'delete', '{}');
  });

  Future<void> upsertNote(LocalNote note) => transaction(() async {
    final previous = await (select(noteEntries)..where((n) => n.id.equals(note.id)))
        .getSingleOrNull();
    await into(noteEntries).insertOnConflictUpdate(NoteEntriesCompanion.insert(
      id: note.id, title: note.title, body: note.body, createdAt: note.createdAt,
      remoteVersion: Value(previous?.remoteVersion),
      deletedAt: const Value(null),
    ));
    await _enqueue('note', note.id, 'upsert', jsonEncode(note.toJson()));
  });

  Future<void> removeNote(String id) => transaction(() async {
    await (update(noteEntries)..where((n) => n.id.equals(id)))
        .write(NoteEntriesCompanion(deletedAt: Value(DateTime.now())));
    await _enqueue('note', id, 'delete', '{}');
  });

  Future<void> _enqueue(String type, String id, String action, String body) async {
    // Drift stores SQLite DateTime with second resolution. Force a strictly
    // monotonic order to preserve list-upsert → task-upsert and move → delete.
    final latest = await (select(pendingMutations)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1)).getSingleOrNull();
    final now = DateTime.now();
    final next = latest?.createdAt.add(const Duration(seconds: 1));
    final timestamp = next != null && now.isBefore(next) ? next : now;
    await into(pendingMutations).insert(PendingMutationsCompanion.insert(
      operationId: const Uuid().v4(),
      entityType: type,
      entityId: id,
      action: action,
      payload: body,
      createdAt: timestamp,
    ));
  }

  Future<List<PendingMutation>> pendingOperations() async =>
      (select(pendingMutations)
        ..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();

  Future<int?> remoteVersionFor(String type, String id) async {
    if (type == 'list') {
      final row = await (select(taskListEntries)
          ..where((item) => item.id.equals(id))).getSingleOrNull();
      return row?.remoteVersion;
    }
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
    if (op.entityType == 'list') {
      await (update(taskListEntries)
        ..where((row) => row.id.equals(op.entityId)))
          .write(TaskListEntriesCompanion(remoteVersion: Value(version)));
    } else if (op.entityType == 'task') {
      await (update(taskEntries)..where((t) => t.id.equals(op.entityId)))
          .write(TaskEntriesCompanion(remoteVersion: Value(version)));
    } else {
      await (update(noteEntries)..where((n) => n.id.equals(op.entityId)))
          .write(NoteEntriesCompanion(remoteVersion: Value(version)));
    }
    await (delete(pendingMutations)..where((p) => p.operationId.equals(op.operationId))).go();
  });

  // The user must explicitly choose a conflict resolution. Keep other
  // entities in the outbox, and never clear the entire local database.
  Future<void> acceptRemoteConflict({
    required String type,
    required String entityId,
    required Map<String, dynamic> payload,
    required bool deleted,
    required int version,
  }) => transaction(() async {
    await (delete(pendingMutations)..where((m) =>
        m.entityType.equals(type) & m.entityId.equals(entityId))).go();
    await applyRemote(type: type, entityId: entityId,
        payload: payload, deleted: deleted, version: version);
  });

  Future<void> rebaseLocalConflict({
    required String type,
    required String entityId,
    required int remoteVersion,
  }) => transaction(() async {
    if (type == 'list') {
      await (update(taskListEntries)..where((row) => row.id.equals(entityId)))
          .write(TaskListEntriesCompanion(remoteVersion: Value(remoteVersion)));
    } else if (type == 'task') {
      await (update(taskEntries)..where((t) => t.id.equals(entityId)))
          .write(TaskEntriesCompanion(remoteVersion: Value(remoteVersion)));
    } else if (type == 'note') {
      await (update(noteEntries)..where((n) => n.id.equals(entityId)))
          .write(NoteEntriesCompanion(remoteVersion: Value(remoteVersion)));
    } else {
      throw StateError('Tipo di entità non valido');
    }
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
    if (type == 'list') {
      if (deleted) {
        await (update(taskListEntries)..where((l) => l.id.equals(entityId)))
            .write(TaskListEntriesCompanion(
              deletedAt: Value(DateTime.now()), remoteVersion: Value(version)));
        return;
      }
      final created = DateTime.tryParse(payload['createdAt'] as String? ?? '');
      await into(taskListEntries).insertOnConflictUpdate(
        TaskListEntriesCompanion.insert(
          id: entityId,
          title: payload['title'] as String,
          createdAt: created ?? DateTime.now(),
          deletedAt: const Value(null),
          remoteVersion: Value(version),
        ),
      );
    } else if (type == 'task') {
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
        description: Value(payload['description'] as String? ?? ''),
        listId: Value(payload['listId'] as String?),
        priority: Value(payload['priority'] as int? ?? 0),
        tagsJson: Value(jsonEncode(payload['tags'] ?? const [])),
        subtasksJson: Value(jsonEncode(payload['subtasks'] ?? const [])),
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
