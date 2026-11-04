import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/restore_cloud_preflight.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'cloud-preflight-test-owner';
  final created = DateTime.utc(2026, 11, 4, 17);

  Future<FullBackupSnapshot> profile(String ownerId, String cursor) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner(ownerId);
      await db.upsertNote(LocalNote(
          id: 'note-1', title: 'Save me', body: 'not to upload',
          createdAt: created));
      await db.putSetting('syncCursor', cursor);
      final archive = FullBackupSnapshot(
        ownerId: ownerId,
        createdAtUtc: created,
        tables: await db.fullBackupRows(ownerId),
        preferences: {
          for (final name in FullBackupSnapshot.preferenceNames) name: null,
        },
      );
      archive.validate();
      return archive;
    } finally {
      await db.close();
    }
  }

  test('read-only client follows pages, never POSTs or exposes token', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.url.path, '/api/v1/sync/changes');
      final cursor = request.url.queryParameters['cursor'];
      if (cursor == '0') {
        return http.Response(jsonEncode({
          'changes': [{
            'entityType': 'note', 'entityId': 'note-1',
            'version': 9, 'deleted': false,
          }],
          'nextCursor': 5, 'hasMore': true,
        }), 200);
      }
      expect(cursor, '5');
      return http.Response(jsonEncode({
        'changes': [{
          'entityType': 'note', 'entityId': 'note-1',
          'version': 10, 'deleted': true,
        }],
        'nextCursor': 6, 'hasMore': false,
      }), 200);
    });
    addTearDown(client.close);
    final observation = await const RestoreCloudReadOnlyPreflight().inspect(
      client: client, apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => 'test-token',
    );
    expect(methods, ['GET', 'GET']);
    expect(observation.eventsRead, 2);
    expect(observation.lastCursor, 6);
    expect(observation.revisions['note:note-1'], 10);
    expect(observation.uploadAuthorized, isFalse);
    expect(observation.importedCursorTrusted, isFalse);

    final current = await profile(owner, '91');
    final imported = await profile(owner, '25');
    final review = RestoreCloudReview.compare(
      checkpoint: current, target: imported,
      observation: observation,
    );
    expect(review.importedOperations, 1);
    expect(review.potentiallyStaleEntities, 1);
    expect(review.cursorRegressedOrUnknown, isTrue);
    expect(review.canReplayOperations, isFalse);
    expect(review.canWriteToCloud, isFalse);
  });

  test('unobserved data cannot be assumed absent from cloud', () async {
    final observation = const RestoreCloudObservation(
      lastCursor: 900, eventsRead: 0, revisions: {},
    );
    final review = RestoreCloudReview.compare(
      checkpoint: await profile(owner, '50'),
      target: await profile(owner, '50'),
      observation: observation,
    );
    expect(review.unobservedEntities, 1);
    expect(review.canWriteToCloud, isFalse);
    expect(review.canTrustImportedCursor, isFalse);
  });

  test('HTTP error or invalid schema is fail closed', () async {
    final failed = MockClient((request) async =>
        http.Response('no credentials in response', 401));
    addTearDown(failed.close);
    await expectLater(const RestoreCloudReadOnlyPreflight().inspect(
      client: failed, apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => 'sensitive',
    ), throwsFormatException);

    final malformed = MockClient((request) async =>
        http.Response('{"changes":[],"nextCursor":"oops","hasMore":false}',
            200));
    addTearDown(malformed.close);
    await expectLater(const RestoreCloudReadOnlyPreflight().inspect(
      client: malformed, apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => 'token',
    ), throwsFormatException);
  });

  test('rejects HTTP outside emulator/localhost and pagination loops',
      () async {
    final calls = <Uri>[];
    final client = MockClient((request) async {
      calls.add(request.url);
      return http.Response(jsonEncode({
        'changes': [],
        'nextCursor': 0,
        'hasMore': true,
      }), 200);
    });
    addTearDown(client.close);
    await expectLater(const RestoreCloudReadOnlyPreflight().inspect(
      client: client, apiBase: Uri.parse('http://sync.example'),
      accessToken: () async => 'token',
    ), throwsFormatException);
    expect(calls, isEmpty);
    await expectLater(const RestoreCloudReadOnlyPreflight().inspect(
      client: client, apiBase: Uri.parse('https://sync.example'),
      accessToken: () async => 'token',
    ), throwsFormatException);
    expect(calls.length, 1);
  });

  test('different checkpoint and target owner never produce review', () async {
    final current = await profile(owner, '91');
    final foreign = await profile('different-google-user', '25');
    await expectLater(
      Future<void>(() {
        RestoreCloudReview.compare(
          checkpoint: current,
          target: foreign,
          observation: const RestoreCloudObservation(
            lastCursor: 0, eventsRead: 0, revisions: {},
          ),
        );
      }),
      throwsFormatException,
    );
  });
}
