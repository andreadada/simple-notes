import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'task_templates.dart';

/// Device-local, owner-scoped user-defined templates. No sync or OAuth scopes.
/// The encrypted .snb backup includes the optional 'templates' preference;
/// legacy .snb/v1 files without it remain readable.
class UserTaskTemplateLibrary {
  UserTaskTemplateLibrary({Iterable<TaskTemplate> templates = const []})
      : templates = List.unmodifiable(templates) {
    if (this.templates.length > 50 ||
        this.templates.map((t) => t.id).toSet().length !=
            this.templates.length) {
      throw const FormatException('Catalogo modelli non valido.');
    }
    for (final template in this.templates) {
      _check(template);
    }
  }

  static const schema = 1;
  final List<TaskTemplate> templates;

  static void _check(TaskTemplate t) {
    if (!t.id.startsWith('custom-') || t.id.length > 90 ||
        t.title.trim().isEmpty || t.title.length > 160 ||
        t.title != t.title.trim() ||
        t.description.length > 2000 ||
        t.priority < 0 || t.priority > 3 ||
        t.tags.length > 16 ||
        t.tags.any((x) => x.trim().isEmpty || x.length > 40) ||
        t.subtasks.length > 50 ||
        t.subtasks.any((x) => x.trim().isEmpty || x.length > 255) ||
        t.subtasks.toSet().length != t.subtasks.length) {
      throw const FormatException('Modello personalizzato non valido.');
    }
  }

  UserTaskTemplateLibrary upsert(TaskTemplate template) {
    _check(template);
    return UserTaskTemplateLibrary(templates: [
      for (final current in templates)
        if (current.id != template.id) current,
      template,
    ]);
  }

  UserTaskTemplateLibrary remove(String id) =>
      UserTaskTemplateLibrary(templates:
        templates.where((x) => x.id != id));

  String serialize() => jsonEncode({
    'schema': schema,
    'templates': [
      for (final t in templates)
        {
          'id': t.id,
          'title': t.title,
          'description': t.description,
          'priority': t.priority,
          'tags': t.tags,
          'subtasks': t.subtasks,
        },
    ],
  });

  factory UserTaskTemplateLibrary.deserialize(String source) {
    if (utf8.encode(source).length > 512 * 1024) {
      throw const FormatException('Archivio modelli troppo grande.');
    }
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic> || raw.length != 2 ||
        raw['schema'] != schema || raw['templates'] is! List ||
        (raw['templates'] as List).length > 50) {
      throw const FormatException('Versione modelli non supportata.');
    }
    final result = <TaskTemplate>[];
    for (final item in raw['templates'] as List) {
      if (item is! Map || item.length != 6 ||
          item['id'] is! String || item['title'] is! String ||
          item['description'] is! String ||
          item['priority'] is! int ||
          item['tags'] is! List || item['subtasks'] is! List ||
          (item['tags'] as List).any((x) => x is! String) ||
          (item['subtasks'] as List).any((x) => x is! String)) {
        throw const FormatException('Modello danneggiato.');
      }
      result.add(TaskTemplate(
        id: item['id'] as String,
        title: item['title'] as String,
        description: item['description'] as String,
        priority: item['priority'] as int,
        tags: List<String>.unmodifiable((item['tags'] as List).cast<String>()),
        subtasks: List<String>.unmodifiable(
          (item['subtasks'] as List).cast<String>()),
      ));
    }
    return UserTaskTemplateLibrary(templates: result);
  }

  static TaskTemplate newTemplate({
    required String title,
    required String description,
    required List<String> subtasks,
    int priority = 0,
    List<String> tags = const [],
  }) => TaskTemplate(
    id: 'custom-${const Uuid().v4()}',
    title: title.trim(),
    description: description.trim(),
    priority: priority,
    tags: tags.map((x) => x.trim()).toSet().toList(),
    subtasks: subtasks.map((x) => x.trim()).toSet().toList(),
  );
}

class UserTaskTemplateStore {
  const UserTaskTemplateStore();

  static String keyForOwner(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) {
      return 'simple_notes.templates.v1.guest';
    }
    final digest = crypto.sha256.convert(utf8.encode(ownerId));
    return 'simple_notes.templates.v1.$digest';
  }

  Future<UserTaskTemplateLibrary> load(
      SharedPreferences preferences, String? ownerId) async {
    final raw = preferences.getString(keyForOwner(ownerId));
    return raw == null
        ? UserTaskTemplateLibrary()
        : UserTaskTemplateLibrary.deserialize(raw);
  }

  Future<void> save(SharedPreferences preferences, String? ownerId,
      UserTaskTemplateLibrary library) async {
    // Validate before mutating persistent preferences.
    final encoded = library.serialize();
    UserTaskTemplateLibrary.deserialize(encoded);
    final updated = await preferences.setString(
      keyForOwner(ownerId), encoded);
    if (!updated) throw StateError('Salvataggio modello non riuscito.');
  }
}
