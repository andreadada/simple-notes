import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _storeKey = 'simple_notes.local.v1';
const _uuid = Uuid();

final preferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences must be initialized before runApp.');
});
final localStoreProvider = NotifierProvider<LocalStore, LocalData>(LocalStore.new);

class LocalTask {
  final String id;
  final String title;
  final DateTime? dueAt;
  final bool completed;
  final DateTime createdAt;

  const LocalTask({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.completed,
    required this.createdAt,
  });

  factory LocalTask.fromJson(Map<String, dynamic> j) => LocalTask(
        id: j['id'] as String,
        title: j['title'] as String,
        dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt'] as String),
        completed: j['completed'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueAt': dueAt?.toIso8601String(),
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  LocalTask copyWith({bool? completed, String? title, DateTime? dueAt, bool changeDueAt = false}) =>
      LocalTask(
        id: id,
        title: title ?? this.title,
        dueAt: changeDueAt ? dueAt : this.dueAt,
        completed: completed ?? this.completed,
        createdAt: createdAt,
      );
}

class LocalNote {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const LocalNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory LocalNote.fromJson(Map<String, dynamic> j) => LocalNote(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'body': body, 'createdAt': createdAt.toIso8601String(),
      };

  LocalNote copyWith({String? title, String? body}) =>
      LocalNote(id: id, title: title ?? this.title, body: body ?? this.body, createdAt: createdAt);
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

  Map<String, dynamic> toJson() => {
        'tasks': tasks.map((task) => task.toJson()).toList(),
        'notes': notes.map((note) => note.toJson()).toList(),
      };
}

class LocalStore extends Notifier<LocalData> {
  @override
  LocalData build() {
    final raw = ref.read(preferencesProvider).getString(_storeKey);
    if (raw == null) return const LocalData();
    try {
      return LocalData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const LocalData(); // TODO: surface corrupt storage and provide data recovery.
    } on TypeError {
      return const LocalData();
    }
  }

  Future<void> _persist() async {
    await ref.read(preferencesProvider).setString(_storeKey, jsonEncode(state.toJson()));
  }

  Future<void> addTask(String title, {DateTime? dueAt}) async {
    final value = title.trim();
    if (value.isEmpty) return;
    state = LocalData(
      tasks: [...state.tasks, LocalTask(
        id: _uuid.v4(), title: value, dueAt: dueAt, completed: false, createdAt: DateTime.now(),
      )],
      notes: state.notes,
    );
    await _persist();
  }

  Future<void> toggleTask(String id) async {
    state = LocalData(
      tasks: [
        for (final t in state.tasks) if (t.id == id) t.copyWith(completed: !t.completed) else t
      ],
      notes: state.notes,
    );
    await _persist();
  }

  Future<void> deleteTask(String id) async {
    state = LocalData(tasks: state.tasks.where((t) => t.id != id).toList(), notes: state.notes);
    await _persist();
  }

  Future<void> addNote() async {
    state = LocalData(
      tasks: state.tasks,
      notes: [...state.notes, LocalNote(
        id: _uuid.v4(), title: 'Nuova nota', body: '', createdAt: DateTime.now(),
      )],
    );
    await _persist();
  }

  Future<void> editNote(String id, {String? title, String? body}) async {
    state = LocalData(
      tasks: state.tasks,
      notes: [
        for (final n in state.notes) if (n.id == id) n.copyWith(title: title, body: body) else n
      ],
    );
    await _persist();
  }

  Future<void> deleteNote(String id) async {
    state = LocalData(tasks: state.tasks, notes: state.notes.where((n) => n.id != id).toList());
    await _persist();
  }
}
