import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// P2: rules are evaluated only on explicit local task lifecycle events.
/// The resulting task is persisted once with the standard SQLite sync outbox.
/// Remote pulls, reload, and app startup NEVER replay actions.
class TaskActionRule {
  const TaskActionRule({
    required this.id,
    required this.trigger,
    required this.action,
    required this.value,
    this.titleContains = '',
    this.enabled = true,
  });

  static const triggers = <String>{'created', 'completed'};
  static const actions = <String>{'priority', 'tag', 'list'};

  final String id;
  final String trigger;
  final String action;
  final String value;
  final String titleContains;
  final bool enabled;

  void validate() {
    if (!RegExp(r'^action-[a-zA-Z0-9-]{3,90}$').hasMatch(id) ||
        !triggers.contains(trigger) || !actions.contains(action) ||
        titleContains.length > 100 ||
        titleContains != titleContains.trim() ||
        (titleContains.isNotEmpty && titleContains.trim().isEmpty) ||
        value.isEmpty || value.length > 128 || value != value.trim()) {
      throw const FormatException('Regola di azione non valida.');
    }
    if (action == 'priority' &&
        !const {'0', '1', '2', '3'}.contains(value)) {
      throw const FormatException('Priorità automazione non valida.');
    }
    if (action == 'tag' &&
        (value.length > 40 || value.trim().isEmpty ||
         value.contains(',') || value.contains('\n'))) {
      throw const FormatException('Tag automazione non valido.');
    }
  }

  TaskActionRule copyWith({
    String? trigger, String? action, String? value,
    String? titleContains, bool? enabled,
  }) => TaskActionRule(
    id: id, trigger: trigger ?? this.trigger,
    action: action ?? this.action, value: value ?? this.value,
    titleContains: titleContains ?? this.titleContains,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object> toJson() => {
    'id': id, 'trigger': trigger, 'action': action, 'value': value,
    'titleContains': titleContains, 'enabled': enabled,
  };

  factory TaskActionRule.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> || raw.length != 6 ||
        raw['id'] is! String || raw['trigger'] is! String ||
        raw['action'] is! String || raw['value'] is! String ||
        raw['titleContains'] is! String || raw['enabled'] is! bool) {
      throw const FormatException('Schema regola di azione non valido.');
    }
    final result = TaskActionRule(
      id: raw['id'] as String, trigger: raw['trigger'] as String,
      action: raw['action'] as String, value: raw['value'] as String,
      titleContains: raw['titleContains'] as String,
      enabled: raw['enabled'] as bool,
    );
    result.validate();
    return result;
  }
}

class TaskActionLibrary {
  TaskActionLibrary({Iterable<TaskActionRule> rules = const []})
      : rules = List.unmodifiable(rules) {
    if (this.rules.length > 20 ||
        this.rules.map((r) => r.id).toSet().length != this.rules.length) {
      throw const FormatException('Catalogo azioni non valido.');
    }
    for (final rule in this.rules) {
      rule.validate();
    }
  }

  static const schema = 1;
  final List<TaskActionRule> rules;

  static TaskActionRule newRule({
    required String trigger, required String action,
    required String value, String titleContains = '',
  }) {
    final rule = TaskActionRule(
      id: 'action-${const Uuid().v4()}',
      trigger: trigger, action: action,
      value: value.trim(), titleContains: titleContains.trim());
    rule.validate();
    return rule;
  }

  TaskActionLibrary upsert(TaskActionRule rule) {
    rule.validate();
    return TaskActionLibrary(rules: [
      for (final previous in rules)
        if (previous.id != rule.id) previous,
      rule,
    ]);
  }

  TaskActionLibrary remove(String id) => TaskActionLibrary(
    rules: rules.where((r) => r.id != id));

  String serialize() => jsonEncode({
    'schema': schema,
    'rules': [for (final r in rules) r.toJson()],
  });

  factory TaskActionLibrary.deserialize(String source) {
    if (utf8.encode(source).length > 32 * 1024) {
      throw const FormatException('Archivio azioni troppo grande.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> || value.length != 2 ||
        value['schema'] != schema || value['rules'] is! List ||
        (value['rules'] as List).length > 20) {
      throw const FormatException('Versione azioni non supportata.');
    }
    return TaskActionLibrary(rules: [
      for (final item in value['rules'] as List)
        TaskActionRule.fromJson(item),
    ]);
  }

  /// No side effects: sequence follows rule order. A missing destination list
  /// is ignored rather than creating a dangling FK or an extra entity.
  LocalTask apply(LocalTask original, {
    required String trigger,
    required Iterable<LocalTaskList> lists,
  }) {
    if (!TaskActionRule.triggers.contains(trigger)) {
      throw const FormatException('Evento automazione non supportato.');
    }
    final existingLists = lists.map((l) => l.id).toSet();
    var result = original;
    for (final rule in rules) {
      if (!rule.enabled || rule.trigger != trigger ||
          !result.title.toLowerCase().contains(
              rule.titleContains.toLowerCase())) {
        continue;
      }
      switch (rule.action) {
        case 'priority':
          result = result.copyWith(priority: int.parse(rule.value));
        case 'tag':
          if (result.tags.any((t) =>
              t.toLowerCase() == rule.value.toLowerCase()) ||
              result.tags.length >= 16) {
            continue;
          }
          result = result.copyWith(tags: [...result.tags, rule.value]);
        case 'list':
          if (!existingLists.contains(rule.value)) continue;
          result = result.copyWith(
            listId: rule.value, changeListId: true);
      }
    }
    return result;
  }
}

class TaskActionStore {
  const TaskActionStore();

  static String keyForOwner(String owner) {
    if (owner.trim().isEmpty) {
      throw const FormatException('Account non valido.');
    }
    return 'simple_notes.task_actions.v1.'
        '${crypto.sha256.convert(utf8.encode(owner))}';
  }

  Future<TaskActionLibrary> load(
      SharedPreferences prefs, String owner) async {
    final raw = prefs.getString(keyForOwner(owner));
    return raw == null
        ? TaskActionLibrary()
        : TaskActionLibrary.deserialize(raw);
  }

  Future<void> save(
      SharedPreferences prefs, String owner,
      TaskActionLibrary library) async {
    final source = library.serialize();
    TaskActionLibrary.deserialize(source);
    if (!await prefs.setString(keyForOwner(owner), source)) {
      throw StateError('Salvataggio regola non riuscito.');
    }
  }
}
