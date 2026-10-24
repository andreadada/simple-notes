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

class _DueTestAuth extends CloudAuth {
  _DueTestAuth() : super() {
    state = const CloudSession(accessToken: 'test-token', userId: 'due-user');
  }

  @override
  Future<String> validAccessToken() async => 'test-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer device(AppDatabase db, http.Client client) =>
      ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        initialDataProvider.overrideWithValue(const LocalData()),
        cloudAuthProvider.overrideWith((ref) => _DueTestAuth()),
        cloudSyncProvider.overrideWith((ref) => CloudSync(ref,
          client: client, apiBaseUrl: 'https://fake-due.example')),
      ]);

  test('Two-device date-only and DST timed payload round-trip intact',
      () async {
    final serverRows = <String, Map<String, dynamic>>{};
    final changes = <Map<String, dynamic>>[];
    final api = MockClient((request) async {
      if (request.url.path == '/api/v1/capabilities') {
        return http.Response('{"taskDueSchema":1}', 200);
      }
      if (request.url.path == '/api/v1/sync/apply') {
        final op = jsonDecode(request.body) as Map<String, dynamic>;
        final id = op['entityId'] as String;
        final current = serverRows[id];
        if (current?['version'] != op['expectedVersion']) {
          return http.Response('{}', 409);
        }
        final version = current == null ? 0 : (current['version'] as int) + 1;
        final payload = op['payload'] as Map<String, dynamic>;
        serverRows[id] = {'version': version, 'payload': payload};
        changes.add({
          'changeId': changes.length + 1,
          'entityType': op['entityType'], 'entityId': id,
          'payload': payload, 'version': version, 'deleted': false,
        });
        return http.Response(jsonEncode({
          'version': version, 'operationId': op['operationId'],
        }), 200);
      }
      if (request.url.path == '/api/v1/sync/changes') {
        final cursor = int.parse(request.url.queryParameters['cursor'] ?? '0');
        final next = changes.where((c) => (c['changeId'] as int) > cursor).toList();
        return http.Response(jsonEncode({
          'changes': next,
          'hasMore': false,
          'nextCursor': next.isEmpty ? cursor : next.last['changeId'],
        }), 200);
      }
      return http.Response('{}', 404);
    });
    final desktopDb = AppDatabase(NativeDatabase.memory());
    final androidDb = AppDatabase(NativeDatabase.memory());
    final desktop = device(desktopDb, api);
    final android = device(androidDb, api);
    addTearDown(() async {
      desktop.dispose();
      android.dispose();
      api.close();
      await desktopDb.close();
      await androidDb.close();
    });

    await desktop.read(localStoreProvider.notifier).addTask('Consegna');
    final task = desktop.read(localStoreProvider).tasks.single;
    await desktop.read(localStoreProvider.notifier).setTaskDueSemantics(
      task.id, TaskDue.dateOnly('2026-10-26'));
    await desktop.read(cloudSyncProvider.notifier).synchronize();
    expect(await desktopDb.pendingCount(), 0);
    expect(desktop.read(cloudSyncProvider).conflict, false);

    await android.read(cloudSyncProvider.notifier).synchronize();
    final mobileDue = android.read(localStoreProvider).tasks.single.due;
    expect(mobileDue.kind, 'date');
    expect(mobileDue.date, '2026-10-26');
    expect(mobileDue.instant, isNull);

    await android.read(localStoreProvider.notifier).setTaskDueSemantics(
      task.id, TaskDue.timed(
        date: '2026-10-25', time: '02:30', timeZone: 'Europe/Rome',
        instant: DateTime.utc(2026, 10, 25, 1, 30),
        offsetSeconds: 3600,
      ));
    await android.read(cloudSyncProvider.notifier).synchronize();
    await desktop.read(cloudSyncProvider.notifier).synchronize();
    final returned = desktop.read(localStoreProvider).tasks.single.due;
    expect(returned.kind, 'datetime');
    expect(returned.time, '02:30');
    expect(returned.timeZone, 'Europe/Rome');
    expect(returned.offsetSeconds, 3600);
    expect(returned.instant, DateTime.utc(2026, 10, 25, 1, 30));
    expect(await desktopDb.pendingCount(), 0);
    expect(await androidDb.pendingCount(), 0);
  });

  test('Old server cannot silently accept date-only writes', () async {
    var attemptedApply = false;
    final api = MockClient((request) async {
      if (request.url.path == '/api/v1/capabilities') {
        return http.Response('{}', 404);
      }
      if (request.url.path == '/api/v1/sync/apply') {
        attemptedApply = true;
        return http.Response('{}', 200);
      }
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final pc = device(db, api);
    addTearDown(() async { pc.dispose(); api.close(); await db.close(); });
    await pc.read(localStoreProvider.notifier).addTask('Safe');
    final task = pc.read(localStoreProvider).tasks.single;
    await pc.read(localStoreProvider.notifier).setTaskDueSemantics(
        task.id, TaskDue.dateOnly('2026-10-26'));
    await pc.read(cloudSyncProvider.notifier).synchronize();
    // There is an older none task queued first; that operation can go through,
    // but the modern date-only operation MUST be blocked before upload.
    expect(pc.read(cloudSyncProvider).message, contains('server'));
    expect(await db.pendingCount(), greaterThan(0));
    expect(pc.read(cloudSyncProvider).conflict, false);
    expect(attemptedApply, isTrue);
  });

  test('HTTP 426 is not a rebasable conflict; unsent data stays in outbox',
      () async {
    final api = MockClient((request) async {
      if (request.url.path == '/api/v1/sync/apply') {
        return http.Response('{"code":"CLIENT_UPGRADE_REQUIRED"}', 426);
      }
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final pc = device(db, api);
    addTearDown(() async { pc.dispose(); api.close(); await db.close(); });
    await pc.read(localStoreProvider.notifier).addTask('Legacy pending');
    await pc.read(cloudSyncProvider.notifier).synchronize();
    expect(await db.pendingCount(), 1);
    expect(pc.read(cloudSyncProvider).conflict, false);
    expect(pc.read(cloudSyncProvider).details, isNull);
    expect(pc.read(cloudSyncProvider).message, contains('precedente'));
  });
}
