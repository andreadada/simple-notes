import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/auth/cloud_auth.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/sync/cloud_sync.dart';

/// Simulates the same Google user on two different SQLite databases.
/// The mocked REST server applies versions and returns a monotonically
/// increasing change cursor just like /sync/apply and /sync/changes.
class _FakeCloudAuth extends CloudAuth {
  _FakeCloudAuth() : super() {
    state = const CloudSession(accessToken: 'test-token', userId: 'same-user');
  }

  @override
  Future<String> validAccessToken() async => 'test-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Note from PC reaches Android and the edited note returns to PC',
      () async {
    final serverRows = <String, Map<String, dynamic>>{};
    final changes = <Map<String, dynamic>>[];

    final server = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/sync/apply') {
        final operation = jsonDecode(request.body) as Map<String, dynamic>;
        final id = operation['entityId'] as String;
        final previous = serverRows[id];
        final expected = operation['expectedVersion'];
        if (expected != previous?['version']) {
          return http.Response('{"message":"Version conflict"}', 409);
        }
        final version = previous == null ? 0 : (previous['version'] as int) + 1;
        final payload = operation['payload'] as Map<String, dynamic>;
        serverRows[id] = {'version': version, 'payload': payload};
        changes.add({
          'changeId': changes.length + 1,
          'entityType': operation['entityType'],
          'entityId': id,
          'payload': payload,
          'deleted': false,
          'version': version,
        });
        return http.Response(jsonEncode({
          'operationId': operation['operationId'],
          'version': version,
          'changeId': changes.length,
        }), 200);
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/sync/changes') {
        final cursor = int.parse(request.url.queryParameters['cursor'] ?? '0');
        final delta = changes.where((item) =>
            (item['changeId'] as int) > cursor).toList();
        return http.Response(jsonEncode({
          'changes': delta,
          'nextCursor': delta.isEmpty
              ? cursor
              : delta.last['changeId'],
          'hasMore': false,
        }), 200);
      }
      return http.Response('Not found', 404);
    });

    final pcDatabase = AppDatabase(NativeDatabase.memory());
    final mobileDatabase = AppDatabase(NativeDatabase.memory());

    ProviderContainer device(AppDatabase database) => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialDataProvider.overrideWithValue(const LocalData()),
        cloudAuthProvider.overrideWith((ref) => _FakeCloudAuth()),
        cloudSyncProvider.overrideWith(
          (ref) => CloudSync(ref, client: server,
            apiBaseUrl: 'https://fake-api.example')),
      ],
    );

    final pc = device(pcDatabase);
    final mobile = device(mobileDatabase);
    addTearDown(() async {
      pc.dispose();
      mobile.dispose();
      server.close();
      await pcDatabase.close();
      await mobileDatabase.close();
    });

    // A locally empty note title is legal (UI calls it "Senza titolo").
    await pc.read(localStoreProvider.notifier).addNote();
    final original = pc.read(localStoreProvider).notes.single;
    await pc.read(localStoreProvider.notifier).editNote(
      original.id, title: '', body: 'Scritta sul PC');
    expect(await pcDatabase.pendingCount(), 2);

    await pc.read(cloudSyncProvider.notifier).synchronize();
    expect(pc.read(cloudSyncProvider).conflict, isFalse);
    expect(await pcDatabase.pendingCount(), 0);

    await mobile.read(cloudSyncProvider.notifier).synchronize();
    final onMobile = mobile.read(localStoreProvider).notes.single;
    expect(onMobile.id, original.id);
    expect(onMobile.title, '');
    expect(onMobile.body, 'Scritta sul PC');
    expect(await mobileDatabase.pendingCount(), 0);

    await mobile.read(localStoreProvider.notifier).editNote(
      onMobile.id, title: 'Aggiornata', body: 'Modificata sul telefono');
    await mobile.read(cloudSyncProvider.notifier).synchronize();
    expect(mobile.read(cloudSyncProvider).conflict, isFalse);
    expect(await mobileDatabase.pendingCount(), 0);

    await pc.read(cloudSyncProvider.notifier).synchronize();
    final onPc = pc.read(localStoreProvider).notes.single;
    expect(onPc.title, 'Aggiornata');
    expect(onPc.body, 'Modificata sul telefono');
    expect(await pcDatabase.pendingCount(), 0);
  });
}
