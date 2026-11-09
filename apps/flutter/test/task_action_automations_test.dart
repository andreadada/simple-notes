import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/task_action_automations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  LocalTask task({String title = 'Esame Analisi 1',
      List<String> tags = const [], int priority = 0,
      String? listId}) =>
      LocalTask(id: 'task', title: title, dueAt: null,
          completed: false, createdAt: DateTime.utc(2026, 11, 9),
          tags: tags, priority: priority, listId: listId);
  final lists = [
    LocalTaskList(id: 'uni', title: 'Università',
        createdAt: DateTime.utc(2026, 11, 9)),
  ];

  test('created event composes priority, tag and list in configured order', () {
    final library = TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(trigger: 'created',
          action: 'priority', value: '3', titleContains: 'esame'),
      TaskActionLibrary.newRule(trigger: 'created',
          action: 'tag', value: 'Studio', titleContains: 'ANALISI'),
      TaskActionLibrary.newRule(trigger: 'created',
          action: 'list', value: 'uni', titleContains: 'esame'),
      TaskActionLibrary.newRule(trigger: 'completed',
          action: 'tag', value: 'Finito'),
    ]);
    final created = library.apply(task(), trigger: 'created', lists: lists);
    expect(created.priority, 3);
    expect(created.tags, ['Studio']);
    expect(created.listId, 'uni');
    expect(created.completed, isFalse);
    final again = library.apply(created, trigger: 'created', lists: lists);
    expect(again.toJson(), created.toJson());
    final done = library.apply(created.copyWith(completed: true),
        trigger: 'completed', lists: lists);
    expect(done.tags, ['Studio', 'Finito']);
  });

  test('missing list, tag limit and case-insensitive duplicates fail safe',
      () {
    final rules = TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(
          trigger: 'created', action: 'list', value: 'deleted'),
      TaskActionLibrary.newRule(
          trigger: 'created', action: 'tag', value: 'UNI'),
    ]);
    final original = task(listId: 'uni', tags: ['uni']);
    final kept = rules.apply(original, trigger: 'created', lists: lists);
    expect(kept.listId, 'uni');
    expect(kept.tags, ['uni']);
    final full = task(tags: List.generate(16, (n) => 'T$n'));
    final skipped = rules.apply(full, trigger: 'created', lists: lists);
    expect(skipped.tags, full.tags);
    expect(() => rules.apply(original, trigger: 'sync', lists: lists),
        throwsFormatException);
  });

  test('roundtrip owner isolation, empty defaults and strict schema',
      () async {
    const store = TaskActionStore();
    final prefs = await SharedPreferences.getInstance();
    expect((await store.load(prefs, 'alice')).rules, isEmpty);
    final r = TaskActionLibrary.newRule(trigger: 'completed',
        action: 'priority', value: '2', titleContains: 'studio');
    final a = TaskActionLibrary(rules: [r]);
    await store.save(prefs, 'alice', a);
    expect((await store.load(prefs, 'alice')).rules.single.id, r.id);
    expect((await store.load(prefs, 'bob')).rules, isEmpty);
    expect(TaskActionStore.keyForOwner('alice'), isNot(contains('alice')));
    final bad = jsonDecode(a.serialize()) as Map<String, dynamic>;
    bad['schema'] = 99;
    expect(() => TaskActionLibrary.deserialize(jsonEncode(bad)),
        throwsFormatException);
    bad['schema'] = 1;
    (bad['rules'] as List).first['extra'] = 'x';
    expect(() => TaskActionLibrary.deserialize(jsonEncode(bad)),
        throwsFormatException);
    expect(() => TaskActionLibrary(rules: [r, r]),
        throwsFormatException);
  });

  test('corrupted store is never overwritten by a failed read', () async {
    final prefs = await SharedPreferences.getInstance();
    const store = TaskActionStore();
    final key = TaskActionStore.keyForOwner('alice');
    await prefs.setString(key, '{bad');
    await expectLater(store.load(prefs, 'alice'), throwsFormatException);
    expect(prefs.getString(key), '{bad');
  });

  test('invalid action values reject before a rule can execute', () {
    expect(() => TaskActionLibrary.newRule(
        trigger: 'created', action: 'priority', value: '5'),
        throwsFormatException);
    expect(() => TaskActionLibrary.newRule(
        trigger: 'delete', action: 'tag', value: 'ok'),
        throwsFormatException);
    expect(() => TaskActionLibrary.newRule(
        trigger: 'created', action: 'tag', value: 'bad,tag'),
        throwsFormatException);
  });
}
