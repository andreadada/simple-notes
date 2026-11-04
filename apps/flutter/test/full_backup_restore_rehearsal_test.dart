import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_restore_rehearsal.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = 'p2-4b2a-google-owner';
  const password = 'a-long-backup-test-password';
  final date = DateTime.utc(2026, 11, 4, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppDatabase> sourceDatabase() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.bindOwner(owner);
    await db.upsertList(LocalTaskList(
        id: 'list-1', title: 'Lavoro', createdAt: date));
    await db.upsertTask(LocalTask(
        id: 'task-1', title: 'Consegna', createdAt: date,
        listId: 'list-1'));
    await db.upsertNote(LocalNote(
        id: 'note-1', title: 'Da conservare',
        body: 'Contenuto privato', createdAt: date));
    await db.upsertNote(LocalNote(
        id: 'note-deleted', title: 'Cestino',
        body: 'Riga eliminata', createdAt: date));
    await db.removeNote('note-deleted');
    await db.putSetting('syncCursor', '91');
    await db.putSetting('lastSyncSuccessUtc',
        '2026-11-03T02:24:58.000Z');
    return db;
  }

  Future<List<int>> backup(AppDatabase db) async {
    final preferences = await SharedPreferences.getInstance();
    final source = await const FullBackupSource().capture(
      database: db, preferences: preferences,
      ownerId: owner, now: date,
    );
    return const FullBackupCodec().encrypt(source, password);
  }

  test('rehearsal restores all raw tables in disposable SQLite', () async {
    final original = await sourceDatabase();
    addTearDown(original.close);
    final before = await original.fullBackupRows(owner);
    final bytes = await backup(original);

    final report = await const FullBackupRestoreRehearsal().verify(
      encryptedBytes: bytes, password: password,
      expectedOwnerId: owner,
    );
    expect(report.rowsByTable['task_entries'], 1);
    expect(report.rowsByTable['task_list_entries'], 1);
    expect(report.rowsByTable['note_entries'], 2);
    expect(report.outboxCount, before['pending_mutations']!.length);
    expect(report.automaticSyncAuthorized, isFalse);
    expect(await original.fullBackupRows(owner), before);
  });

  test('fault after a table aborts atomically, retry uses fresh sandbox',
      () async {
    final original = await sourceDatabase();
    addTearDown(original.close);
    final before = await original.fullBackupRows(owner);
    final bytes = await backup(original);
    final verifier = const FullBackupRestoreRehearsal();

    await expectLater(verifier.verify(
      encryptedBytes: bytes, password: password, expectedOwnerId: owner,
      faultAfterTable: (table) async {
        if (table == 'note_entries') throw StateError('Injected failure');
      },
    ), throwsStateError);
    expect(await original.fullBackupRows(owner), before);
    final retried = await verifier.verify(
      encryptedBytes: bytes, password: password,
      expectedOwnerId: owner,
    );
    expect(retried.rowsByTable['note_entries'], 2);
  });

  test('incorrect account or password fails without touching the source',
      () async {
    final original = await sourceDatabase();
    addTearDown(original.close);
    final before = await original.fullBackupRows(owner);
    final bytes = await backup(original);

    await expectLater(const FullBackupRestoreRehearsal().verify(
      encryptedBytes: bytes, password: password,
      expectedOwnerId: 'different-google-owner',
    ), throwsFormatException);
    await expectLater(const FullBackupRestoreRehearsal().verify(
      encryptedBytes: bytes, password: 'invalid-password-for-backup',
      expectedOwnerId: owner,
    ), throwsFormatException);
    expect(await original.fullBackupRows(owner), before);
  });

  test('SQLite rejects invalid not-null data in sandbox, not in profile',
      () async {
    final original = await sourceDatabase();
    addTearDown(original.close);
    final before = await original.fullBackupRows(owner);
    final captured = await const FullBackupSource().capture(
      database: original,
      preferences: await SharedPreferences.getInstance(),
      ownerId: owner, now: date,
    );
    final modified = jsonDecode(jsonEncode(captured.toJson()))
        as Map<String, dynamic>;
    final table = (modified['tables'] as Map<String, dynamic>)['note_entries']
        as List<dynamic>;
    (table.first as Map<String, dynamic>)['title'] = null;
    final malformed = FullBackupSnapshot.fromJson(modified);
    final bytes = await const FullBackupCodec().encrypt(malformed, password);

    await expectLater(const FullBackupRestoreRehearsal().verify(
      encryptedBytes: bytes, password: password,
      expectedOwnerId: owner,
    ), throwsA(isA<Exception>()));
    expect(await original.fullBackupRows(owner), before);
  });
}
