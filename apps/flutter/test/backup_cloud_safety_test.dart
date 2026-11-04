import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/backup_cloud_safety.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final created = DateTime.utc(2026, 11, 4, 19);

  Future<FullBackupSnapshot> archive({
    String owner = 'google-cloud-review-owner',
    int cursor = 8,
    bool deleted = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(owner);
      await db.upsertList(LocalTaskList(
        id: 'list-one', title: 'PRIVATE-LIST', createdAt: created));
      await db.upsertTask(LocalTask(
        id: 'task-one', title: 'PRIVATE-TASK', completed: false,
        dueAt: null, listId: 'list-one', createdAt: created));
      await db.upsertNote(LocalNote(
        id: 'note-one', title: 'PRIVATE-NOTE',
        body: 'PRIVATE-NOTE-BODY', createdAt: created));
      if (deleted) await db.removeNote('note-one');
      await db.putSetting('syncCursor', cursor.toString());
      final snapshot = FullBackupSnapshot(
        ownerId: owner, createdAtUtc: created,
        tables: await db.fullBackupRows(owner),
        preferences: {
          for (final name in FullBackupSnapshot.preferenceNames) name: null,
        },
      );
      snapshot.validate();
      return snapshot;
    } finally {
      await db.close();
    }
  }

  RestoreServerInventory inventory({
    int cursor = 12,
    int noteVersion = 5,
    bool noteDeleted = false,
    bool unknownNote = false,
  }) => RestoreServerInventory(cursor, {
    'task:task-one': const RestoreInventoryRevision(
      version: 0, deleted: false, changeId: 1),
    'list:list-one': const RestoreInventoryRevision(
      version: 0, deleted: false, changeId: 2),
    if (!unknownNote)
      'note:note-one': RestoreInventoryRevision(
        version: noteVersion, deleted: noteDeleted, changeId: 3),
    'note:cloud-only': const RestoreInventoryRevision(
      version: 2, deleted: false, changeId: 4),
  });

  test('counts remote revisions, missing ledger records, and remote-only items',
      () async {
    final current = await archive(cursor: 10);
    final backup = await archive(cursor: 8);
    final result = const BackupCloudSafetyReviewer().inspect(
      current: current, backup: backup, remote: inventory());
    expect(result.entitiesInBackup, 3);
    expect(result.entitiesNotObservedRemotely, 0);
    expect(result.remoteOnlyEntities, 1);
    expect(result.remoteCursor, 12);
    expect(result.cloudCursorAheadOfBackup, isTrue);
    expect(result.outboxVersionConflicts, greaterThanOrEqualTo(0));
    expect(result.unobservedOutboxOperations,
        greaterThanOrEqualTo(0));
    expect(result.requiresManualReconciliation, isTrue);
    expect(result.canRestoreLive, isFalse);
    expect(result.canApplyImportedOperations, isFalse);
    expect(result.canResumeAutoSync, isFalse);
    expect(result.canTrustImportedCursor, isFalse);
  });

  test('remote tombstone and unobserved entities are not treated as safe',
      () async {
    final current = await archive(cursor: 12);
    final backup = await archive(cursor: 8, deleted: true);
    final mismatched = const BackupCloudSafetyReviewer().inspect(
      current: current, backup: backup,
      remote: inventory(noteDeleted: false),
    );
    expect(mismatched.remoteDeletionMismatches, 1);
    expect(mismatched.canRestoreLive, isFalse);

    final unknown = const BackupCloudSafetyReviewer().inspect(
      current: current, backup: backup,
      remote: inventory(unknownNote: true),
    );
    expect(unknown.entitiesNotObservedRemotely, 1);
    expect(unknown.canApplyImportedOperations, isFalse);
  });

  test('even matching cursor and versions never authorize imported replay',
      () async {
    final same = await archive(cursor: 12);
    final result = const BackupCloudSafetyReviewer().inspect(
      current: same, backup: same,
      remote: inventory(cursor: 12, noteVersion: 0),
    );
    expect(result.cloudCursorAheadOfBackup, isFalse);
    expect(result.canResumeAutoSync, isFalse);
    expect(result.requiresManualReconciliation, isTrue);
    expect(result.summary, contains('Ripristino e replay restano disabilitati.'));
  });

  test('summary contains counts but no private data or owner identifiers',
      () async {
    final current = await archive();
    final result = const BackupCloudSafetyReviewer().inspect(
      current: current, backup: current, remote: inventory(),
    );
    expect(result.summary, contains('Inventario cloud'));
    for (final secret in [
      'PRIVATE-LIST', 'PRIVATE-TASK', 'PRIVATE-NOTE',
      'PRIVATE-NOTE-BODY', 'google-cloud-review-owner',
      'task-one', 'note-one',
    ]) {
      expect(result.summary, isNot(contains(secret)));
    }
  });

  test('different backup owner rejected before inventory review',
      () async {
    final current = await archive();
    final foreign = await archive(owner: 'google-different-owner');
    expect(() => const BackupCloudSafetyReviewer().inspect(
      current: current, backup: foreign, remote: inventory(),
    ), throwsFormatException);
  });

  test('review leaves both snapshots and inventory unchanged', () async {
    final current = await archive();
    final backup = await archive(cursor: 5);
    final remote = inventory();
    final currentBefore = current.toJson().toString();
    final backupBefore = backup.toJson().toString();
    final remoteBefore = Map.of(remote.revisions);
    const BackupCloudSafetyReviewer().inspect(
      current: current, backup: backup, remote: remote,
    );
    expect(current.toJson().toString(), currentBefore);
    expect(backup.toJson().toString(), backupBefore);
    expect(remote.revisions, remoteBefore);
  });
}
