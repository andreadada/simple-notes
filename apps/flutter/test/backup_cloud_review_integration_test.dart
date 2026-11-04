import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/backup_cloud_safety.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'contract-review-owner-A';
  const password = 'long-local-backup-password-2026';
  final created = DateTime.utc(2026, 11, 4, 19);

  Future<FullBackupSnapshot> capture(String title, String cursor) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(owner);
      await db.upsertNote(LocalNote(
        id: 'note-review',
        title: title,
        body: 'PRIVATE-RESTORE-CONTENT',
        createdAt: created,
      ));
      await db.putSetting('syncCursor', cursor);
      final snapshot = FullBackupSnapshot(
        ownerId: owner,
        createdAtUtc: created,
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

  test('encrypted backup + cloud GET inventory + safe report never posts',
      () async {
    final current = await capture('current', '91');
    final old = await capture('old private note', '25');
    final encrypted = await const FullBackupCodec().encrypt(
      old, password,
    );
    final imported = await const FullBackupCodec().inspect(
      encrypted,
      password: password,
      expectedOwnerId: owner,
    );
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/sync/inventory');
      expect(request.headers['Authorization'], 'Bearer fake-token');
      return http.Response(jsonEncode({
        'cursor': 91, 'complete': true,
        'items': [{
          'entityType': 'note',
          'entityId': 'note-review',
          'version': 10,
          'deleted': false,
          'changeId': 91,
        }],
      }), 200);
    });
    addTearDown(client.close);
    final inventory = await const RestoreServerInventoryReader().inspect(
      client: client,
      apiBase: Uri.parse('https://cloud.example.test'),
      accessToken: () async => 'fake-token',
    );
    final review = const BackupCloudSafetyReviewer().inspect(
      current: current,
      backup: imported,
      remote: inventory,
    );
    expect(methods, ['GET']);
    expect(review.entitiesInBackup, 1);
    expect(review.cloudCursorAheadOfBackup, isTrue);
    expect(review.canRestoreLive, isFalse);
    expect(review.canResumeAutoSync, isFalse);
    expect(review.canApplyImportedOperations, isFalse);
    expect(review.requiresManualReconciliation, isTrue);
    expect(review.summary, isNot(contains('PRIVATE')));
    expect(review.summary, isNot(contains('contract-review-owner-A')));
    expect(review.summary, isNot(contains('note-review')));
    expect(current.tables['note_entries']!.single['title'], 'current');
    expect(imported.tables['note_entries']!.single['title'],
        'old private note');
  });

  test('server 404 and foreign owner fail closed without writes', () async {
    final old = await capture('never synced', '25');
    final encrypted = await const FullBackupCodec().encrypt(old, password);
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response('not yet deployed', 404);
    });
    addTearDown(client.close);
    await expectLater(const RestoreServerInventoryReader().inspect(
      client: client,
      apiBase: Uri.parse('https://cloud.example.test'),
      accessToken: () async => 'fake-token',
    ), throwsFormatException);
    await expectLater(const FullBackupCodec().inspect(
      encrypted, password: password, expectedOwnerId: 'foreign-account',
    ), throwsFormatException);
  });
}
