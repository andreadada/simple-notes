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

@DriftDatabase(tables: [TaskEntries, NoteEntries, PendingMutations])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDatabase());

  @override
  int get schemaVersion => 1;

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
