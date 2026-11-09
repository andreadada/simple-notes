import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/user_task_templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('custom models roundtrip without losing identity or subtasks', () {
    final template = UserTaskTemplateLibrary.newTemplate(
      title: '  Esame  ', description: 'Ripassare',
      priority: 2, tags: ['Uni', 'Uni'],
      subtasks: ['Capitolo 1', 'Capitolo 2'],
    );
    final library = UserTaskTemplateLibrary().upsert(template);
    final restored = UserTaskTemplateLibrary.deserialize(library.serialize());
    expect(restored.templates, hasLength(1));
    expect(restored.templates.single.id, template.id);
    expect(restored.templates.single.title, 'Esame');
    expect(restored.templates.single.tags, ['Uni']);
    expect(restored.templates.single.subtasks, ['Capitolo 1', 'Capitolo 2']);
    expect(restored.remove(template.id).templates, isEmpty);
  });

  test('owner-scoped preferences never mix users or guest data', () async {
    final prefs = await SharedPreferences.getInstance();
    const store = UserTaskTemplateStore();
    final model = UserTaskTemplateLibrary().upsert(
      UserTaskTemplateLibrary.newTemplate(
        title: 'Solo account A', description: '', subtasks: ['Studiare'],
      ),
    );
    await store.save(prefs, 'account-A', model);
    expect((await store.load(prefs, 'account-A')).templates, hasLength(1));
    expect((await store.load(prefs, 'account-B')).templates, isEmpty);
    expect((await store.load(prefs, null)).templates, isEmpty);
    expect(UserTaskTemplateStore.keyForOwner('account-A'),
        isNot(UserTaskTemplateStore.keyForOwner('account-B')));
    expect(UserTaskTemplateStore.keyForOwner('account-A'),
        isNot(contains('account-A')));
  });

  test('duplicate IDs, invalid bounds and unknown schemas fail closed', () {
    final valid = UserTaskTemplateLibrary.newTemplate(
      title: 'Piano', description: '', subtasks: ['A'],
    );
    expect(
      () => UserTaskTemplateLibrary(templates: [valid, valid]),
      throwsFormatException,
    );
    expect(
      () => UserTaskTemplateLibrary().upsert(
        UserTaskTemplateLibrary.newTemplate(
          title: ' ', description: '', subtasks: [],
        )),
      throwsFormatException,
    );
    final corrupt = jsonDecode(
      UserTaskTemplateLibrary(templates: [valid]).serialize(),
    ) as Map<String, dynamic>;
    corrupt['schema'] = 999;
    expect(() => UserTaskTemplateLibrary.deserialize(jsonEncode(corrupt)),
      throwsFormatException);
    corrupt['schema'] = 1;
    (corrupt['templates'] as List).first['priority'] = -1;
    expect(() => UserTaskTemplateLibrary.deserialize(jsonEncode(corrupt)),
      throwsFormatException);
    corrupt['templates'] = [for (var n = 0; n < 51; n++) {}];
    expect(() => UserTaskTemplateLibrary.deserialize(jsonEncode(corrupt)),
      throwsFormatException);
  });

  test('an invalid stored library cannot be replaced through a failed load',
      () async {
    final prefs = await SharedPreferences.getInstance();
    const store = UserTaskTemplateStore();
    await prefs.setString(
      UserTaskTemplateStore.keyForOwner('owner'),
      'CORRUPTED-SAVED-CONTENT',
    );
    await expectLater(store.load(prefs, 'owner'), throwsFormatException);
    expect(prefs.getString(UserTaskTemplateStore.keyForOwner('owner')),
      'CORRUPTED-SAVED-CONTENT');
  });
}
