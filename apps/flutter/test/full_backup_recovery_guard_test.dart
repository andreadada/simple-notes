import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_recovery_guard.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'recovery-test-google-owner';
  const checkpointPassword = 'recovery-current-checkpoint-long';
  const targetPassword = 'recovery-imported-archive-long';
  const codec = FullBackupCodec();
  final timestamp = DateTime.utc(2026, 11, 4, 16);

  Future<FullBackupSnapshot> snapshot(
      String ownerId, String title, String cursor) async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      await database.bindOwner(ownerId);
      await database.upsertNote(LocalNote(
          id: 'note-recovery', title: title, body: 'test-content',
          createdAt: timestamp));
      await database.putSetting('syncCursor', cursor);
      final rows = await database.fullBackupRows(ownerId);
      final value = FullBackupSnapshot(
        ownerId: ownerId, createdAtUtc: timestamp,
        tables: rows,
        preferences: {
          for (final name in FullBackupSnapshot.preferenceNames) name: null,
        },
      );
      value.validate();
      return value;
    } finally {
      await database.close();
    }
  }

  late FullBackupSnapshot current;
  late FullBackupSnapshot imported;
  late List<int> checkpointBytes;
  late List<int> targetBytes;
  late Directory folder;
  late FileRestoreJournal journal;
  late FullBackupColdStartGuard guard;

  setUpAll(() async {
    current = await snapshot(owner, 'current note', '91');
    imported = await snapshot(owner, 'old note', '25');
    checkpointBytes = await codec.encrypt(current, checkpointPassword);
    targetBytes = await codec.encrypt(imported, targetPassword);
  });

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('simple-notes-coldstart-');
    journal = FileRestoreJournal(folder);
    guard = FullBackupColdStartGuard(journal);
  });

  tearDown(() async {
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  Future<RestoreColdStartReport> prepare() => guard.prepare(
    checkpointBytes: checkpointBytes,
    checkpointPassword: checkpointPassword,
    targetBytes: targetBytes,
    targetPassword: targetPassword,
    expectedOwnerId: owner,
  );

  Future<RestoreColdStartReport> reboot({
    Future<void> Function(String phase)? injectCrash,
    List<int>? targetOverride,
    String ownerOverride = owner,
    String checkpointPassOverride = checkpointPassword,
  }) => FullBackupColdStartGuard(FileRestoreJournal(folder)).recover(
    checkpointBytes: checkpointBytes,
    checkpointPassword: checkpointPassOverride,
    targetBytes: targetOverride ?? targetBytes,
    targetPassword: targetPassword,
    expectedOwnerId: ownerOverride,
    injectCrash: injectCrash,
  );

  test('preflight quarantines imported outbox and regressed cursor', () async {
    final result = await prepare();
    expect(result.phase, RestorePhase.prepared);
    expect(result.risk!.importedOutbox, greaterThan(0));
    expect(result.risk!.savedOutbox, greaterThan(0));
    expect(result.risk!.cursorRegressedOrUnknown, isTrue);
    expect(result.risk!.importedOutboxQuarantined, isTrue);
    expect(result.risk!.importedCursorTrusted, isFalse);
    expect(result.risk!.needsRemoteReconciliation, isTrue);
    expect(result.automaticSyncAuthorized, isFalse);
    expect(result.liveRestoreAuthorized, isFalse);
    expect(folder.listSync().length, 1);
  });

  test('new process detects interrupted staging and proves rollback', () async {
    await prepare();
    await guard.simulateNext(RestorePhase.staging);
    await guard.simulateNext(RestorePhase.verifying);
    final rebooted = await reboot();
    expect(rebooted.phase, RestorePhase.rollbackVerified);
    expect(rebooted.sandboxRollbackVerified, isTrue);
    expect(rebooted.recoveryPending, isFalse);
    expect(rebooted.automaticSyncAuthorized, isFalse);
    expect((await journal.read())!.sequence, 4);
    // Idempotent on a second cold start.
    expect((await reboot()).phase, RestorePhase.rollbackVerified);
  });

  test('crash after durable recovery-required marker retries safely',
      () async {
    await prepare();
    await guard.simulateNext(RestorePhase.staging);
    await expectLater(reboot(injectCrash: (stage) async {
      if (stage == 'recovery-required') throw StateError('simulated crash');
    }), throwsStateError);
    expect((await journal.read())!.phase, RestorePhase.recoveryRequired);
    final result = await reboot();
    expect(result.phase, RestorePhase.rollbackVerified);
    expect(result.sandboxRollbackVerified, isTrue);
  });

  test('crash after rollback marker remains quarantined on restart',
      () async {
    await prepare();
    await expectLater(reboot(injectCrash: (stage) async {
      if (stage == 'rollback-verified') throw StateError('simulated restart');
    }), throwsStateError);
    expect((await reboot()).sandboxRollbackVerified, isTrue);
    expect((await reboot()).automaticSyncAuthorized, isFalse);
  });

  test('wrong owner, archive hash and password fail closed', () async {
    await prepare();
    await expectLater(reboot(ownerOverride: 'foreign-owner'),
        throwsFormatException);
    await expectLater(reboot(targetOverride: [1, 2, 3]),
        throwsFormatException);
    await expectLater(reboot(checkpointPassOverride: 'wrong-password'),
        throwsFormatException);
    expect((await journal.read())!.phase, RestorePhase.prepared);
  });

  test('partial or corrupt journal blocks startup recovery', () async {
    await prepare();
    final orphan = File(path.join(folder.path, '.recovery-001.json.tmp'));
    await orphan.writeAsString('incomplete');
    await expectLater(reboot(), throwsFormatException);
    await orphan.delete();
    final first = File(path.join(folder.path, 'recovery-000.json'));
    await first.writeAsString('{not json');
    await expectLater(reboot(), throwsFormatException);
  });

  test('missing sequence and invalid phase transition are rejected',
      () async {
    await prepare();
    await expectLater(guard.simulateNext(RestorePhase.rollbackVerified),
        throwsStateError);
    await File(path.join(folder.path, 'recovery-002.json'))
        .writeAsString('bad gap');
    await expectLater(reboot(), throwsFormatException);
  });

  test('no journal is not an authorization to replay imported data',
      () async {
    final result = await reboot();
    expect(result.phase, isNull);
    expect(result.sandboxRollbackVerified, isFalse);
    expect(result.automaticSyncAuthorized, isFalse);
    expect(result.liveRestoreAuthorized, isFalse);
  });

  test('cannot start second session over pending or finished journal',
      () async {
    await prepare();
    await expectLater(prepare(), throwsStateError);
    await reboot();
    await expectLater(prepare(), throwsStateError);
  });

  test('even same cursor and empty outbox cannot authorize cloud sync',
      () async {
    final same = FullBackupSnapshot(
      ownerId: owner,
      createdAtUtc: timestamp,
      tables: {
        for (final entry in imported.tables.entries)
          entry.key: entry.key == 'pending_mutations'
            ? <Map<String, Object?>>[]
            : entry.key == 'sync_settings'
              ? current.tables['sync_settings']! : entry.value,
      },
      preferences: imported.preferences,
    );
    final risk = RestoreReplayRisk.assess(current, same);
    expect(risk.importedOutbox, 0);
    expect(risk.cursorRegressedOrUnknown, isFalse);
    expect(risk.importedCursorTrusted, isFalse);
    expect(risk.automaticSyncAuthorized, isFalse);
    expect(risk.needsRemoteReconciliation, isTrue);
  });
}
