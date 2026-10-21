import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import 'models.dart';

export 'models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('AppDatabase must be initialized before runApp.');
});
final initialDataProvider = Provider<LocalData>((ref) {
  throw StateError('Initial snapshot must be loaded before runApp.');
});
final localStoreProvider = NotifierProvider<LocalStore, LocalData>(LocalStore.new);

class LocalStore extends Notifier<LocalData> {
  @override
  LocalData build() => ref.read(initialDataProvider);

  Future<void> reload() async {
    state = await ref.read(databaseProvider).snapshot();
  }

  Future<void> addTask(String title, {DateTime? dueAt}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final task = LocalTask(
      id: const Uuid().v4(), title: trimmed, dueAt: dueAt,
      completed: false, createdAt: DateTime.now(),
    );
    await ref.read(databaseProvider).upsertTask(task);
    state = LocalData(tasks: [...state.tasks, task], notes: state.notes);
  }

  Future<void> toggleTask(String id) async {
    for (final task in state.tasks) {
      if (task.id == id) {
        final changed = task.copyWith(completed: !task.completed);
        await ref.read(databaseProvider).upsertTask(changed);
        state = LocalData(
          tasks: [for (final t in state.tasks) if (t.id == id) changed else t],
          notes: state.notes,
        );
        return;
      }
    }
  }

  Future<void> deleteTask(String id) async {
    await ref.read(databaseProvider).removeTask(id);
    state = LocalData(
      tasks: state.tasks.where((t) => t.id != id).toList(), notes: state.notes,
    );
  }

  Future<void> addNote() async {
    final note = LocalNote(
      id: const Uuid().v4(), title: 'Nuova nota',
      body: '', createdAt: DateTime.now(),
    );
    await ref.read(databaseProvider).upsertNote(note);
    state = LocalData(tasks: state.tasks, notes: [...state.notes, note]);
  }

  Future<void> editNote(String id, {String? title, String? body}) async {
    for (final note in state.notes) {
      if (note.id == id) {
        final changed = note.copyWith(title: title, body: body);
        await ref.read(databaseProvider).upsertNote(changed);
        state = LocalData(
          tasks: state.tasks,
          notes: [for (final n in state.notes) if (n.id == id) changed else n],
        );
        return;
      }
    }
  }

  Future<void> deleteNote(String id) async {
    await ref.read(databaseProvider).removeNote(id);
    state = LocalData(tasks: state.tasks,
      notes: state.notes.where((n) => n.id != id).toList());
  }
}
