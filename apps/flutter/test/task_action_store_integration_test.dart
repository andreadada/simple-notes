import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/auth/cloud_auth.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/data/task_action_automations.dart';
import 'package:simple_notes/data/task_templates.dart';

class TestAccount extends CloudAuth {
  TestAccount(String? owner) {
    state = CloudSession(
      userId: owner, accessToken: owner == null ? null : 'unit-test-token',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AppDatabase, ProviderContainer)> prepare({
    String? owner = 'account-a',
    bool bound = true,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    if (bound) await db.bindOwner('account-a');
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
      cloudAuthProvider.overrideWith((ref) => TestAccount(owner)),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    return (db, container);
  }

  test('create and template create run actions in one task/outbox write',
      () async {
    final (db, container) = await prepare();
    final prefs = await SharedPreferences.getInstance();
    final rules = TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(
        trigger: 'created', action: 'priority', value: '3'),
      TaskActionLibrary.newRule(
        trigger: 'created', action: 'tag', value: 'AUTO'),
    ]);
    await const TaskActionStore().save(prefs, 'account-a', rules);
    final local = container.read(localStoreProvider.notifier);
    await local.addTask('Nuovo esame');
    var snapshot = await db.snapshot();
    expect(snapshot.tasks.single.priority, 3);
    expect(snapshot.tasks.single.tags, ['AUTO']);
    expect(await db.pendingCount(), 1);

    await local.createTaskFromDefinition(TaskTemplateCatalog.find('meeting'));
    snapshot = await db.snapshot();
    expect(snapshot.tasks, hasLength(2));
    expect(snapshot.tasks.every((t) => t.priority == 3), isTrue);
    expect(snapshot.tasks.every((t) => t.tags.contains('AUTO')), isTrue);
    expect(await db.pendingCount(), 2);
    await local.reload();
    expect(await db.pendingCount(), 2);
  });

  test('completion actions run once per explicit transition and undo skips',
      () async {
    final (db, container) = await prepare();
    final prefs = await SharedPreferences.getInstance();
    await const TaskActionStore().save(prefs, 'account-a',
      TaskActionLibrary(rules: [
        TaskActionLibrary.newRule(
          trigger: 'completed', action: 'tag', value: 'Finished'),
        TaskActionLibrary.newRule(
          trigger: 'completed', action: 'priority', value: '2'),
      ]));
    final local = container.read(localStoreProvider.notifier);
    await local.addTask('Task');
    final id = (await db.snapshot()).tasks.single.id;
    expect(await db.pendingCount(), 1);
    await local.toggleTask(id);
    var task = (await db.snapshot()).tasks.single;
    expect(task.completed, isTrue);
    expect(task.tags, ['Finished']);
    expect(task.priority, 2);
    expect(await db.pendingCount(), 2);
    await local.reload();
    expect(await db.pendingCount(), 2);
    await local.toggleTask(id);
    expect((await db.snapshot()).tasks.single.completed, isFalse);
    expect((await db.snapshot()).tasks.single.tags, ['Finished']);
    expect(await db.pendingCount(), 3);
    await local.toggleTask(id);
    task = (await db.snapshot()).tasks.single;
    expect(task.tags, ['Finished']);
    expect(await db.pendingCount(), 4);
  });

  test('owner mismatch and corrupt rules never mutate tasks or lose archive',
      () async {
    final (db, container) = await prepare(owner: 'account-b');
    final prefs = await SharedPreferences.getInstance();
    const store = TaskActionStore();
    await store.save(prefs, 'account-a', TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(
        trigger: 'created', action: 'priority', value: '3'),
    ]));
    final local = container.read(localStoreProvider.notifier);
    await local.addTask('Unchanged');
    expect((await db.snapshot()).tasks.single.priority, 0);
    expect(await db.pendingCount(), 1);
    // Owner A restores but its archive is corrupt: normal task creation works.
    final corrupt = TaskActionStore.keyForOwner('account-b');
    await prefs.setString(corrupt, '{wrong');
    await local.addTask('Still unchanged');
    expect((await db.snapshot()).tasks.every((t) => t.priority == 0), isTrue);
    expect(prefs.getString(corrupt), '{wrong');
    expect(await db.pendingCount(), 2);
  });

  test('unbound device does not run account automation', () async {
    final (db, container) = await prepare(bound: false);
    final prefs = await SharedPreferences.getInstance();
    await const TaskActionStore().save(prefs, 'account-a',
      TaskActionLibrary(rules: [
        TaskActionLibrary.newRule(
          trigger: 'created', action: 'priority', value: '3'),
      ]));
    await container.read(localStoreProvider.notifier).addTask('Guest');
    expect((await db.snapshot()).tasks.single.priority, 0);
  });
  test('recurrent completion advances due without triggering completion action',
      () async {
    final (db, container) = await prepare();
    final prefs = await SharedPreferences.getInstance();
    await const TaskActionStore().save(prefs, 'account-a',
      TaskActionLibrary(rules: [
        TaskActionLibrary.newRule(
          trigger: 'completed', action: 'tag', value: 'completed-only'),
      ]));
    final store = container.read(localStoreProvider.notifier);
    await store.addTask('Recurring', due: TaskDue.dateOnly('2026-11-10'));
    final id = (await db.snapshot()).tasks.single.id;
    await store.setTaskRecurrence(id, TaskRecurrence('daily'));
    await store.toggleTask(id);
    final result = (await db.snapshot()).tasks.single;
    expect(result.completed, isFalse);
    expect(result.due.date, '2026-11-11');
    expect(result.tags, isNot(contains('completed-only')));
    expect(await db.pendingCount(), 3);
  });

  test('matching owner with corrupt archive still persists an unchanged task',
      () async {
    final (db, container) = await prepare();
    final prefs = await SharedPreferences.getInstance();
    final key = TaskActionStore.keyForOwner('account-a');
    await prefs.setString(key, '{broken');
    await container.read(localStoreProvider.notifier).addTask('Ordinary');
    expect((await db.snapshot()).tasks.single.priority, 0);
    expect(await db.pendingCount(), 1);
    expect(prefs.getString(key), '{broken');
  });

}
