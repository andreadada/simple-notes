import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/reconciliation_worksheet.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'worksheet-test-owner';
  const privateTitle = 'PRIVATE-WORKSHEET-TITLE';
  final stamp = DateTime.utc(2026, 11, 4, 20);

  Future<FullBackupSnapshot> archive({
    String user = owner,
    String title = privateTitle,
    bool clean = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(user);
      await db.upsertNote(LocalNote(
        id: 'note-one', title: title,
        body: 'PRIVATE-WORKSHEET-BODY', createdAt: stamp,
      ));
      final originalRows = await db.fullBackupRows(user);
      final rows = <String, List<Map<String, Object?>>>{
        for (final entry in originalRows.entries)
          entry.key: [
            for (final row in entry.value) {...row},
          ],
      };
      if (clean) {
        rows['pending_mutations'] = <Map<String, Object?>>[];
        for (final row in rows['note_entries']!) {
          row['remote_version'] = 5;
        }
      }
      final snapshot = FullBackupSnapshot(
        ownerId: user, createdAtUtc: stamp, tables: rows,
        preferences: {
          for (final key in FullBackupSnapshot.preferenceNames) key: null,
        },
      );
      snapshot.validate();
      return snapshot;
    } finally {
      await db.close();
    }
  }

  RestoreServerInventory inventory({
    bool includeNote = true,
    bool cloudOnly = false,
    int version = 5,
  }) => RestoreServerInventory(12, {
    if (includeNote)
      'note:note-one': RestoreInventoryRevision(
        version: version, deleted: false, changeId: 10,
      ),
    if (cloudOnly)
      'note:cloud-only': const RestoreInventoryRevision(
        version: 2, deleted: false, changeId: 11,
      ),
  });

  test('no conflict produces empty worksheet but never a restore permit',
      () async {
    final same = await archive(clean: true);
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: same, imported: same, cloud: inventory(),
    );
    expect(sheet.items, isEmpty);
    expect(sheet.pendingCount, 0);
    expect(sheet.canRestoreLive, isFalse);
    expect(sheet.canWriteCloud, isFalse);
    expect(sheet.canReplayImportedOutbox, isFalse);
    expect(sheet.canResumeAutoSync, isFalse);
    expect(sheet.isExecutable, isFalse);
    expect(sheet.isBoundTo(
      current: same, imported: same, cloud: inventory(),
    ), isTrue);
  });

  test('per-item choice is immutable and cannot authorize any write',
      () async {
    final current = await archive();
    final backup = await archive(title: 'OLDER-BACKUP-TITLE');
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: current, imported: backup, cloud: inventory(),
    );
    expect(sheet.items.length, 1);
    final item = sheet.items.single;
    expect(item.kind, 'Nota');
    expect(item.warnings, contains('Modifica locale in attesa'));
    expect(item.warnings, contains('Modifica del backup in attesa'));
    expect(item.warnings, contains('Contenuti dispositivo e backup diversi'));

    expect(item.title, privateTitle);
    expect(item.opaqueKey, hasLength(64));
    expect(item.opaqueKey, isNot(contains('note-one')));
    expect(item.availableChoices,
        contains(DraftConflictChoice.preserveDevice));
    expect(item.availableChoices,
        contains(DraftConflictChoice.preserveBackup));
    expect(item.availableChoices,
        contains(DraftConflictChoice.preserveCloud));

    final changed = sheet.choose(
      item.opaqueKey, DraftConflictChoice.preserveBackup,
    );
    expect(sheet.items.single.choice, DraftConflictChoice.undecided);
    expect(changed.items.single.choice, DraftConflictChoice.preserveBackup);
    expect(changed.pendingCount, 0);
    expect(changed.canRestoreLive, isFalse);
    expect(changed.canWriteCloud, isFalse);
    expect(changed.canReplayImportedOutbox, isFalse);
    expect(changed.canResumeAutoSync, isFalse);
    expect(changed.isExecutable, isFalse);
    expect(changed.summary, isNot(contains(privateTitle)));
    expect(changed.summary, isNot(contains('note-one')));
    expect(changed.summary, isNot(contains(owner)));
  });

  test('cloud-only record forbids non-existent device/backup choices',
      () async {
    final same = await archive(clean: true);
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: same, imported: same,
      cloud: inventory(cloudOnly: true),
    );
    expect(sheet.items.length, 1);
    final row = sheet.items.single;
    expect(row.title, '(nome non disponibile)');
    expect(row.onDevice, isFalse);
    expect(row.inBackup, isFalse);
    expect(row.observedInCloud, isTrue);
    expect(() => sheet.choose(
      row.opaqueKey, DraftConflictChoice.preserveBackup,
    ), throwsFormatException);
    expect(() => sheet.choose(
      row.opaqueKey, DraftConflictChoice.preserveDevice,
    ), throwsFormatException);
    final selected = sheet.choose(
      row.opaqueKey, DraftConflictChoice.preserveCloud,
    );
    expect(selected.isExecutable, isFalse);
  });

  test('unknown item token and foreign owner must fail closed', () async {
    final current = await archive();
    final backup = await archive(title: 'Backup note');
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: current, imported: backup, cloud: inventory(),
    );
    expect(() => sheet.choose(
      'forged-item-id', DraftConflictChoice.preserveCloud,
    ), throwsFormatException);
    final foreign = await archive(user: 'foreign-google-owner');
    expect(() => const ReconciliationWorksheetBuilder().preview(
      current: current, imported: foreign, cloud: inventory(),
    ), throwsFormatException);
  });

  test('changed source invalidates all selections without applying them',
      () async {
    final current = await archive(clean: true);
    final old = await archive(title: 'Older note', clean: true);
    final sheet = const ReconciliationWorksheetBuilder().preview(
      current: current, imported: old, cloud: inventory(),
    );
    expect(sheet.isBoundTo(
      current: current, imported: old, cloud: inventory(),
    ), isTrue);
    final changed = await archive(title: 'Changed after review', clean: true);
    expect(sheet.isBoundTo(
      current: changed, imported: old, cloud: inventory(),
    ), isFalse);
    expect(sheet.isBoundTo(
      current: current, imported: old, cloud: inventory(version: 8),
    ), isFalse);
  });

  test('more than 500 entities fails closed, never partial review',
      () async {
    final same = await archive(clean: true);
    final huge = RestoreServerInventory(12, {
      for (var i = 0; i < 501; i++)
        'note:cloud-item-$i': const RestoreInventoryRevision(
          version: 2, deleted: false, changeId: 3,
        ),
    });
    expect(() => const ReconciliationWorksheetBuilder().preview(
      current: same, imported: same, cloud: huge,
    ), throwsFormatException);
  });

  test('worksheet construction never modifies supplied source snapshots',
      () async {
    final current = await archive();
    final backup = await archive(title: 'Old note');
    final remote = inventory();
    final beforeCurrent = current.toJson().toString();
    final beforeBackup = backup.toJson().toString();
    final beforeRemote = Map.of(remote.revisions);
    const ReconciliationWorksheetBuilder().preview(
      current: current, imported: backup, cloud: remote,
    );
    expect(current.toJson().toString(), beforeCurrent);
    expect(backup.toJson().toString(), beforeBackup);
    expect(remote.revisions, beforeRemote);
  });
}
