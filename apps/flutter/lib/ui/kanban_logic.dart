import '../data/models.dart';

/// Kanban P1.9 is a projection of synced lists, NOT a separate workflow state.
/// No task is mutated when computing this view.
class KanbanColumn {
  const KanbanColumn({required this.id, required this.title,
      required this.tasks});
  final String? id;
  final String title;
  final List<LocalTask> tasks;
}

abstract final class KanbanLogic {
  /// Always show Inbox and every existing list, including empty ones.
  /// Deleted/missing list references are displayed in Inbox without silently
  /// rewriting the task's original listId (the sync engine owns repair).
  static List<KanbanColumn> columns(LocalData data) {
    final knownIds = data.lists.map((item) => item.id).toSet();
    List<LocalTask> forList(String? id) {
      final tasks = data.tasks.where((task) =>
          !task.completed &&
          (id == null ? task.listId == null ||
              !knownIds.contains(task.listId) : task.listId == id)).toList();
      tasks.sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        final byCreation = a.createdAt.compareTo(b.createdAt);
        return byCreation != 0 ? byCreation : a.id.compareTo(b.id);
      });
      return List.unmodifiable(tasks);
    }

    return [
      KanbanColumn(id: null, title: 'Inbox', tasks: forList(null)),
      for (final list in data.lists)
        KanbanColumn(id: list.id, title: list.title, tasks: forList(list.id)),
    ];
  }

  /// Used by DragTarget and accessible move menus. Never write a mutation
  /// when a task is already in its destination.
  static bool canMove(LocalData data, String taskId, String? destinationId) {
    if (destinationId != null &&
        !data.lists.any((list) => list.id == destinationId)) {
      return false;
    }
    final task = data.tasks.where((item) => item.id == taskId).firstOrNull;
    return task != null && !task.completed && task.listId != destinationId;
  }
}
