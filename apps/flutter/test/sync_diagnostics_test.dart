import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/auth/cloud_auth.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/sync/cloud_sync.dart';

class _AuthenticatedTestSession extends CloudAuth {
  _AuthenticatedTestSession() : super() {
    state = const CloudSession(accessToken: 'test-only',
      userId: 'test-account');
  }

  @override
  Future<String> validAccessToken() async => 'test-only';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer device(AppDatabase database, http.Client client) =>
      ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(database),
        initialDataProvider.overrideWithValue(const LocalData()),
        cloudAuthProvider.overrideWith((ref) => _AuthenticatedTestSession()),
        cloudSyncProvider.overrideWith((ref) => CloudSync(ref,
            client: client, apiBaseUrl: 'https://mock-sync.example')),
      ]);

  const typedCapabilities =
    '{"taskDueSchema":1,'
    '"taskDueKinds":["none","date","datetime","legacy"],'
    '"requiresExplicitDueForModernTasks":true}';

  test('Passive diagnostics checks compatibility without uploading tasks',
      () async {
    var getCount = 0, postCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/capabilities') {
        getCount++;
        return http.Response(typedCapabilities, 200);
      }
      postCount++;
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final container = device(db, client);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });

    await container.read(localStoreProvider.notifier).addTask(
        'Dati privati', due: TaskDue.dateOnly('2026-10-26'));
    final pendingBefore = await db.pendingCount();
    final report = await container.read(cloudSyncProvider.notifier)
        .inspectSync();

    expect(report.authenticated, isTrue);
    expect(report.backendStatus, 'compatible');
    expect(report.pending, pendingBefore);
    expect(report.localTasks, 1);
    expect(report.localNotes, 0);
    expect(report.cursor, 0);
    expect(report.lastSuccessUtc, isNull);
    expect(await db.pendingCount(), pendingBefore);
    expect(postCount, 0);
    expect(getCount, 1);
  });

  test('HTTP 426 retains pending edits and signals user visibly',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/capabilities') {
        return http.Response(typedCapabilities, 200);
      }
      return http.Response('{"code":"CLIENT_UPGRADE_REQUIRED"}', 426);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final container = device(db, client);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });
    await container.read(localStoreProvider.notifier).addTask(
        'Non perdere', due: TaskDue.dateOnly('2026-10-26'));
    await container.read(cloudSyncProvider.notifier).synchronize();

    expect(container.read(cloudSyncProvider).upgradeRequired, isTrue);
    expect(container.read(cloudSyncProvider).conflict, isFalse);
    expect(await db.pendingCount(), 1);
    expect(await db.setting('lastSyncSuccessUtc'), isNull);
  });

  test('Offline diagnostics never modify queue, cursor or last success',
      () async {
    final client = MockClient((request) async {
      throw const SocketException('offline');
    });
    final db = AppDatabase(NativeDatabase.memory());
    final container = device(db, client);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });
    await container.read(localStoreProvider.notifier).addNote();
    final report = await container.read(cloudSyncProvider.notifier)
        .inspectSync();

    expect(report.backendStatus, 'offline');
    expect(report.pending, 1);
    expect(await db.pendingCount(), 1);
    expect(await db.setting('syncCursor'), isNull);
    expect(await db.setting('lastSyncSuccessUtc'), isNull);
  });

  test('Successful full pull records last successful local timestamp',
      () async {
    final history = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/capabilities') {
        return http.Response(typedCapabilities, 200);
      }
      if (request.url.path == '/api/v1/sync/apply') {
        final operation = jsonDecode(request.body) as Map<String, dynamic>;
        history.add({
          'entityId': operation['entityId'],
          'entityType': operation['entityType'],
          'payload': operation['payload'],
          'deleted': false,
          'version': 0,
          'changeId': history.length + 1,
        });
        return http.Response(jsonEncode({
          'version': 0, 'operationId': operation['operationId'],
        }), 200);
      }
      if (request.url.path == '/api/v1/sync/changes') {
        return http.Response(jsonEncode({
          'changes': history,
          'nextCursor': history.length,
          'hasMore': false,
        }), 200);
      }
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final container = device(db, client);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });
    await container.read(localStoreProvider.notifier).addTask(
        'Consegna', due: TaskDue.dateOnly('2026-10-26'));
    await container.read(cloudSyncProvider.notifier).synchronize();
    expect(await db.pendingCount(), 0);
    final report = await container.read(cloudSyncProvider.notifier)
        .inspectSync();
    expect(report.backendStatus, 'compatible');
    expect(report.cursor, 1);
    expect(report.lastSuccessUtc, isNotNull);
    expect(report.localTasks, 1);
  });

  test('Diagnostic refuses account mismatch without contacting API',
      () async {
    var contacted = false;
    final client = MockClient((request) async {
      contacted = true;
      return http.Response(typedCapabilities, 200);
    });
    final db = AppDatabase(NativeDatabase.memory());
    await db.bindOwner('other-account');
    final container = device(db, client);
    addTearDown(() async {
      container.dispose();
      client.close();
      await db.close();
    });
    final report = await container.read(cloudSyncProvider.notifier)
        .inspectSync();
    expect(report.accountMatchesLocal, isFalse);
    expect(report.backendStatus, 'account-mismatch');
    expect(contacted, isFalse);
  });
}
