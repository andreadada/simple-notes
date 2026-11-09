import 'models.dart';

/// Local, privacy-preserving filters. Nothing is transmitted to a server.
enum TaskDueScope { any, overdue, today, next7, withoutDate }
enum TaskSortOrder { priority, deadline, createdNewest, title }

class TaskQuery {
  const TaskQuery({
    this.search = '',
    this.priority,
    this.tag,
    this.dueScope = TaskDueScope.any,
    this.sort = TaskSortOrder.priority,
    this.completed,
    this.listId,
  });

  final String search;
  final int? priority;
  final String? tag;
  final TaskDueScope dueScope;
  final TaskSortOrder sort;
  final bool? completed;
  final String? listId;

  static DateTime _day(DateTime instant) {
    final local = instant.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? taskDay(LocalTask task) {
    if (task.due.kind == 'date' || task.due.kind == 'datetime') {
      final value = task.due.date;
      if (value != null) {
        final parts = value.split('-').map(int.parse).toList();
        return DateTime(parts[0], parts[1], parts[2]);
      }
    }
    final time = task.due.displayLocal;
    return time == null ? null : _day(time);
  }

  List<LocalTask> apply(Iterable<LocalTask> tasks, {DateTime? at}) {
    final now = _day(at ?? DateTime.now());
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final after7 = DateTime(now.year, now.month, now.day + 7);
    final needle = search.trim().toLowerCase();
    final selectedTag = tag?.trim().toLowerCase();
    final result = tasks.where((task) {
      if (completed != null && task.completed != completed) return false;
      if (listId != null && task.listId != listId) return false;
      if (priority != null && task.priority != priority) return false;
      if (selectedTag != null && selectedTag.isNotEmpty &&
          !task.tags.any((item) => item.toLowerCase() == selectedTag)) {
        return false;
      }
      if (needle.isNotEmpty &&
          !task.title.toLowerCase().contains(needle) &&
          !task.description.toLowerCase().contains(needle) &&
          !task.tags.any((item) => item.toLowerCase().contains(needle)) &&
          !task.subtasks.any(
              (item) => item.title.toLowerCase().contains(needle))) {
        return false;
      }
      final day = taskDay(task);
      return switch (dueScope) {
        TaskDueScope.any => true,
        TaskDueScope.overdue =>
          !task.completed && day != null && day.isBefore(now),
        TaskDueScope.today => day != null && day == now,
        TaskDueScope.next7 =>
          day != null && !day.isBefore(now) && day.isBefore(after7),
        TaskDueScope.withoutDate => day == null,
      };
    }).toList();

    int compare(LocalTask left, LocalTask right) {
      final lDay = taskDay(left);
      final rDay = taskDay(right);
      final byDate = lDay == null && rDay == null
          ? 0 : lDay == null ? 1 : rDay == null ? -1 : lDay.compareTo(rDay);
      final byPriority = right.priority.compareTo(left.priority);
      return switch (sort) {
        TaskSortOrder.priority =>
          byPriority != 0 ? byPriority :
              left.createdAt.compareTo(right.createdAt),
        TaskSortOrder.deadline =>
          byDate != 0 ? byDate : byPriority != 0 ? byPriority :
              left.createdAt.compareTo(right.createdAt),
        TaskSortOrder.createdNewest =>
          right.createdAt.compareTo(left.createdAt),
        TaskSortOrder.title =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      };
    }
    result.sort((a, b) {
      final diff = compare(a, b);
      return diff != 0 ? diff : a.id.compareTo(b.id);
    });
    return result;
  }
}

class TaskAnalyticsSnapshot {
  const TaskAnalyticsSnapshot({
    required this.total,
    required this.completed,
    required this.overdue,
    required this.upcoming,
    required this.highPriority,
    required this.plannedMinutes,
    required this.byList,
  });

  final int total;
  final int completed;
  final int overdue;
  final int upcoming;
  final int highPriority;
  final int plannedMinutes;
  final Map<String?, int> byList;
  int get pending => total - completed;
  double get completionRatio => total == 0 ? 0 : completed / total;

  static TaskAnalyticsSnapshot fromTasks(
    Iterable<LocalTask> tasks, {DateTime? at}
  ) {
    final values = tasks.toList();
    final listCounts = <String?, int>{};
    var completed = 0;
    var planned = 0;
    var highPriority = 0;
    for (final task in values) {
      if (task.completed) completed++;
      if (!task.completed && task.priority >= 2) highPriority++;
      listCounts.update(task.listId, (value) => value + 1, ifAbsent: () => 1);
      for (final slot in task.timeBlocks) {
        planned += slot.block.duration.inMinutes;
      }
    }
    final overdue = TaskQuery(
      dueScope: TaskDueScope.overdue,
    ).apply(values, at: at).length;
    final upcoming = TaskQuery(
      completed: false, dueScope: TaskDueScope.next7,
    ).apply(values, at: at).length;
    return TaskAnalyticsSnapshot(
      total: values.length,
      completed: completed,
      overdue: overdue,
      upcoming: upcoming,
      highPriority: highPriority,
      plannedMinutes: planned,
      byList: Map.unmodifiable(listCounts),
    );
  }
}
