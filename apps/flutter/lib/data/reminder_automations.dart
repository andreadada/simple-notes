import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// P2 local automation: user-defined reminder schedule, not a server job.
/// Rules never read Google credentials or write tasks / sync mutations.
class ReminderAutomationRule {
  const ReminderAutomationRule({
    required this.id,
    required this.kind,
    required this.leadMinutes,
    this.minPriority = 0,
    this.enabled = true,
  });

  static const leadChoices = <int>{0, 5, 15, 30, 60, 1440};
  static const kinds = <String>{'due', 'block'};

  final String id;
  final String kind;
  final int leadMinutes;
  final int minPriority;
  final bool enabled;

  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,90}$').hasMatch(id) ||
        !kinds.contains(kind) ||
        !leadChoices.contains(leadMinutes) ||
        minPriority < 0 || minPriority > 3) {
      throw const FormatException('Regola di automazione non valida.');
    }
  }

  ReminderAutomationRule copyWith({
    String? kind,
    int? leadMinutes,
    int? minPriority,
    bool? enabled,
  }) => ReminderAutomationRule(
    id: id,
    kind: kind ?? this.kind,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    minPriority: minPriority ?? this.minPriority,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object> toJson() => {
    'id': id, 'kind': kind, 'leadMinutes': leadMinutes,
    'minPriority': minPriority, 'enabled': enabled,
  };

  factory ReminderAutomationRule.fromJson(Object? source) {
    if (source is! Map<String, dynamic> || source.length != 5 ||
        source['id'] is! String || source['kind'] is! String ||
        source['leadMinutes'] is! int || source['minPriority'] is! int ||
        source['enabled'] is! bool) {
      throw const FormatException('Formato regola non valido.');
    }
    final rule = ReminderAutomationRule(
      id: source['id'] as String,
      kind: source['kind'] as String,
      leadMinutes: source['leadMinutes'] as int,
      minPriority: source['minPriority'] as int,
      enabled: source['enabled'] as bool,
    );
    rule.validate();
    return rule;
  }
}

class ReminderAutomationLibrary {
  ReminderAutomationLibrary({required Iterable<ReminderAutomationRule> rules})
      : rules = List.unmodifiable(rules) {
    if (this.rules.length > 20 ||
        this.rules.map((r) => r.id).toSet().length != this.rules.length) {
      throw const FormatException('Massimo 20 regole con ID distinti.');
    }
    for (final rule in this.rules) {
      rule.validate();
    }
  }

  static const schema = 1;
  final List<ReminderAutomationRule> rules;

  /// Matches legacy fixed 15-minute due/block reminders until first edit.
  factory ReminderAutomationLibrary.defaults() => ReminderAutomationLibrary(
    rules: const [
      ReminderAutomationRule(
        id: 'rule-default-due', kind: 'due', leadMinutes: 15),
      ReminderAutomationRule(
        id: 'rule-default-block', kind: 'block', leadMinutes: 15),
    ],
  );

  static ReminderAutomationRule create({
    required String kind, required int leadMinutes,
    int minPriority = 0,
  }) {
    final rule = ReminderAutomationRule(
      id: 'rule-${const Uuid().v4()}',
      kind: kind, leadMinutes: leadMinutes, minPriority: minPriority,
    );
    rule.validate();
    return rule;
  }

  ReminderAutomationLibrary upsert(ReminderAutomationRule next) {
    next.validate();
    return ReminderAutomationLibrary(rules: [
      for (final current in rules)
        if (current.id != next.id) current,
      next,
    ]);
  }

  ReminderAutomationLibrary remove(String id) =>
      ReminderAutomationLibrary(rules: rules.where((r) => r.id != id));

  String serialize() => jsonEncode({
    'schema': schema,
    'rules': [for (final rule in rules) rule.toJson()],
  });

  factory ReminderAutomationLibrary.deserialize(String raw) {
    if (utf8.encode(raw).length > 32 * 1024) {
      throw const FormatException('Archivio automazioni troppo grande.');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> || value.length != 2 ||
        value['schema'] != schema || value['rules'] is! List ||
        (value['rules'] as List).length > 20) {
      throw const FormatException('Versione automazioni non supportata.');
    }
    return ReminderAutomationLibrary(rules: [
      for (final item in value['rules'] as List)
        ReminderAutomationRule.fromJson(item),
    ]);
  }
}

class ReminderAutomationStore {
  const ReminderAutomationStore();

  static String keyForOwner(String ownerId) {
    if (ownerId.trim().isEmpty) {
      throw const FormatException('Account automazioni non valido.');
    }
    final digest = crypto.sha256.convert(utf8.encode(ownerId));
    return 'simple_notes.reminder_automations.v1.$digest';
  }

  Future<ReminderAutomationLibrary> load(
    SharedPreferences prefs, String ownerId,
  ) async {
    final raw = prefs.getString(keyForOwner(ownerId));
    return raw == null
        ? ReminderAutomationLibrary.defaults()
        : ReminderAutomationLibrary.deserialize(raw);
  }

  Future<void> save(
    SharedPreferences prefs, String ownerId,
    ReminderAutomationLibrary library,
  ) async {
    final encoded = library.serialize();
    ReminderAutomationLibrary.deserialize(encoded);
    final ok = await prefs.setString(keyForOwner(ownerId), encoded);
    if (!ok) throw StateError('Salvataggio automazioni non riuscito.');
  }
}
