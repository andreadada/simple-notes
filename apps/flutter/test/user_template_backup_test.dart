import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/user_task_templates.dart';
import 'package:simple_notes/data/reminder_automations.dart';
import 'package:simple_notes/data/task_action_automations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new encrypted profile archive contains owner-specific templates',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('owner-A');
    final prefs = await SharedPreferences.getInstance();
    final custom = UserTaskTemplateLibrary().upsert(
      UserTaskTemplateLibrary.newTemplate(
        title: 'Progetto', description: 'Milestone',
        subtasks: ['Prima', 'Seconda'],
      ),
    );
    const store = UserTaskTemplateStore();
    await store.save(prefs, 'owner-A', custom);
    await store.save(prefs, 'owner-B',
      UserTaskTemplateLibrary().upsert(
        UserTaskTemplateLibrary.newTemplate(
          title: 'OTHER-ACCOUNT', description: '', subtasks: [])));

    final snapshot = await const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'owner-A',
      now: DateTime.utc(2026, 11, 9),
    );
    expect(snapshot.preferences['templates'], custom.serialize());
    expect(snapshot.toJson().toString(), isNot(contains('OTHER-ACCOUNT')));

    final file = await const FullBackupCodec().encrypt(
      snapshot, 'password-for-testing-2026');
    final decoded = await const FullBackupCodec().inspect(file,
      password: 'password-for-testing-2026', expectedOwnerId: 'owner-A');
    expect(decoded.preferences['templates'], custom.serialize());
  });

  test('legacy v1 archive with five preferences remains readable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('legacy-owner');
    final snapshot = await const FullBackupSource().capture(
      database: db, preferences: await SharedPreferences.getInstance(),
      ownerId: 'legacy-owner',
    );
    final oldJson = snapshot.toJson();
    final oldPrefs = Map<String, dynamic>.from(
        oldJson['preferences'] as Map);
    oldPrefs.remove('templates');
    oldJson['preferences'] = oldPrefs;
    final old = FullBackupSnapshot.fromJson(oldJson);
    expect(old.preferences.containsKey('templates'), isFalse);
    final archive = await const FullBackupCodec()
        .encrypt(old, 'legacy-backup-password-2026');
    final decoded = await const FullBackupCodec().inspect(
      archive, password: 'legacy-backup-password-2026',
      expectedOwnerId: 'legacy-owner',
    );
    expect(decoded.preferences['templates'], isNull);
  });

  test('corrupted optional template data rejects authenticated snapshot',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('owner');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UserTaskTemplateStore.keyForOwner('owner'),
      '{"schema":99,"templates":[]}');
    await expectLater(const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'owner',
    ), throwsFormatException);
  });
  test('encrypted .snb includes owner-only automation rules as optional data',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('automations-A');
    final prefs = await SharedPreferences.getInstance();
    const store = ReminderAutomationStore();
    await store.save(prefs, 'automations-A', ReminderAutomationLibrary(
      rules: const [
        ReminderAutomationRule(
          id: 'rule-private', kind: 'block', leadMinutes: 30,
          minPriority: 2),
      ],
    ));
    await store.save(prefs, 'automations-B', ReminderAutomationLibrary(
      rules: const [
        ReminderAutomationRule(
          id: 'rule-other-account', kind: 'due', leadMinutes: 60),
      ],
    ));
    final snapshot = await const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'automations-A');
    expect(snapshot.preferences['automations'], contains('rule-private'));
    expect(snapshot.toJson().toString(), isNot(contains('rule-other-account')));
    final file = await const FullBackupCodec().encrypt(
      snapshot, 'password-for-automations-2026');
    final checked = await const FullBackupCodec().inspect(file,
      password: 'password-for-automations-2026',
      expectedOwnerId: 'automations-A');
    expect(checked.preferences['automations'],
        snapshot.preferences['automations']);
    final legacy = snapshot.toJson();
    final prefsCopy = Map<String, dynamic>.from(
      legacy['preferences'] as Map);
    prefsCopy.remove('automations');
    legacy['preferences'] = prefsCopy;
    expect(FullBackupSnapshot.fromJson(legacy)
        .preferences.containsKey('automations'), isFalse);
  });

  test('invalid automation JSON prevents incomplete full backup', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('bad-automation-owner');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ReminderAutomationStore.keyForOwner('bad-automation-owner'),
      '{"schema":999,"rules":[]}');
    await expectLater(const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'bad-automation-owner'),
      throwsFormatException);
  });

  test('encrypted .snb archives task actions only for the bound owner',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('actions-A');
    final prefs = await SharedPreferences.getInstance();
    const store = TaskActionStore();
    await store.save(prefs, 'actions-A', TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(
        trigger: 'created', action: 'tag', value: 'private'),
    ]));
    await store.save(prefs, 'actions-B', TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(
        trigger: 'completed', action: 'tag', value: 'OTHER-OWNER-SECRET'),
    ]));
    final backup = await const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'actions-A');
    expect(backup.preferences['taskActions'], contains('private'));
    expect(backup.toJson().toString(),
      isNot(contains('OTHER-OWNER-SECRET')));
    final encoded = await const FullBackupCodec()
      .encrypt(backup, 'password-for-task-actions-2026');
    final inspected = await const FullBackupCodec().inspect(encoded,
      password: 'password-for-task-actions-2026',
      expectedOwnerId: 'actions-A');
    expect(inspected.preferences['taskActions'],
        backup.preferences['taskActions']);
    // Archives created before task-actions existed remain compatible.
    final old = backup.toJson();
    final prevPrefs = Map<String, dynamic>.from(
        old['preferences'] as Map);
    prevPrefs.remove('taskActions');
    old['preferences'] = prevPrefs;
    expect(FullBackupSnapshot.fromJson(old)
        .preferences.containsKey('taskActions'), isFalse);
  });

  test('bad action catalog blocks encrypted backup rather than losing rules',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.bindOwner('bad-rule');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(TaskActionStore.keyForOwner('bad-rule'),
        '{"schema":999,"rules":[]}');
    await expectLater(const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'bad-rule'),
      throwsFormatException);
  });

}
