import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import 'models.dart';
import 'portable_archive.dart';

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

  /// Import is additive and atomic: failed writes roll back with the outbox.
  Future<int> importPortable(PortableArchive archive) async {
    final copies = archive.asNewCopies();
    final database = ref.read(databaseProvider);
    await database.transaction(() async {
      for (final list in copies.lists) {
        await database.upsertList(list);
      }
      for (final task in copies.tasks) {
        await database.upsertTask(task);
      }
      for (final note in copies.notes) {
        await database.upsertNote(note);
      }
    });
    await reload();
    if (archive.recordCount > 0) _changed();
    return archive.recordCount;
  }

  Future<void> reload() async {
    state = await ref.read(databaseProvider).snapshot();
  }

  void _changed() => ref.read(localMutationRevisionProvider.notifier).state++;

  Future<void> addTask(String title, {DateTime? dueAt, TaskDue? due, String? listId}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    if (listId != null && !state.lists.any((list) => list.id == listId)) {
      throw StateError('La lista selezionata non esiste.');
    }
    final task = LocalTask(
      id: const Uuid().v4(), title: trimmed, dueAt: dueAt, due: due,
      completed: false, createdAt: DateTime.now(), listId: listId,
    );
    await ref.read(databaseProvider).upsertTask(task);
    state = state.copyWith(tasks: [...state.tasks, task]);
    _changed();
  }

  Future<void> editTask(String id, {
    required String title, String? description, DateTime? dueAt,
    TaskDue? due, bool changeDue = false,
    String? listId, bool changeListId = false, int? priority,
    List<String>? tags, List<LocalSubtask>? subtasks,
    TimeBlock? timeBlock, bool changeTimeBlock = false,
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
          dueAt: dueAt, changeDueAt: !changeDue && dueAt != task.dueAt,
          due: due, changeDue: changeDue,
          listId: listId, changeListId: changeListId,
          priority: priority,
          tags: tags?.map((tag) => tag.trim()).toSet().toList(),
          subtasks: subtasks,
          timeBlock: timeBlock, changeTimeBlock: changeTimeBlock,
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

  // Property-level writes use the newest in-memory task rather than a stale
  // editor snapshot. Every edit still goes through SQLite + the sync outbox.
  Future<void> renameTask(String id, String title) async {
    final text = title.trim();
    if (text.isEmpty || text.length > 1024) {
      throw StateError('Il titolo deve contenere da 1 a 1024 caratteri.');
    }
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    if (task.title != text) await _persistTask(task.copyWith(title: text));
  }

  Future<void> setTaskDescription(String id, String description) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    if (task.description != description) {
      await _persistTask(task.copyWith(description: description));
    }
  }

  Future<void> setTaskPriority(String id, int priority) async {
    if (priority < 0 || priority > 3) throw StateError('Priorità non valida.');
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    if (task.priority != priority) {
      await _persistTask(task.copyWith(priority: priority));
    }
  }

  /// T2 API: explicit modern semantics, without guessing whether legacy
  /// midnight is date-only. A future T3 UI will expose the choice.
  Future<void> setTaskDueSemantics(String id, TaskDue due) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    await _persistTask(task.copyWith(due: due, changeDue: true,
      recurrence: due.modern ? task.recurrence : TaskRecurrence.none,
      changeRecurrence: true));
  }

  Future<void> setTaskRecurrence(String id, TaskRecurrence rule) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    if (rule.enabled && !task.due.modern) {
      throw StateError('Imposta prima una scadenza con data.');
    }
    if (task.recurrence.kind == rule.kind &&
        task.recurrence.interval == rule.interval) {
      return;
    }
    await _persistTask(task.copyWith(
        recurrence: rule, changeRecurrence: true));
  }

  /// An explicit block update uses the newest in-memory task and keeps
  /// its independent due date intact. null clears the block, not the due date.
  Future<void> setTaskTimeBlock(String id, TimeBlock? block) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    await _persistTask(task.copyWith(
        timeBlock: block, changeTimeBlock: true));
  }

  /// Target one stable slot ID; no other scheduled interval is discarded.
  Future<void> addTaskTimeSlot(String id, TimeBlock block) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    await _persistTask(task.copyWith(timeBlocks: [
      ...task.timeBlocks,
      TimeSlot(id: const Uuid().v4(), block: block),
    ], changeTimeBlocks: true));
  }

  Future<void> updateTaskTimeSlot(
      String id, String slotId, TimeBlock block) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null || !task.timeBlocks.any((x) => x.id == slotId)) {
      throw StateError('Blocco orario non disponibile.');
    }
    await _persistTask(task.copyWith(timeBlocks: [
      for (final slot in task.timeBlocks)
        slot.id == slotId ? slot.copyWith(block: block) : slot,
    ], changeTimeBlocks: true));
  }

  Future<void> removeTaskTimeSlot(String id, String slotId) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null || !task.timeBlocks.any((x) => x.id == slotId)) {
      throw StateError('Blocco orario non disponibile.');
    }
    await _persistTask(task.copyWith(timeBlocks: [
      for (final slot in task.timeBlocks) if (slot.id != slotId) slot,
    ], changeTimeBlocks: true));
  }

  Future<void> duplicateTaskTimeSlot(String id, String slotId) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    final slot = task?.timeBlocks.where((x) => x.id == slotId).firstOrNull;
    if (slot == null) throw StateError('Blocco orario non disponibile.');
    final shifted = TimeBlock(
      start: slot.block.start.add(const Duration(days: 1)),
      end: slot.block.end.add(const Duration(days: 1)),
      timeZone: slot.block.timeZone);
    await addTaskTimeSlot(id, shifted);
  }

  Future<void> setTaskDue(String id, DateTime? date) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    await _persistTask(task.copyWith(dueAt: date, changeDueAt: true));
  }

  Future<void> setTaskList(String id, String? listId) async {
    if (listId != null && !state.lists.any((item) => item.id == listId)) {
      throw StateError('La lista selezionata non esiste.');
    }
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    if (task.listId != listId) {
      await _persistTask(task.copyWith(listId: listId, changeListId: true));
    }
  }

  Future<void> setTaskTags(String id, String raw) async {
    final tags = raw.split(',').map((item) => item.trim())
        .where((item) => item.isNotEmpty).toSet().toList();
    if (tags.length > 16 || tags.any((item) => item.length > 40)) {
      throw StateError('Massimo 16 tag, fino a 40 caratteri ciascuno.');
    }
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    await _persistTask(task.copyWith(tags: tags));
  }

  Future<void> renameSubtask(String taskId, String subtaskId, String value) async {
    final text = value.trim();
    if (text.isEmpty || text.length > 255) {
      throw StateError('Il sottotask deve contenere da 1 a 255 caratteri.');
    }
    final task = state.tasks.where((item) => item.id == taskId).firstOrNull;
    if (task == null || !task.subtasks.any((item) => item.id == subtaskId)) {
      throw StateError('Sottotask non disponibile.');
    }
    await _persistTask(task.copyWith(subtasks: [
      for (final item in task.subtasks)
        item.id == subtaskId ? item.copyWith(title: text) : item,
    ]));
  }

  Future<void> addSubtask(String taskId, String value) async {
    final text = value.trim();
    final task = state.tasks.where((item) => item.id == taskId).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    if (text.isEmpty || text.length > 255 || task.subtasks.length >= 50) {
      throw StateError('Massimo 50 sottotask, fino a 255 caratteri.');
    }
    await _persistTask(task.copyWith(subtasks: [
      ...task.subtasks, LocalSubtask(id: const Uuid().v4(), title: text),
    ]));
  }

  Future<void> removeSubtask(String taskId, String subtaskId) async {
    final task = state.tasks.where((item) => item.id == taskId).firstOrNull;
    if (task == null) throw StateError('Attività non disponibile.');
    await _persistTask(task.copyWith(subtasks: [
      for (final item in task.subtasks) if (item.id != subtaskId) item,
    ]));
  }

  Future<void> toggleTask(String id) async {
    final task = state.tasks.where((item) => item.id == id).firstOrNull;
    if (task == null) return;
    if (!task.completed && task.recurrence.enabled) {
      // Advance *once* in the same task/UUID; one SQLite transaction and
      // one outbox operation. A second device must pass the server version
      // check, avoiding duplicate future task entities.
      final next = task.recurrence.advance(task.due);
      await _persistTask(task.copyWith(
          due: next, changeDue: true, completed: false));
      return;
    }
    await _persistTask(task.copyWith(completed: !task.completed));
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

  Future<void> renameNote(String id, String title) async {
    final value = title.trim();
    if (value.isEmpty || value.length > 255) {
      throw StateError('Il titolo deve contenere da 1 a 255 caratteri.');
    }
    await editNote(id, title: value);
  }

  Future<void> setNoteBody(String id, String body) async {
    await editNote(id, body: body);
  }

  Future<void> deleteNote(String id) async {
    final note = state.notes.where((item) => item.id == id).firstOrNull;
    if (note == null) throw StateError('Nota non disponibile.');
    await ref.read(databaseProvider).removeNote(id);
    state = state.copyWith(
      notes: state.notes.where((item) => item.id != id).toList(),
      trashedNotes: [...state.trashedNotes, note],
    );
    _changed();
  }

  Future<void> restoreNote(String id) async {
    final note = state.trashedNotes.where((item) => item.id == id).firstOrNull;
    if (note == null) throw StateError('Nota non presente nel cestino.');
    await ref.read(databaseProvider).restoreNote(id);
    state = state.copyWith(
      notes: [...state.notes, note],
      trashedNotes: state.trashedNotes.where((item) => item.id != id).toList(),
    );
    _changed();
  }
}
