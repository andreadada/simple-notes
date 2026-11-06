import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/reconciliation_preflight_client.dart';
import 'package:simple_notes/data/reconciliation_review_receipt.dart';
import 'package:simple_notes/data/reconciliation_worksheet.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  const owner = 'PRIVATE-OWNER';
  const privateTitle = 'PRIVATE-TITLE';
  const entity = 'note:note-one';
  const planner = ReconciliationReviewReceiptBuilder();

  FullBackupSnapshot snapshot({
    String account = owner,
    String title = privateTitle,
    bool withOutbox = false,
  }) {
    final tables = <String, List<Map<String, Object?>>>{
      for (final name in FullBackupSnapshot.columns.keys)
        name: <Map<String, Object?>>[],
    };
    tables['sync_settings'] = [
      {'key': 'boundOwnerId', 'value': account},
      {'key': 'syncCursor', 'value': '12'},
    ];
    tables['note_entries'] = [
      {
        for (final column in FullBackupSnapshot.columns['note_entries']!)
          column: null,
        'id': 'note-one',
        'title': title,
        'body': 'PRIVATE-BODY',
        'created_at': '2026-11-06T12:00:00.000Z',
        'remote_version': 4,
      },
    ];
    if (withOutbox) {
      tables['pending_mutations'] = [
        {
          'operation_id': 'pending-operation',
          'entity_type': 'note',
          'entity_id': 'note-one',
          'action': 'upsert',
          'payload': '{}',
          'created_at': '2026-11-06T12:00:00.000Z',
        },
      ];
    }
    final result = FullBackupSnapshot(
      ownerId: account,
      createdAtUtc: DateTime.utc(2026, 11, 6),
      tables: tables,
      preferences: {
        for (final name in FullBackupSnapshot.preferenceNames) name: null,
      },
    );
    result.validate();
    return result;
  }

  RestoreServerInventory inventory({int cursor = 12, int version = 4}) =>
      RestoreServerInventory(cursor, {
        entity: RestoreInventoryRevision(
          version: version, deleted: false, changeId: 10,
        ),
      });

  ReconciliationPreflightResult check({
    int cursor = 12,
    int entities = 1,
    int mismatches = 0,
    bool consistent = true,
  }) => ReconciliationPreflightResult(
    observedCursor: cursor,
    cursorMatches: cursor == 12,
    consistent: consistent,
    checkedEntities: entities,
    mismatchedEntities: mismatches,
  );

  test('review requires both explicit decisions and current cloud preflight',
      () {
    final device = snapshot();
    final backup = snapshot(title: 'Older version', withOutbox: true);
    final cloud = inventory();
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: device, imported: backup, cloud: cloud,
    );
    expect(sheet.items, hasLength(1));

    final noCheck = planner.inspect(
      expectedOwnerId: owner, current: device, imported: backup,
      cloud: cloud, worksheet: sheet,
    );
    expect(noCheck.reviewComplete, isFalse);
    expect(noCheck.unresolvedDecisions, 1);
    expect(noCheck.importedPendingOperations, 1);
    expect(noCheck.importedOutboxQuarantined, isTrue);

    final selected = sheet.choose(
      sheet.items.single.opaqueKey, DraftConflictChoice.preserveDevice,
    );
    final complete = planner.inspect(
      expectedOwnerId: owner, current: device, imported: backup,
      cloud: cloud, worksheet: selected, preflight: check(),
    );
    expect(complete.reviewComplete, isTrue);
    expect(complete.reviewedDecisions, 1);
    expect(complete.unresolvedDecisions, 0);
    expect(complete.canRestoreLive, isFalse);
    expect(complete.canWriteCloud, isFalse);
    expect(complete.canApplyDecisions, isFalse);
    expect(complete.canReplayImportedOutbox, isFalse);
    expect(complete.canResumeAutoSync, isFalse);
    for (final secret in [
      owner, privateTitle, 'PRIVATE-BODY', 'note-one', 'pending-operation',
    ]) {
      expect(complete.summary, isNot(contains(secret)));
    }
    expect(complete.summary, contains('Nessun ripristino'));
  });

  test('stale or partial cloud check fails closed', () {
    final device = snapshot();
    final backup = snapshot(title: 'Backup');
    final cloud = inventory();
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: device, imported: backup, cloud: cloud,
    );
    final reviewed = sheet.choose(
      sheet.items.single.opaqueKey, DraftConflictChoice.preserveBackup,
    );
    for (final checkResult in [
      check(cursor: 13),
      check(entities: 0),
      check(mismatches: 1, consistent: false),
    ]) {
      final report = planner.inspect(
        expectedOwnerId: owner, current: device, imported: backup,
        cloud: cloud, worksheet: reviewed, preflight: checkResult,
      );
      expect(report.reviewComplete, isFalse);
      expect(report.canApplyDecisions, isFalse);
    }
  });

  test('new local or cloud source invalidates an old completed review', () {
    final device = snapshot();
    final backup = snapshot(title: 'Backup');
    final cloud = inventory();
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: device, imported: backup, cloud: cloud,
    );
    final reviewed = sheet.choose(
      sheet.items.single.opaqueKey, DraftConflictChoice.preserveCloud,
    );
    for (final scenario in [
      (snapshot(title: 'New local'), cloud),
      (device, inventory(version: 5)),
      (device, inventory(cursor: 13)),
    ]) {
      final result = planner.inspect(
        expectedOwnerId: owner,
        current: scenario.$1,
        imported: backup,
        cloud: scenario.$2,
        worksheet: reviewed,
        preflight: check(),
      );
      expect(result.sourcesMatch, isFalse);
      expect(result.reviewComplete, isFalse);
      expect(result.reviewedDecisions, 0);
    }
  });

  test('wrong owner and malformed source are rejected before review', () {
    final device = snapshot();
    final backup = snapshot(title: 'Backup');
    final cloud = inventory();
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: device, imported: backup, cloud: cloud,
    );
    expect(() => planner.inspect(
      expectedOwnerId: 'foreign-owner',
      current: device, imported: backup, cloud: cloud, worksheet: sheet,
    ), throwsFormatException);
    final broken = FullBackupSnapshot(
      ownerId: owner,
      createdAtUtc: DateTime.utc(2026, 11, 6),
      tables: {...device.tables, 'unknown': []},
      preferences: device.preferences,
    );
    expect(() => planner.inspect(
      expectedOwnerId: owner,
      current: broken, imported: backup, cloud: cloud, worksheet: sheet,
    ), throwsFormatException);
  });

  test('an empty and oversized cloud inventory cannot appear preflight-checked',
      () {
    final device = snapshot();
    final backup = snapshot(title: 'Backup');
    for (final cloud in [
      const RestoreServerInventory(12, {}),
      RestoreServerInventory(12, {
        for (var i = 0; i < 101; i++)
          'note:other-$i': const RestoreInventoryRevision(
            version: 4, deleted: false, changeId: 10,
          ),
      }),
    ]) {
      final sheet = const ReconciliationWorksheetBuilder().preview(
        current: device, imported: backup, cloud: cloud,
      );
      final result = planner.inspect(
        expectedOwnerId: owner,
        current: device, imported: backup, cloud: cloud,
        worksheet: sheet,
        preflight: check(entities: cloud.revisions.length),
      );
      expect(result.cloudCheckCurrent, isFalse);
      expect(result.reviewComplete, isFalse);
      expect(result.canResumeAutoSync, isFalse);
    }
  });
}
