import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/user_task_templates.dart';

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
}
