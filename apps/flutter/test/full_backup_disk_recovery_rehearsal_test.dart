import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_disk_recovery_rehearsal.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'disk-restore-test-owner';
  const currentPassword = 'long-current-test-password';
  const importedPassword = 'long-imported-test-password';
  const codec = FullBackupCodec();
  final created = DateTime.utc(2026, 11, 4, 19);

  Future<FullBackupSnapshot> snapshot(bool imported) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(owner);
      await db.upsertList(LocalTaskList(
        id: 'list-1', title: imported ? 'Old' : 'Current',
        createdAt: created,
      ));
      await db.upsertTask(LocalTask(
        id: 'task-1', title: imported ? 'Old task' : 'Current task',
        dueAt: null, completed: false,
        listId: 'list-1', createdAt: created,
      ));
      await db.upsertNote(LocalNote(
        id: 'note-1', title: imported ? 'Old note' : 'Current note',
        body: imported ? 'old private contents' : 'current private contents',
        createdAt: created,
      ));
      if (!imported) {
        await db.upsertNote(LocalNote(
          id: 'trashed-1', title: 'Keep trash',
          body: 'tombstone contents', createdAt: created,
        ));
        await db.removeNote('trashed-1');
      }
      await db.putSetting('syncCursor', imported ? '25' : '91');
      final source = FullBackupSnapshot(
        ownerId: owner,
        createdAtUtc: created,
        tables: await db.fullBackupRows(owner),
        preferences: {
          for (final name in FullBackupSnapshot.preferenceNames)
            name: name == 'theme'
                ? (imported ? 'light' : 'dark') : null,
        },
      );
      source.validate();
      return source;
    } finally {
      await db.close();
    }
  }

  late List<int> checkpoint;
  late List<int> imported;
  late DiskRestoreRehearsal sandbox;

  setUpAll(() async {
    checkpoint = await codec.encrypt(await snapshot(false), currentPassword);
    imported = await codec.encrypt(await snapshot(true), importedPassword);
  });

  setUp(() async {
    sandbox = await DiskRestoreRehearsal.create();
  });
  tearDown(() async {
    await sandbox.disposeForTest();
  });

  Future<void> prepare() => sandbox.prepare(
    checkpointBytes: checkpoint,
    checkpointPassword: currentPassword,
    targetBytes: imported,
    targetPassword: importedPassword,
    expectedOwnerId: owner,
  );

  Future<DiskRestoreReceipt> recover({
    Future<void> Function(String stage)? crash,
    String user = owner,
    String password = currentPassword,
  }) => sandbox.coldStart().recover(
    expectedOwnerId: user,
    checkpointPassword: password,
    targetPassword: importedPassword,
    injectCrash: crash,
  );

  test('checkpoint creates actual SQLite and prefs on disposable disk',
      () async {
    await prepare();
    expect(await File(path.join(sandbox.directory.path,
        'sandbox.sqlite')).exists(), isTrue);
    expect(await File(path.join(sandbox.directory.path,
        'preferences.json')).exists(), isTrue);
    final result = await recover();
    expect(result.rollbackVerifiedOnDisk, isTrue);
    expect(result.rows['note_entries'], 2);
    expect(result.rows['pending_mutations'], greaterThan(0));
    expect(result.liveRestoreAuthorized, isFalse);
    expect(result.automaticSyncAuthorized, isFalse);
    expect(result.importedOutboxQuarantined, isTrue);
    expect((await recover()).rows, result.rows);
  });

  for (final interruption in [
    'after-sqlite-commit',
    'after-preferences-replace',
    'after-verifying-marker',
  ]) {
    test('cold start recovers persistent files after $interruption', () async {
      await prepare();
      await expectLater(sandbox.applyTargetForTest(
        expectedOwnerId: owner,
        targetPassword: importedPassword,
        injectCrash: (stage) async {
          if (stage == interruption) throw StateError('simulated process death');
        },
      ), throwsStateError);
      final report = await recover();
      expect(report.rollbackVerifiedOnDisk, isTrue);
      expect(report.rows['note_entries'], 2);
      expect(report.automaticSyncAuthorized, isFalse);
    });
  }

  for (final interruption in [
    'recovery-marked',
    'after-sqlite-rollback',
    'after-preferences-rollback',
  ]) {
    test('a second recovery resumes after $interruption', () async {
      await prepare();
      await sandbox.applyTargetForTest(
          expectedOwnerId: owner, targetPassword: importedPassword);
      await expectLater(recover(crash: (stage) async {
        if (stage == interruption) throw StateError('simulated reboot');
      }), throwsStateError);
      final report = await recover();
      expect(report.rollbackVerifiedOnDisk, isTrue);
      expect(report.rows['note_entries'], 2);
      expect((await recover()).automaticSyncAuthorized, isFalse);
    });
  }

  test('mismatched owner and wrong password never overwrite checkpoint',
      () async {
    await prepare();
    final file = File(path.join(sandbox.directory.path, 'checkpoint.snb'));
    final original = await file.readAsBytes();
    await expectLater(recover(user: 'foreign-user'), throwsFormatException);
    await expectLater(recover(password: 'wrong-password-long'),
        throwsFormatException);
    expect(await file.readAsBytes(), original);
    expect((await recover()).rollbackVerifiedOnDisk, isTrue);
  });

  test('mutated imported bytes fail closed without changing checkpoint',
      () async {
    await prepare();
    final file = File(path.join(sandbox.directory.path, 'target.snb'));
    final original = await file.readAsBytes();
    await file.writeAsBytes([1, 2, 3], flush: true);
    await expectLater(recover(), throwsFormatException);
    await file.writeAsBytes(original, flush: true);
    expect((await recover()).rollbackVerifiedOnDisk, isTrue);
  });

  test('corrupt journal is rejected without silently resetting files',
      () async {
    await prepare();
    final journal = File(path.join(
        sandbox.directory.path, 'journal', 'recovery-000.json'));
    await journal.writeAsString('{"not":"a valid journal"}', flush: true);
    await expectLater(recover(), throwsFormatException);
    expect(await journal.readAsString(), contains('not'));
  });

  test('never creates two sessions in one sandbox', () async {
    await prepare();
    await expectLater(prepare(), throwsStateError);
    final report = await recover();
    expect(report.rollbackVerifiedOnDisk, isTrue);
  });

  test('orphan staged preferences file cannot block cold-start compensation',
      () async {
    await prepare();
    await File(path.join(sandbox.directory.path, 'prefs-stage-orphan.tmp'))
        .writeAsString('incomplete private prefs', flush: true);
    final report = await recover();
    expect(report.rollbackVerifiedOnDisk, isTrue);
    expect(report.automaticSyncAuthorized, isFalse);
  });

  test('recovered snapshot cannot grant replay even when target was applied',
      () async {
    await prepare();
    await sandbox.applyTargetForTest(
        expectedOwnerId: owner, targetPassword: importedPassword);
    final report = await recover();
    expect(report.liveRestoreAuthorized, isFalse);
    expect(report.automaticSyncAuthorized, isFalse);
    expect(report.importedOutboxQuarantined, isTrue);
  });
}
