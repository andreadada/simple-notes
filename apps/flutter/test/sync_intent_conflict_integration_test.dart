import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/auth/cloud_auth.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/sync/cloud_sync.dart';

class _LoggedIn extends CloudAuth {
  _LoggedIn() : super() {
    state = const CloudSession(accessToken: 'test-token', userId: 'same-user');
  }

  @override
  Future<String> validAccessToken() async => 'test-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('immutable intent 409 preserves every pending op and never rebases',
      () async {
    var writes = 0;
    var latestReads = 0;
    var changeReads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/sync/apply') {
        writes++;
        return http.Response(
          jsonEncode({'code': 'SYNC_OPERATION_ID_REUSE'}), 409,
        );
      }
      if (request.url.path == '/api/v1/sync/latest') {
        latestReads++;
        return http.Response('{}', 200);
      }
      if (request.url.path == '/api/v1/sync/changes') {
        changeReads++;
        return http.Response('{}', 200);
      }
      return http.Response('{}', 404);
    });

    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
      cloudAuthProvider.overrideWith((ref) => _LoggedIn()),
      cloudSyncProvider.overrideWith((ref) =>
          CloudSync(ref, client: client, apiBaseUrl: 'https://api.test')),
    ]);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });

    await container.read(localStoreProvider.notifier).addNote();
    final created = container.read(localStoreProvider).notes.single;
    await container.read(localStoreProvider.notifier).editNote(
      created.id, title: 'PRIVATE TITLE', body: 'PRIVATE BODY',
    );
    final queued = await db.pendingOperations();
    expect(queued.length, 2);
    await container.read(cloudSyncProvider.notifier).synchronize();

    final state = container.read(cloudSyncProvider);
    expect(state.conflict, isTrue);
    expect(state.running, isFalse);
    expect(state.details, isNull);
    expect(state.message, contains('già registrata'));
    expect(state.message, isNot(contains('PRIVATE BODY')));
    expect(writes, 1);
    expect(latestReads, 0);
    expect(changeReads, 0);
    expect(await db.pendingCount(), 2);
    expect((await db.pendingOperations()).map((e) => e.operationId),
        queued.map((e) => e.operationId));
    expect(container.read(localStoreProvider).notes.single.body,
        'PRIVATE BODY');

    // The existing interactive resolution must be disabled, with no DB writes.
    await container.read(cloudSyncProvider.notifier)
        .resolveConflict(keepLocal: true);
    expect(container.read(cloudSyncProvider).details, isNull);
    expect(await db.pendingCount(), 2);
    expect(writes, 1);
  });

  test('ordinary 409 keeps old review behavior and does not acknowledge',
      () async {
    var latestRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/sync/apply') {
        return http.Response('{"detail":"Version conflict"}', 409);
      }
      if (request.url.path == '/api/v1/sync/latest') {
        latestRequests++;
        return http.Response(jsonEncode({
          'version': 4, 'deleted': false,
          'payload': {'title': 'Remote', 'body': 'Remote body'},
        }), 200);
      }
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
      cloudAuthProvider.overrideWith((ref) => _LoggedIn()),
      cloudSyncProvider.overrideWith((ref) =>
          CloudSync(ref, client: client, apiBaseUrl: 'https://api.test')),
    ]);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });
    await container.read(localStoreProvider.notifier).addNote();
    await container.read(cloudSyncProvider.notifier).synchronize();
    final state = container.read(cloudSyncProvider);
    expect(state.conflict, isTrue);
    expect(state.details, isNotNull);
    expect(state.details?.remoteVersion, 4);
    expect(await db.pendingCount(), 1);
    expect(latestRequests, 1);
  });
}
