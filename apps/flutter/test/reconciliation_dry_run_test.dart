import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/reconciliation_dry_run.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'dryrun-owner-A';
  const secret = 'PERSONAL-BODY-NOT-FOR-REPORTS';
  final stamp = DateTime.utc(2026, 11, 4, 20);

  Future<FullBackupSnapshot> source({
    String ownerId = owner,
    String title = 'Current',
    bool extra = false,
    bool trashed = false,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      await database.bindOwner(ownerId);
      await database.upsertNote(LocalNote(
        id: 'note-main', title: title, body: secret, createdAt: stamp,
      ));
      if (extra) {
        await database.upsertNote(LocalNote(
          id: 'note-local-only', title: 'Device only',
          body: secret, createdAt: stamp,
        ));
      }
      if (trashed) {
        await database.removeNote('note-main');
      }
      await database.putSetting('syncCursor', '15');
      final snapshot = FullBackupSnapshot(
        ownerId: ownerId,
        createdAtUtc: stamp,
        tables: await database.fullBackupRows(ownerId),
        preferences: {
          for (final key in FullBackupSnapshot.preferenceNames) key: null,
        },
      );
      snapshot.validate();
      return snapshot;
    } finally {
      await database.close();
    }
  }

  FullBackupSnapshot clean(
      FullBackupSnapshot input, {int remoteVersion = 5}) {
    final tables = <String, List<Map<String, Object?>>>{
      for (final entry in input.tables.entries)
        entry.key: [
          for (final row in entry.value) {...row},
        ],
    };
    tables['pending_mutations'] = [];
    for (final row in tables['note_entries']!) {
      row['remote_version'] = remoteVersion;
    }
    final out = FullBackupSnapshot(
      ownerId: input.ownerId,
      createdAtUtc: input.createdAtUtc,
      tables: tables,
      preferences: input.preferences,
    );
    out.validate();
    return out;
  }

  RestoreServerInventory inventory({
    int cursor = 15,
    int version = 5,
    bool deleted = false,
    bool cloudOnly = false,
    bool missing = false,
  }) => RestoreServerInventory(cursor, {
    if (!missing)
      'note:note-main': RestoreInventoryRevision(
        version: version, deleted: deleted, changeId: 10),
    if (cloudOnly)
      'note:cloud-only': const RestoreInventoryRevision(
        version: 1, deleted: false, changeId: 11),
  });

  test('identical observations have zero hazards but cannot authorize writes',
      () async {
    final same = clean(await source());
    final draft = const ReconciliationDryRunPlanner().preview(
      current: same, imported: same, cloud: inventory(),
    );
    expect(draft.totalEntities, 1);
    expect(draft.entitiesNeedingReview, 0);
    expect(draft.observedEntities, 1);
    expect(draft.importedOperationCount, 0);
    expect(draft.deviceOperationCount, 0);
    expect(draft.canRestoreLive, isFalse);
    expect(draft.canWriteToCloud, isFalse);
    expect(draft.canReplayImportedOutbox, isFalse);
    expect(draft.canResumeAutoSync, isFalse);
    expect(draft.isExecutable, isFalse);
    expect(draft.requiresHumanReview, isTrue);
    expect(draft.needsFreshCloudReview, isTrue);
  });

  test('local-only + cloud-only + old backup are all flagged', () async {
    final device = clean(await source(extra: true));
    final backup = clean(await source(title: 'Older title'));
    final draft = const ReconciliationDryRunPlanner().preview(
      current: device,
      imported: backup,
      cloud: inventory(version: 10, cloudOnly: true),
    );
    expect(draft.totalEntities, 3);
    expect(draft.entitiesNeedingReview, 3);
    expect(draft.hazardCounts[ReconciliationHazard.cloudOnly], 1);
    expect(draft.hazardCounts[ReconciliationHazard.missingFromBackup], 2);
    expect(draft.hazardCounts[ReconciliationHazard.deviceBackupDifferent], 1);
    expect(draft.hazardCounts[ReconciliationHazard.cloudNewerThanBackup], 1);
    expect(draft.hazardCounts[ReconciliationHazard.cloudNewerThanDevice], 1);
    expect(draft.hazardCounts[ReconciliationHazard.cloudNotObserved], 1);
    expect(draft.canWriteToCloud, isFalse);
  });

  test('tombstone differences and version regression fail closed',
      () async {
    final device = clean(await source());
    final imported = clean(await source(trashed: true),
        remoteVersion: 8);
    final draft = const ReconciliationDryRunPlanner().preview(
      current: device, imported: imported,
      cloud: inventory(version: 5, deleted: false),
    );
    expect(draft.hazardCounts[ReconciliationHazard.backupDeletedMismatch], 1);
    expect(draft.hazardCounts[ReconciliationHazard.cloudOlderThanBackup], 1);
    expect(draft.hazardCounts[ReconciliationHazard.deviceBackupDifferent], 1);
    expect(draft.canRestoreLive, isFalse);
  });

  test('missing ledger and pending mutation must not be assumed safe',
      () async {
    final device = await source();
    final imported = await source(title: 'Older');
    final draft = const ReconciliationDryRunPlanner().preview(
      current: device, imported: imported,
      cloud: inventory(missing: true),
    );
    expect(draft.hazardCounts[ReconciliationHazard.cloudNotObserved], 1);
    expect(draft.hazardCounts[ReconciliationHazard.importedOutbox], 1);
    expect(draft.hazardCounts[ReconciliationHazard.deviceOutbox], 1);
    expect(draft.importedOperationCount, greaterThan(0));
    expect(draft.summary, isNot(contains(secret)));
    expect(draft.summary, isNot(contains(owner)));
  });

  test('all hypothetical strategies are non-executable', () async {
    final same = clean(await source());
    final planner = const ReconciliationDryRunPlanner();
    String? fingerprint;
    for (final choice in ReconciliationStrategy.values) {
      final proposal = planner.preview(
        current: same, imported: same, cloud: inventory(),
        strategy: choice,
      );
      fingerprint ??= proposal.sourceFingerprint;
      expect(proposal.sourceFingerprint, fingerprint);
      expect(proposal.strategy, choice);
      expect(proposal.canRestoreLive, isFalse);
      expect(proposal.canWriteToCloud, isFalse);
      expect(proposal.isExecutable, isFalse);
      expect(proposal.summary, isNot(contains(secret)));
    }
  });

  test('fingerprint binds all three inputs without logging their contents',
      () async {
    final original = clean(await source(title: 'A'));
    final changed = clean(await source(title: 'B'));
    final first = const ReconciliationDryRunPlanner().preview(
      current: original, imported: original, cloud: inventory(),
    );
    final second = const ReconciliationDryRunPlanner().preview(
      current: changed, imported: original, cloud: inventory(),
    );
    final third = const ReconciliationDryRunPlanner().preview(
      current: original, imported: original, cloud: inventory(version: 7),
    );
    expect(first.sourceFingerprint, hasLength(64));
    expect(first.sourceFingerprint, isNot(second.sourceFingerprint));
    expect(first.sourceFingerprint, isNot(third.sourceFingerprint));
    expect(first.summary, isNot(contains('note-main')));
    expect(first.summary, isNot(contains(secret)));
  });

  test('foreign owner, impossible cursor and malformed key are refused',
      () async {
    final device = clean(await source());
    final foreign = clean(await source(ownerId: 'foreign-owner'));
    final planner = const ReconciliationDryRunPlanner();
    expect(() => planner.preview(
      current: device, imported: foreign, cloud: inventory(),
    ), throwsFormatException);
    expect(() => planner.preview(
      current: device, imported: device,
      cloud: const RestoreServerInventory(-1, {}),
    ), throwsFormatException);
    expect(() => planner.preview(
      current: device, imported: device,
      cloud: const RestoreServerInventory(4, {
        'note:note-main': RestoreInventoryRevision(
          version: 1, deleted: false, changeId: 5),
      }),
    ), throwsFormatException);
    expect(() => planner.preview(
      current: device, imported: device,
      cloud: const RestoreServerInventory(8, {
        'unsupported:entity': RestoreInventoryRevision(
          version: 1, deleted: false, changeId: 5),
      }),
    ), throwsFormatException);
  });

  test('dry run does not mutate snapshots or remote revisions', () async {
    final device = clean(await source());
    final backup = clean(await source(title: 'Imported'));
    final cloud = inventory();
    final beforeDevice = device.toJson().toString();
    final beforeBackup = backup.toJson().toString();
    final beforeCloud = Map.of(cloud.revisions);
    const ReconciliationDryRunPlanner().preview(
      current: device, imported: backup, cloud: cloud,
    );
    expect(device.toJson().toString(), beforeDevice);
    expect(backup.toJson().toString(), beforeBackup);
    expect(cloud.revisions, beforeCloud);
  });
}
