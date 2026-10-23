class LocalTask {
  final String id;
  final String title;
  final String description;
  final DateTime? dueAt;
  final bool completed;
  final DateTime createdAt;

  const LocalTask({
    required this.id, required this.title, required this.dueAt,
    required this.completed, required this.createdAt,
    this.description = '',
  });

  factory LocalTask.fromJson(Map<String, dynamic> j) => LocalTask(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt'] as String),
    completed: j['completed'] as bool? ?? false,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'dueAt': dueAt?.toIso8601String(),
    'completed': completed, 'createdAt': createdAt.toIso8601String(),
  };

  LocalTask copyWith({bool? completed, String? title,
    String? description, DateTime? dueAt, bool changeDueAt = false}) => LocalTask(
      id: id, title: title ?? this.title,
      description: description ?? this.description,
      dueAt: changeDueAt ? dueAt : this.dueAt,
      completed: completed ?? this.completed, createdAt: createdAt,
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
    body: j['body'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body, 'createdAt': createdAt.toIso8601String(),
  };

  LocalNote copyWith({String? title, String? body}) => LocalNote(
    id: id, title: title ?? this.title, body: body ?? this.body, createdAt: createdAt,
  );
}

class LocalData {
  final List<LocalTask> tasks;
  final List<LocalNote> notes;
  const LocalData({this.tasks = const [], this.notes = const []});

  factory LocalData.fromJson(Map<String, dynamic> j) => LocalData(
    tasks: (j['tasks'] as List<dynamic>? ?? [])
        .map((e) => LocalTask.fromJson(e as Map<String, dynamic>)).toList(),
    notes: (j['notes'] as List<dynamic>? ?? [])
        .map((e) => LocalNote.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
