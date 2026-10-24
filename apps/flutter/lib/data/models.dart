import 'task_due.dart';
export 'task_due.dart';

class LocalSubtask {
  final String id;
  final String title;
  final bool completed;

  const LocalSubtask({required this.id, required this.title,
    this.completed = false});

  factory LocalSubtask.fromJson(Map<String, dynamic> value) => LocalSubtask(
    id: value['id'] as String,
    title: value['title'] as String,
    completed: value['completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'completed': completed};

  LocalSubtask copyWith({String? title, bool? completed}) => LocalSubtask(
    id: id, title: title ?? this.title,
    completed: completed ?? this.completed,
  );
}

class LocalTaskList {
  final String id;
  final String title;
  final DateTime createdAt;

  const LocalTaskList({required this.id, required this.title,
    required this.createdAt});

  factory LocalTaskList.fromJson(Map<String, dynamic> value) => LocalTaskList(
    id: value['id'] as String,
    title: value['title'] as String,
    createdAt: DateTime.parse(value['createdAt'] as String),
  );

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'createdAt': createdAt.toIso8601String()};

  LocalTaskList copyWith({String? title}) => LocalTaskList(
    id: id, title: title ?? this.title, createdAt: createdAt,
  );
}

class LocalTask {
  final String id;
  final String title;
  final String description;
  final TaskDue due;
  DateTime? get dueAt => due.displayLocal;
  final bool completed;
  final DateTime createdAt;
  final String? listId;
  final int priority;
  final List<String> tags;
  final List<LocalSubtask> subtasks;

  LocalTask({
    required this.id, required this.title, required DateTime? dueAt,
    TaskDue? due,
    required this.completed, required this.createdAt,
    this.description = '',
    this.listId,
    this.priority = 0,
    this.tags = const [],
    this.subtasks = const [],
  }) : due = due ?? TaskDue.legacy(dueAt);

  factory LocalTask.fromJson(Map<String, dynamic> value) => LocalTask(
    id: value['id'] as String,
    title: value['title'] as String,
    description: value['description'] as String? ?? '',
    dueAt: value['dueAt'] == null || value['dueAt'] == ''
      ? null : DateTime.parse(value['dueAt'] as String),
    due: TaskDue.fromJson(value['due'], oldDueAt:
      value['dueAt'] == null || value['dueAt'] == ''
        ? null : DateTime.parse(value['dueAt'] as String)),
    completed: value['completed'] as bool? ?? false,
    createdAt: DateTime.parse(value['createdAt'] as String),
    listId: value['listId'] as String?,
    priority: value['priority'] as int? ?? 0,
    tags: (value['tags'] as List<dynamic>? ?? const [])
        .cast<String>().toList(),
    subtasks: (value['subtasks'] as List<dynamic>? ?? const [])
        .map((item) => LocalSubtask.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'dueAt': due.instant?.toUtc().toIso8601String(),
    'due': due.toJson(),
    'completed': completed, 'createdAt': createdAt.toIso8601String(),
    'listId': listId, 'priority': priority, 'tags': tags,
    'subtasks': subtasks.map((item) => item.toJson()).toList(),
  };

  LocalTask copyWith({
    bool? completed, String? title, String? description, DateTime? dueAt,
    bool changeDueAt = false, TaskDue? due, bool changeDue = false,
    String? listId, bool changeListId = false,
    int? priority, List<String>? tags, List<LocalSubtask>? subtasks,
  }) => LocalTask(
    id: id, title: title ?? this.title,
    description: description ?? this.description,
    dueAt: changeDueAt ? dueAt : this.dueAt,
    due: changeDue ? (due ?? TaskDue.none) :
      changeDueAt ? TaskDue.legacy(dueAt) : this.due,
    completed: completed ?? this.completed, createdAt: createdAt,
    listId: changeListId ? listId : this.listId,
    priority: priority ?? this.priority,
    tags: tags ?? this.tags,
    subtasks: subtasks ?? this.subtasks,
  );
}

class LocalNote {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const LocalNote({
    required this.id, required this.title, required this.body,
    required this.createdAt,
  });

  factory LocalNote.fromJson(Map<String, dynamic> j) => LocalNote(
    id: j['id'] as String, title: j['title'] as String,
    body: j['body'] as String, createdAt: DateTime.parse(j['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body, 'createdAt': createdAt.toIso8601String(),
  };

  LocalNote copyWith({String? title, String? body}) => LocalNote(
    id: id, title: title ?? this.title, body: body ?? this.body,
    createdAt: createdAt,
  );
}

class LocalData {
  final List<LocalTask> tasks;
  final List<LocalNote> notes;
  final List<LocalNote> trashedNotes;
  final List<LocalTaskList> lists;
  const LocalData({
    this.tasks = const [],
    this.notes = const [],
    this.trashedNotes = const [],
    this.lists = const [],
  });

  factory LocalData.fromJson(Map<String, dynamic> value) => LocalData(
    tasks: (value['tasks'] as List<dynamic>? ?? const [])
      .map((item) => LocalTask.fromJson(item as Map<String, dynamic>)).toList(),
    notes: (value['notes'] as List<dynamic>? ?? const [])
      .map((item) => LocalNote.fromJson(item as Map<String, dynamic>)).toList(),
    trashedNotes: (value['trashedNotes'] as List<dynamic>? ?? const [])
      .map((item) => LocalNote.fromJson(item as Map<String, dynamic>)).toList(),
    lists: (value['lists'] as List<dynamic>? ?? const [])
      .map((item) => LocalTaskList.fromJson(item as Map<String, dynamic>)).toList(),
  );

  LocalData copyWith({
    List<LocalTask>? tasks, List<LocalNote>? notes,
    List<LocalNote>? trashedNotes, List<LocalTaskList>? lists,
  }) => LocalData(
    tasks: tasks ?? this.tasks,
    notes: notes ?? this.notes,
    trashedNotes: trashedNotes ?? this.trashedNotes,
    lists: lists ?? this.lists,
  );
}
