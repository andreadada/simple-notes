import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_sandbox_orchestrator.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'p2u-test-owner';
  const checkpointPassword = 'checkpoint-passphrase-2026';
  const targetPassword = 'imported-passphrase-2026';
  final stamp = DateTime.utc(2026, 11, 6, 15);
  const codec = FullBackupCodec();

  Future<FullBackupSnapshot> snapshot({required bool target}) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(owner);
      await db.upsertNote(LocalNote(
        id: 'note-one',
        title: target ? 'PRIVATE-IMPORTED-NOTE' : 'PRIVATE-CURRENT-NOTE',
        body: 'PRIVATE-BODY-CONTENT',
        createdAt: stamp,
      ));
      await db.putSetting('syncCursor', target ? '25' : '91');
      final snap = FullBackupSnapshot(
        ownerId: owner,
        createdAtUtc: stamp,
        tables: await db.fullBackupRows(owner),
        preferences: {
          for (final name in FullBackupSnapshot.preferenceNames)
            name: name == 'theme' ? (target ? 'light' : 'dark') : null,
        },
      );
      snap.validate();
      return snap;
    } finally {
      await db.close();
    }
  }

  late List<int> checkpointBytes;
  late List<int> targetBytes;
  late SandboxRestoreOrchestrator sandbox;

  setUpAll(() async {
    checkpointBytes = await codec.encrypt(
      await snapshot(target: false), checkpointPassword,
    );
    targetBytes = await codec.encrypt(
      await snapshot(target: true), targetPassword,
    );
  });

  setUp(() async {
    sandbox = await SandboxRestoreOrchestrator.create();
  });

  tearDown(() async {
    await sandbox.disposeForTest();
  });

  SandboxRestoreConsent consent({
    String user = owner,
    List<int>? current,
    List<int>? imported,
    String phrase = SandboxRestoreConsent.confirmationPhrase,
    bool confirmsReplacement = true,
    bool confirmsQuarantine = true,
  }) => SandboxRestoreConsent.confirm(
    ownerId: user,
    checkpointBytes: current ?? checkpointBytes,
    targetBytes: imported ?? targetBytes,
    typedConfirmation: phrase,
    understandsLocalReplacement: confirmsReplacement,
    understandsImportedOutboxQuarantine: confirmsQuarantine,
  );

  Future<SandboxRestoreOutcome> run({
    SandboxRestoreConsent? approval,
    String user = owner,
    String currentPassword = checkpointPassword,
    List<int>? current,
    List<int>? imported,
    Future<void> Function(String stage)? crash,
  }) => sandbox.run(
    expectedOwnerId: user,
    checkpointBytes: current ?? checkpointBytes,
    checkpointPassword: currentPassword,
    targetBytes: imported ?? targetBytes,
    targetPassword: targetPassword,
    consent: approval,
    injectCrash: crash,
  );

  Future<void> expectCheckpointStillInstalled() async {
    final sqlite = File(path.join(
      sandbox.temporaryDirectoryForTest.path, 'sandbox.sqlite',
    ));
    final db = AppDatabase(NativeDatabase(sqlite));
    try {
      final rows = await db.fullBackupRows(owner);
      expect(rows['note_entries']!.single['title'], 'PRIVATE-CURRENT-NOTE');
      expect(rows['pending_mutations']!.length, greaterThan(0));
      final cursor = rows['sync_settings']!
          .where((row) => row['key'] == 'syncCursor').single['value'];
      expect(cursor, '91');
    } finally {
      await db.close();
    }
    final file = File(path.join(
      sandbox.temporaryDirectoryForTest.path, 'preferences.json',
    ));
    final prefs = jsonDecode(await file.readAsString())
        as Map<String, dynamic>;
    expect(prefs['theme'], 'dark');
  }

  test('missing consent cannot create a journal, SQLite or prefs', () async {
    await expectLater(run(), throwsFormatException);
    expect(await sandbox.temporaryDirectoryForTest.list().toList(), isEmpty);
  });

  test('explicit phrase and both warnings are required', () {
    for (final args in [
      (phrase: 'RIPRISTINA', replace: true, quarantine: true),
      (phrase: SandboxRestoreConsent.confirmationPhrase,
        replace: false, quarantine: true),
      (phrase: SandboxRestoreConsent.confirmationPhrase,
        replace: true, quarantine: false),
    ]) {
      expect(
        () => consent(
          phrase: args.phrase,
          confirmsReplacement: args.replace,
          confirmsQuarantine: args.quarantine,
        ),
        throwsFormatException,
      );
    }
  });

  test('verified rollback is on disposable disk and never grants sync',
      () async {
    final approval = consent();
    expect(approval.canRestoreLive, isFalse);
    expect(approval.canWriteCloud, isFalse);
    expect(approval.canReplayImportedOutbox, isFalse);
    expect(approval.canResumeAutoSync, isFalse);

    final result = await run(approval: approval);
    expect(result.sandboxRollbackVerified, isTrue);
    expect(result.installedProfileChanged, isFalse);
    expect(result.importedOutboxQuarantined, isTrue);
    expect(result.canRestoreLive, isFalse);
    expect(result.canWriteCloud, isFalse);
    expect(result.canReplayImportedOutbox, isFalse);
    expect(result.canResumeAutoSync, isFalse);
    expect(result.rowCounts['note_entries'], 1);
    await expectCheckpointStillInstalled();

    final journal = Directory(path.join(
      sandbox.temporaryDirectoryForTest.path, 'journal',
    ));
    expect(await journal.exists(), isTrue);
    expect(await journal.list().length, greaterThanOrEqualTo(4));
  });

  test('caller-owned ciphertext buffers cannot change an in-flight run',
      () async {
    final borrowedCurrent = [...checkpointBytes];
    final borrowedTarget = [...targetBytes];
    final approval = consent(
      current: borrowedCurrent, imported: borrowedTarget,
    );
    final pending = run(
      approval: approval,
      current: borrowedCurrent,
      imported: borrowedTarget,
    );
    // This happens after run begins but before its asynchronous preflight
    // completes. The private, approved copies must remain intact.
    borrowedCurrent[borrowedCurrent.length - 1] ^= 1;
    borrowedTarget[borrowedTarget.length - 1] ^= 1;
    final report = await pending;
    expect(report.sandboxRollbackVerified, isTrue);
    expect(report.canResumeAutoSync, isFalse);
    await expectCheckpointStillInstalled();
  });

  test('consent is one-shot and cannot be replayed', () async {
    final approval = consent();
    await run(approval: approval);
    await expectLater(run(approval: approval), throwsFormatException);
    await expectCheckpointStillInstalled();
  });

  test('consent is bound to owner and exact encrypted bytes', () async {
    final owned = consent();
    await expectLater(run(
      user: 'other-account', approval: owned,
    ), throwsFormatException);
    expect(await sandbox.temporaryDirectoryForTest.list().toList(), isEmpty);

    final changed = [...targetBytes];
    changed[changed.length - 1] ^= 1;
    await expectLater(run(
      approval: owned, imported: changed,
    ), throwsFormatException);
    expect(await sandbox.temporaryDirectoryForTest.list().toList(), isEmpty);

    final report = await run(approval: owned);
    expect(report.sandboxRollbackVerified, isTrue);
  });

  test('failed cryptographic preflight burns consent and does not write',
      () async {
    final approval = consent();
    await expectLater(run(
      approval: approval,
      currentPassword: 'intentionally-wrong-pass',
    ), throwsFormatException);
    expect(await sandbox.temporaryDirectoryForTest.list().toList(), isEmpty);
    await expectLater(run(approval: approval), throwsFormatException);
  });

  for (final step in [
    'after-sqlite-commit',
    'after-preferences-replace',
    'after-verifying-marker',
  ]) {
    test('new instance compensates simulated crash at $step', () async {
      await expectLater(run(
        approval: consent(),
        crash: (event) async {
          if (event == step) throw StateError('simulated crash');
        },
      ), throwsStateError);

      final newProcess = sandbox.coldStartForTest();
      final receipt = await newProcess.recoverAfterColdStart(
        expectedOwnerId: owner,
        checkpointPassword: checkpointPassword,
        targetPassword: targetPassword,
      );
      expect(receipt.sandboxRollbackVerified, isTrue);
      expect(receipt.canReplayImportedOutbox, isFalse);
      expect(receipt.canResumeAutoSync, isFalse);
      await expectCheckpointStillInstalled();
    });
  }

  test('repeated crash during recovery remains fail-closed and resumable',
      () async {
    await expectLater(run(
      approval: consent(),
      crash: (event) async {
        if (event == 'after-sqlite-commit') throw StateError('crash');
      },
    ), throwsStateError);

    await expectLater(sandbox.coldStartForTest().recoverAfterColdStart(
      expectedOwnerId: owner,
      checkpointPassword: checkpointPassword,
      targetPassword: targetPassword,
      injectCrash: (event) async {
        if (event == 'after-sqlite-rollback') {
          throw StateError('second crash');
        }
      },
    ), throwsStateError);

    final result = await sandbox.coldStartForTest().recoverAfterColdStart(
      expectedOwnerId: owner,
      checkpointPassword: checkpointPassword,
      targetPassword: targetPassword,
    );
    expect(result.sandboxRollbackVerified, isTrue);
    expect(result.canResumeAutoSync, isFalse);
    await expectCheckpointStillInstalled();
  });

  test('foreign owner cannot initiate or recover another sandbox', () async {
    await expectLater(run(
      approval: consent(user: 'other-account'),
      user: 'other-account',
    ), throwsFormatException);
    expect(await sandbox.temporaryDirectoryForTest.list().toList(), isEmpty);
    await run(approval: consent());
    await expectLater(sandbox.coldStartForTest().recoverAfterColdStart(
      expectedOwnerId: 'other-account',
      checkpointPassword: checkpointPassword,
      targetPassword: targetPassword,
    ), throwsFormatException);
    await expectCheckpointStillInstalled();
  });
}
