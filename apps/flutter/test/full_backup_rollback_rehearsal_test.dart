import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_rollback_rehearsal.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/habits_model.dart';
import 'package:simple_notes/ui/theme_mode_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'rehearsal-owner-google';
  const currentPassword = 'long-current-checkpoint-password';
  const targetPassword = 'long-target-backup-password';
  final created = DateTime.utc(2026, 11, 4, 14);
  const codec = FullBackupCodec();
  const rehearsal = FullBackupRollbackRehearsal();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FullBackupSnapshot> makeSnapshot({
    required String ownerId,
    bool target = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(ownerId);
      await db.upsertList(LocalTaskList(
        id: 'list-1', title: target ? 'Lavoro' : 'Personale',
        createdAt: created,
      ));
      await db.upsertTask(LocalTask(
        id: 'task-1',
        title: target ? 'Task target' : 'Task corrente',
        dueAt: null,
        completed: false,
        createdAt: created,
        listId: 'list-1',
      ));
      await db.upsertNote(LocalNote(
        id: 'note-1',
        title: target ? 'Nuova nota' : 'Nota corrente',
        body: target ? 'testo nuovo' : 'testo corrente',
        createdAt: created,
      ));
      if (!target) {
        await db.upsertNote(LocalNote(
          id: 'trash-1', title: 'Cestino preservato',
          body: 'contenuto cestino', createdAt: created,
        ));
        await db.removeNote('trash-1');
      }
      await db.putSetting('syncCursor', target ? '30' : '91');
      await db.putSetting('lastSyncSuccessUtc',
          '2026-11-03T02:24:58.000Z');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          ThemeModePreference.key, target ? 'light' : 'dark');
      final keys = FullBackupSource.preferenceKeys(ownerId);
      await prefs.setString(keys['habits']!, HabitsState().serialize());
      return await const FullBackupSource().capture(
        database: db, preferences: prefs,
        ownerId: ownerId, now: created,
      );
    } finally {
      await db.close();
    }
  }

  Future<List<int>> currentBytes() async =>
      codec.encrypt(await makeSnapshot(ownerId: owner), currentPassword);

  Future<List<int>> targetBytes({String ownerId = owner}) async =>
      codec.encrypt(
        await makeSnapshot(ownerId: ownerId, target: true), targetPassword);

  test('successful staged candidate is rolled back to original checkpoint',
      () async {
    final current = await currentBytes();
    final target = await targetBytes();
    final report = await rehearsal.verify(
      currentCheckpointBytes: current,
      currentCheckpointPassword: currentPassword,
      targetBackupBytes: target,
      targetBackupPassword: targetPassword,
      expectedOwnerId: owner,
    );
    expect(report.interruptedAt, isNull);
    expect(report.rollbackVerified, isTrue);
    expect(report.currentRows['note_entries'], 2);
    expect(report.targetRows['note_entries'], 1);
    expect(report.currentRows['pending_mutations'], greaterThan(0));
    expect(report.currentPreferenceCount, 2);
    expect(report.targetPreferenceCount, 2);
    expect(report.liveRestoreAuthorized, isFalse);
    expect(report.automaticSyncAuthorized, isFalse);
  });

  for (final step in [
    'sqlite:task_entries',
    'sqlite:note_entries',
    'sqlite:sync_settings',
    'preferences:theme',
    'preferences:habits',
    'after-commit',
  ]) {
    test('injected fault at $step restores both stores', () async {
      final report = await rehearsal.verify(
        currentCheckpointBytes: await currentBytes(),
        currentCheckpointPassword: currentPassword,
        targetBackupBytes: await targetBytes(),
        targetBackupPassword: targetPassword,
        expectedOwnerId: owner,
        injectFault: (stage) async {
          if (stage == step) throw FullBackupSandboxInterruption(stage);
        },
      );
      expect(report.interruptedAt, step);
      expect(report.rollbackVerified, isTrue);
      expect(report.currentRows['note_entries'], 2);
      expect(report.automaticSyncAuthorized, isFalse);
    });
  }

  test('wrong password or foreign account is rejected before staging',
      () async {
    final current = await currentBytes();
    final target = await targetBytes();
    await expectLater(rehearsal.verify(
      currentCheckpointBytes: current,
      currentCheckpointPassword: 'incorrect-checkpoint-password',
      targetBackupBytes: target,
      targetBackupPassword: targetPassword,
      expectedOwnerId: owner,
    ), throwsFormatException);
    await expectLater(rehearsal.verify(
      currentCheckpointBytes: current,
      currentCheckpointPassword: currentPassword,
      targetBackupBytes: await targetBytes(ownerId: 'other-account'),
      targetBackupPassword: targetPassword,
      expectedOwnerId: owner,
    ), throwsFormatException);
  });

  test('unexpected stage failure cannot authorize a restore or sync',
      () async {
    await expectLater(rehearsal.verify(
      currentCheckpointBytes: await currentBytes(),
      currentCheckpointPassword: currentPassword,
      targetBackupBytes: await targetBytes(),
      targetBackupPassword: targetPassword,
      expectedOwnerId: owner,
      injectFault: (stage) async {
        if (stage == 'after-commit') {
          throw StateError('Simulated unexpected failure');
        }
      },
    ), throwsStateError);
  });
}
