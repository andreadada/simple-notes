import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'inventory-client-owner';
  const noteId = 'cbb07b67-df92-4be7-a953-6c61bbd45f57';
  final now = DateTime.utc(2026, 11, 4, 18);

  Future<FullBackupSnapshot> profile(String userId, String cursor) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(userId);
      await db.upsertNote(LocalNote(
          id: noteId, title: 'Never upload this',
          body: 'private-backup-content', createdAt: now));
      await db.putSetting('syncCursor', cursor);
      final snapshot = FullBackupSnapshot(
        ownerId: userId, createdAtUtc: now,
        tables: await db.fullBackupRows(userId),
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

  test('reads metadata-only inventory without posting data', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/sync/inventory');
      expect(request.headers['Authorization'], 'Bearer inventory-test-token');
      return http.Response(jsonEncode({
        'cursor': 19, 'complete': true,
        'items': [{
          'entityType': 'note', 'entityId': noteId,
          'version': 4, 'deleted': false, 'changeId': 18,
        }],
      }), 200);
    });
    addTearDown(client.close);

    final inventory = await const RestoreServerInventoryReader().inspect(
      client: client,
      apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => 'inventory-test-token',
    );
    expect(methods, ['GET']);
    expect(inventory.cursor, 19);
    expect(inventory.revisions['note:$noteId']!.version, 4);
    expect(inventory.canAuthorizeImportedSync, isFalse);

    final review = RestoreServerInventoryReview.compare(
      checkpoint: await profile(owner, '91'),
      target: await profile(owner, '25'),
      remote: inventory,
    );
    expect(review.outboxCount, 1);
    expect(review.versionConflicts, 1);
    expect(review.cursorRegressed, isTrue);
    expect(review.canReplayImportedOutbox, isFalse);
    expect(review.canRestoreLive, isFalse);
  });

  test('unknown revision does not authorize upload', () async {
    final review = RestoreServerInventoryReview.compare(
      checkpoint: await profile(owner, '91'),
      target: await profile(owner, '91'),
      remote: const RestoreServerInventory(900, {}),
    );
    expect(review.unobservedOperations, 1);
    expect(review.canReplayImportedOutbox, isFalse);
  });

  test('requires complete inventory, no payload, unique IDs and valid cursor',
      () async {
    final responses = [
      {'cursor': 2, 'complete': false, 'items': []},
      {'cursor': 2, 'complete': true, 'items': [{
        'entityType': 'note', 'entityId': noteId,
        'version': 1, 'deleted': false, 'changeId': 3,
      }]},
      {'cursor': 9, 'complete': true, 'items': [{
        'entityType': 'note', 'entityId': noteId,
        'version': 1, 'deleted': false, 'changeId': 3,
        'payload': 'should never be returned',
      }]},
      {'cursor': 9, 'complete': true, 'items': [
        {'entityType': 'note', 'entityId': noteId,
          'version': 1, 'deleted': false, 'changeId': 3},
        {'entityType': 'note', 'entityId': noteId,
          'version': 1, 'deleted': false, 'changeId': 3},
      ]},
    ];
    for (final response in responses) {
      final client = MockClient((request) async =>
          http.Response(jsonEncode(response), 200));
      try {
        await expectLater(const RestoreServerInventoryReader().inspect(
          client: client, apiBase: Uri.parse('https://sync.example'),
          accessToken: () async => 'test-token',
        ), throwsFormatException);
      } finally {
        client.close();
      }
    }
  });

  test('missing endpoint, insecure URL and missing credentials fail closed',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('not available', 404);
    });
    addTearDown(client.close);
    await expectLater(const RestoreServerInventoryReader().inspect(
      client: client, apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => 'token',
    ), throwsFormatException);
    expect(calls, 1);
    await expectLater(const RestoreServerInventoryReader().inspect(
      client: client, apiBase: Uri.parse('http://not-local.example'),
      accessToken: () async => 'token',
    ), throwsFormatException);
    await expectLater(const RestoreServerInventoryReader().inspect(
      client: client, apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => '',
    ), throwsFormatException);
    expect(calls, 1);
  });

  test('foreign owner cannot be reconciled locally', () async {
    expect(
      () => RestoreServerInventoryReview.compare(
        checkpoint: throwSnapshotOwner(owner),
        target: throwSnapshotOwner('other-owner'),
        remote: const RestoreServerInventory(0, {}),
      ),
      throwsFormatException,
    );
  });
}

FullBackupSnapshot throwSnapshotOwner(String ownerId) {
  final empty = {
    for (final table in FullBackupSnapshot.columns.keys)
      table: <Map<String, Object?>>[],
  };
  empty['sync_settings'] = [{
    'key': 'boundOwnerId', 'value': ownerId,
  }];
  return FullBackupSnapshot(
    ownerId: ownerId, createdAtUtc: DateTime.utc(2026, 11, 4),
    tables: empty,
    preferences: {
      for (final name in FullBackupSnapshot.preferenceNames) name: null,
    },
  );
}
