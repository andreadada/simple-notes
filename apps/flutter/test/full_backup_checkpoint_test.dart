import 'dart:io';

import 'package:crypto/crypto.dart' as hash;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/full_backup_checkpoint.dart';
import 'package:simple_notes/data/models.dart';

class _TruncatedStore implements FullBackupCheckpointStore {
  List<int> bytes = [];

  @override
  Future<void> writeNew(List<int> encryptedBytes) async {
    bytes = encryptedBytes.sublist(0, encryptedBytes.length ~/ 2);
  }

  @override
  Future<List<int>> readBack() async => bytes;
}

class _FailingStore implements FullBackupCheckpointStore {
  @override
  Future<void> writeNew(List<int> encryptedBytes) async =>
      throw const FileSystemException('Simulated disk full');

  @override
  Future<List<int>> readBack() async => throw StateError('unreachable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'p2-4b2b-google-owner';
  const password = 'checkpoint-test-password-long';
  final date = DateTime.utc(2026, 11, 4, 13);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppDatabase> sourceDatabase() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.bindOwner(owner);
    await db.upsertList(LocalTaskList(
        id: 'list-7', title: 'Università', createdAt: date));
    await db.upsertTask(LocalTask(
        id: 'task-7', title: 'Consegna', dueAt: null,
        completed: false, createdAt: date, listId: 'list-7'));
    await db.upsertNote(LocalNote(
        id: 'note-7', title: 'Appunti',
        body: 'private-text', createdAt: date));
    await db.upsertNote(LocalNote(
        id: 'deleted-7', title: 'Nel cestino',
        body: 'private-trash', createdAt: date));
    await db.removeNote('deleted-7');
    await db.putSetting('syncCursor', '91');
    return db;
  }

  Future<FullBackupSnapshot> capture(AppDatabase db) async {
    return const FullBackupSource().capture(
      database: db, preferences: await SharedPreferences.getInstance(),
      ownerId: owner, now: date,
    );
  }

  test('writes unique encrypted checkpoint and rereads authenticated data',
      () async {
    final db = await sourceDatabase();
    addTearDown(db.close);
    final before = await db.fullBackupRows(owner);
    final root = await Directory.systemTemp.createTemp('sn-b2-checkpoint-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileFullBackupCheckpointStore(root);
    final checkpoint = await const FullBackupCheckpointPreflight().prepare(
      current: await capture(db), expectedOwnerId: owner,
      password: password, store: store,
    );

    expect(await store.file.exists(), isTrue);
    expect(checkpoint.bytes, greaterThan(0));
    expect(checkpoint.checksumSha256,
        hash.sha256.convert(await store.readBack()).toString());
    expect(checkpoint.rowCounts['note_entries'], 2);
    expect(checkpoint.rowCounts['pending_mutations'],
        before['pending_mutations']!.length);
    expect(checkpoint.liveRestoreAuthorized, isFalse);
    expect(checkpoint.automaticSyncAuthorized, isFalse);
    final verified = await const FullBackupCodec().inspect(
      await store.readBack(), password: password, expectedOwnerId: owner,
    );
    expect(verified.preferences.keys.toSet(),
        FullBackupSnapshot.preferenceNames);
    expect(verified.tables, before);
    expect(await db.fullBackupRows(owner), before);
    expect(root.listSync().whereType<File>().length, 1);
  });

  test('existing checkpoint cannot be overwritten', () async {
    final db = await sourceDatabase();
    addTearDown(db.close);
    final root = await Directory.systemTemp.createTemp('sn-b2-checkpoint-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileFullBackupCheckpointStore(root);
    final original = await capture(db);
    final service = const FullBackupCheckpointPreflight();
    await service.prepare(current: original, expectedOwnerId: owner,
        password: password, store: store);
    final preserved = await store.readBack();
    await expectLater(service.prepare(
        current: original, expectedOwnerId: owner,
        password: password, store: store), throwsStateError);
    expect(await store.readBack(), preserved);
  });

  test('truncated checkpoint refuses preflight and never changes source',
      () async {
    final db = await sourceDatabase();
    addTearDown(db.close);
    final before = await db.fullBackupRows(owner);
    await expectLater(const FullBackupCheckpointPreflight().prepare(
      current: await capture(db), expectedOwnerId: owner,
      password: password, store: _TruncatedStore(),
    ), throwsFormatException);
    expect(await db.fullBackupRows(owner), before);
  });

  test('disk failure and wrong owner cannot produce a success receipt',
      () async {
    final db = await sourceDatabase();
    addTearDown(db.close);
    final before = await db.fullBackupRows(owner);
    final current = await capture(db);
    final service = const FullBackupCheckpointPreflight();

    await expectLater(service.prepare(
      current: current, expectedOwnerId: owner,
      password: password, store: _FailingStore(),
    ), throwsA(isA<FileSystemException>()));
    await expectLater(service.prepare(
      current: current, expectedOwnerId: 'not-this-account',
      password: password, store: _TruncatedStore(),
    ), throwsFormatException);
    expect(await db.fullBackupRows(owner), before);
  });
}
