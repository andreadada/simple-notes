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

// Local writes alone advance the revision; remote pull never triggers
// an upload loop.
final localMutationRevisionProvider = StateProvider<int>((ref) => 0);

class LocalStore extends Notifier<LocalData> {
  @override
  LocalData build() => ref.read(initialDataProvider);

  Future<void> reload() async {
    state = await ref.read(databaseProvider).snapshot();
  }

  void _changed() => ref.read(localMutationRevisionProvider.notifier).state++;

  Future<void> addTask(String title, {DateTime? dueAt, String? listId}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    if (listId != null && !state.lists.any((list) => list.id == listId)) {
      throw StateError('La lista selezionata non esiste.');
    }
    final task = LocalTask(
      id: const Uuid().v4(), title: trimmed, dueAt: dueAt,
      completed: false, createdAt: DateTime.now(), listId: listId,
    );
    await ref.read(databaseProvider).upsertTask(task);
    state = state.copyWith(tasks: [...state.tasks, task]);
    _changed();
  }

  Future<void> editTask(String id, {
    required String title, String? description, DateTime? dueAt,
    String? listId, bool changeListId = false, int? priority,
    List<String>? tags, List<LocalSubtask>? subtasks,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    if (changeListId && listId != null &&
        !state.lists.any((list) => list.id == listId)) {
      throw StateError('La lista selezionata non esiste.');
    }
    if (priority != null && (priority < 0 || priority > 3)) {
      throw StateError('Priorità non valida');
    }
    if (tags != null && (tags.length > 16 ||
        tags.any((tag) => tag.trim().isEmpty || tag.length > 40))) {
      throw StateError('Massimo 16 tag, fino a 40 caratteri per tag');
    }
    if (subtasks != null && (subtasks.length > 50 ||
        subtasks.any((task) =>
            task.title.trim().isEmpty || task.title.length > 255))) {
      throw StateError('Massimo 50 sottotask, fino a 255 caratteri');
    }
    for (final task in state.tasks) {
      if (task.id == id) {
        final changed = task.copyWith(
          title: trimmed, description: description,
          dueAt: dueAt, changeDueAt: true,
          listId: listId, changeListId: changeListId,
          priority: priority,
          tags: tags?.map((tag) => tag.trim()).toSet().toList(),
          subtasks: subtasks,
        );
        await _persistTask(changed);
        return;
      }
    }
  }

  Future<void> _persistTask(LocalTask task) async {
    await ref.read(databaseProvider).upsertTask(task);
    state = state.copyWith(tasks: [
      for (final existing in state.tasks)
        if (existing.id == task.id) task else existing,
    ]);
    _changed();
  }

  Future<void> toggleTask(String id) async {
    for (final task in state.tasks) {
      if (task.id == id) {
        await _persistTask(task.copyWith(completed: !task.completed));
        return;
      }
    }
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    for (final task in state.tasks) {
      if (task.id == taskId) {
        await _persistTask(task.copyWith(subtasks: [
          for (final item in task.subtasks)
            item.id == subtaskId
              ? item.copyWith(completed: !item.completed)
              : item,
        ]));
        return;
      }
    }
  }

  Future<void> deleteTask(String id) async {
    await ref.read(databaseProvider).removeTask(id);
    state = state.copyWith(
      tasks: state.tasks.where((task) => task.id != id).toList(),
    );
    _changed();
  }

  Future<void> addList(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 255) return;
    final list = LocalTaskList(
      id: const Uuid().v4(), title: trimmed, createdAt: DateTime.now(),
    );
    await ref.read(databaseProvider).upsertList(list);
    state = state.copyWith(lists: [...state.lists, list]);
    _changed();
  }

  Future<void> renameList(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 255) return;
    for (final list in state.lists) {
      if (list.id == id) {
        final updated = list.copyWith(title: trimmed);
        await ref.read(databaseProvider).upsertList(updated);
        state = state.copyWith(lists: [
          for (final item in state.lists)
            item.id == id ? updated : item,
        ]);
        _changed();
        return;
      }
    }
  }

  /// Reassign items before deleting a list: preserve tasks and ensure
  /// server foreign keys and sync change ordering remain valid.
  Future<void> deleteList(String id) async {
    if (!state.lists.any((list) => list.id == id)) return;
    for (final task in state.tasks.where((task) => task.listId == id).toList()) {
      await _persistTask(task.copyWith(listId: null, changeListId: true));
    }
    await ref.read(databaseProvider).removeList(id);
    state = state.copyWith(
      lists: state.lists.where((list) => list.id != id).toList(),
    );
    _changed();
  }

  Future<void> addNote() async {
    final note = LocalNote(
      id: const Uuid().v4(), title: 'Nuova nota',
      body: '', createdAt: DateTime.now(),
    );
    await ref.read(databaseProvider).upsertNote(note);
    state = state.copyWith(notes: [...state.notes, note]);
    _changed();
  }

  Future<void> editNote(String id, {String? title, String? body}) async {
    for (final note in state.notes) {
      if (note.id == id) {
        final changed = note.copyWith(title: title, body: body);
        await ref.read(databaseProvider).upsertNote(changed);
        state = state.copyWith(notes: [
          for (final item in state.notes)
            if (item.id == id) changed else item,
        ]);
        _changed();
        return;
      }
    }
  }

  Future<void> deleteNote(String id) async {
    await ref.read(databaseProvider).removeNote(id);
    state = state.copyWith(
      notes: state.notes.where((note) => note.id != id).toList(),
    );
    _changed();
  }
}
