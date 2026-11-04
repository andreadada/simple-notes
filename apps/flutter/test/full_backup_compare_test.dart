import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_compare.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final created = DateTime.utc(2026, 11, 4, 19);

  Future<FullBackupSnapshot> snapshot({
    String owner = 'google-owner-A',
    bool older = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(owner);
      await db.upsertList(LocalTaskList(
        id: 'list-1', title: 'Personal', createdAt: created,
      ));
      await db.upsertTask(LocalTask(
        id: 'task-1',
        title: older ? 'Old task' : 'Updated task',
        dueAt: null,
        completed: false,
        listId: 'list-1',
        createdAt: created,
      ));
      await db.upsertNote(LocalNote(
        id: 'note-1',
        title: older ? 'Old note' : 'Updated note',
        body: 'SECRET-NOTE-BODY-DO-NOT-SHOW',
        createdAt: created,
      ));
      if (!older) {
        await db.upsertNote(LocalNote(
          id: 'note-2',
          title: 'Only on current device',
          body: 'SECRET-LOCAL-MISSING-FROM-BACKUP',
          createdAt: created,
        ));
        await db.removeNote('note-2');
      }
      await db.putSetting('syncCursor', older ? '25' : '91');
      final value = FullBackupSnapshot(
        ownerId: owner,
        createdAtUtc: created,
        tables: await db.fullBackupRows(owner),
        preferences: {
          for (final key in FullBackupSnapshot.preferenceNames)
            key: key == 'theme' ? (older ? 'light' : 'dark') : null,
        },
      );
      value.validate();
      return value;
    } finally {
      await db.close();
    }
  }

  test('identical snapshots are unchanged but never authorize restore',
      () async {
    final current = await snapshot();
    final report = const FullBackupCompare().preview(
      current: current, backup: current,
    );
    expect(report.hasEntityDifferences, isFalse);
    expect(report.currentDataMissingFromBackup, isFalse);
    expect(report.cursorRegressedOrUnknown, isFalse);
    expect(report.sharedOperationIds,
        report.localPendingMutations);
    expect(report.canRestoreLive, isFalse);
    expect(report.canReplayImportedOutbox, isFalse);
    expect(report.automaticSyncAuthorized, isFalse);
    expect(report.needsRemoteReconciliation, isTrue);
  });

  test('older backup reports changed task and missing tombstone without text',
      () async {
    final current = await snapshot();
    final backup = await snapshot(older: true);
    final report = const FullBackupCompare().preview(
      current: current, backup: backup,
    );
    expect(report.hasEntityDifferences, isTrue);
    expect(report.currentDataMissingFromBackup, isTrue);
    expect(report.entities['task_entries']!.changedInBackup, 1);
    expect(report.entities['task_list_entries']!.unchanged, 1);
    expect(report.entities['note_entries']!.missingFromBackup, 1);
    expect(report.entities['note_entries']!.deletedInBackup, 0);
    expect(report.cursorRegressedOrUnknown, isTrue);
    expect(report.currentCursor, 91);
    expect(report.backupCursor, 25);
    expect(report.preferenceChanges, 1);
    expect(report.importedPendingMutations, greaterThan(0));
    expect(report.localPendingMutations,
        greaterThan(report.importedPendingMutations));
    expect(report.summary, contains('Attenzione'));
    expect(report.summary, isNot(contains('SECRET-NOTE-BODY')));
    expect(report.summary, isNot(contains('SECRET-LOCAL')));
    expect(report.summary, isNot(contains('google-owner')));
    expect(report.canRestoreLive, isFalse);
  });

  test('opposite comparison shows backup-only records and tombstones',
      () async {
    final current = await snapshot(older: true);
    final backup = await snapshot();
    final report = const FullBackupCompare().preview(
      current: current, backup: backup,
    );
    expect(report.entities['note_entries']!.addedInBackup, 1);
    expect(report.entities['note_entries']!.deletedInBackup, 1);
    expect(report.currentDataMissingFromBackup, isFalse);
    expect(report.cursorRegressedOrUnknown, isFalse);
    expect(report.automaticSyncAuthorized, isFalse);
  });

  test('different account is rejected before comparison', () async {
    final actual = await snapshot();
    final foreign = await snapshot(owner: 'google-owner-B');
    expect(() => const FullBackupCompare().preview(
      current: actual, backup: foreign,
    ), throwsFormatException);
  });

  test('invalid table schema and owner binding cannot be bypassed',
      () async {
    final current = await snapshot();
    final invalid = FullBackupSnapshot(
      ownerId: current.ownerId,
      createdAtUtc: current.createdAtUtc,
      tables: {
        for (final entry in current.tables.entries)
          if (entry.key != 'sync_settings') entry.key: entry.value,
      },
      preferences: current.preferences,
    );
    expect(() => const FullBackupCompare().preview(
      current: current, backup: invalid,
    ), throwsFormatException);
  });

  test('report does not mutate either supplied snapshot', () async {
    final current = await snapshot();
    final backup = await snapshot(older: true);
    final previousCurrent = current.toJson().toString();
    final previousBackup = backup.toJson().toString();
    const FullBackupCompare().preview(current: current, backup: backup);
    expect(current.toJson().toString(), previousCurrent);
    expect(backup.toJson().toString(), previousBackup);
  });
}
