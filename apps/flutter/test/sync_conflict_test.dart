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

class _Session extends CloudAuth {
  _Session() : super() {
    state = const CloudSession(accessToken: 'fake', userId: 'same-user');
  }
  @override
  Future<String> validAccessToken() async => 'fake';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Offline outbox and both conflict decisions preserve other notes',
      () async {
    final rows = <String, Map<String, dynamic>>{};
    final history = <Map<String, dynamic>>[];
    var online = true;
    final client = MockClient((req) async {
      if (!online) throw const SocketException('No network');
      if (req.url.path == '/api/v1/sync/apply') {
        final op = jsonDecode(req.body) as Map<String, dynamic>;
        final id = op['entityId'] as String;
        final old = rows[id];
        if (old?['version'] != op['expectedVersion']) {
          return http.Response('{"message":"conflict"}', 409);
        }
        final version = old == null ? 0 : (old['version'] as int) + 1;
        final deleted = op['action'] == 'delete';
        final payload = op['payload'] as Map<String, dynamic>;
        rows[id] = {
          'entityType': op['entityType'], 'entityId': id,
          'version': version, 'payload': payload, 'deleted': deleted,
        };
        history.add({...rows[id]!, 'changeId': history.length + 1});
        return http.Response(jsonEncode({
          'operationId': op['operationId'],
          'version': version, 'changeId': history.length,
        }), 200);
      }
      if (req.url.path == '/api/v1/sync/latest') {
        final row = rows[req.url.queryParameters['entityId']];
        return row == null
          ? http.Response('{}', 404)
          : http.Response(jsonEncode({...row, 'changeId': history.length}), 200);
      }
      if (req.url.path == '/api/v1/sync/changes') {
        final cursor = int.parse(req.url.queryParameters['cursor'] ?? '0');
        final delta = history.where(
          (item) => (item['changeId'] as int) > cursor).toList();
        return http.Response(jsonEncode({
          'changes': delta, 'nextCursor': delta.isEmpty
              ? cursor : delta.last['changeId'], 'hasMore': false,
        }), 200);
      }
      return http.Response('{}', 404);
    });

    final pcDb = AppDatabase(NativeDatabase.memory());
    final phoneDb = AppDatabase(NativeDatabase.memory());
    ProviderContainer device(AppDatabase db) => ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
      cloudAuthProvider.overrideWith((ref) => _Session()),
      cloudSyncProvider.overrideWith((ref) =>
        CloudSync(ref, client: client, apiBaseUrl: 'https://sync.example')),
    ]);
    final pc = device(pcDb), phone = device(phoneDb);
    addTearDown(() async {
      pc.dispose();
      phone.dispose();
      client.close();
      await pcDb.close();
      await phoneDb.close();
    });

    await pc.read(localStoreProvider.notifier).addNote();
    final n = pc.read(localStoreProvider).notes.single;
    await pc.read(localStoreProvider.notifier)
        .editNote(n.id, title: 'Condivisa', body: 'v0');
    await pc.read(cloudSyncProvider.notifier).synchronize();
    await phone.read(cloudSyncProvider.notifier).synchronize();
    expect(phone.read(localStoreProvider).notes.single.body, 'v0');

    // Two offline/concurrent edits: server accepts phone and rejects PC.
    await pc.read(localStoreProvider.notifier).editNote(n.id, body: 'PC');
    await phone.read(localStoreProvider.notifier).editNote(n.id, body: 'Telefono');
    await phone.read(cloudSyncProvider.notifier).synchronize();
    await pc.read(cloudSyncProvider.notifier).synchronize();
    expect(pc.read(cloudSyncProvider).conflict, isTrue);
    expect(pc.read(cloudSyncProvider).details?.remoteVersion, 1);
    expect(pc.read(localStoreProvider).notes.single.body, 'PC');
    expect(await pcDb.pendingCount(), 1);

    await pc.read(cloudSyncProvider.notifier).resolveConflict(keepLocal: true);
    expect(pc.read(cloudSyncProvider).conflict, isFalse);
    expect(await pcDb.pendingCount(), 0);
    await phone.read(cloudSyncProvider.notifier).synchronize();
    expect(phone.read(localStoreProvider).notes.single.body, 'PC');

    // Reverse the roles; explicitly choose server's edit this time.
    await phone.read(localStoreProvider.notifier).editNote(n.id, body: 'Locale');
    await pc.read(localStoreProvider.notifier).editNote(n.id, body: 'Remoto');
    await pc.read(cloudSyncProvider.notifier).synchronize();
    await phone.read(cloudSyncProvider.notifier).synchronize();
    expect(phone.read(cloudSyncProvider).conflict, isTrue);
    await phone.read(cloudSyncProvider.notifier)
        .resolveConflict(keepLocal: false);
    expect(phone.read(cloudSyncProvider).conflict, isFalse);
    expect(await phoneDb.pendingCount(), 0);
    expect(phone.read(localStoreProvider).notes.single.body, 'Remoto');

    // Unrelated unsent notes survive loss of connectivity and retry.
    online = false;
    await pc.read(localStoreProvider.notifier).addNote();
    await pc.read(cloudSyncProvider.notifier).synchronize();
    expect(pc.read(cloudSyncProvider).message, startsWith('Sync non riuscita'));
    expect(await pcDb.pendingCount(), 1);
    online = true;
    await pc.read(cloudSyncProvider.notifier).synchronize();
    expect(await pcDb.pendingCount(), 0);
    await phone.read(cloudSyncProvider.notifier).synchronize();
    expect(phone.read(localStoreProvider).notes.length, 2);
  });
}
