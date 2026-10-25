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
import 'package:uuid/uuid.dart';

class _TestAuth extends CloudAuth {
  _TestAuth() : super() {
    state = const CloudSession(accessToken: 'test-token', userId: 'same-user');
  }

  @override
  Future<String> validAccessToken() async => 'test-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lists, tags, priorities and subtasks round-trip PC and Android',
      () async {
    final server = <String, Map<String, dynamic>>{};
    final changes = <Map<String, dynamic>>[];
    final mock = MockClient((request) async {
      if (request.url.path == '/api/v1/capabilities') {
        return http.Response('{"timeBlockSchema":1,"timeBlocksSchema":1}', 200);
      }
      if (request.url.path == '/api/v1/sync/apply') {
        final op = jsonDecode(request.body) as Map<String, dynamic>;
        final id = op['entityId'] as String;
        final previous = server[id];
        if (previous?['version'] != op['expectedVersion']) {
          return http.Response('{}', 409);
        }
        final type = op['entityType'] as String;
        final payload = op['payload'] as Map<String, dynamic>;
        if (type == 'task' && payload['listId'] != null) {
          final list = server[payload['listId']];
          if (list == null || list['entityType'] != 'list' ||
              list['deleted'] == true) {
            return http.Response('{"error":"unknown list"}', 400);
          }
        }
        if (type == 'list' && op['action'] == 'delete') {
          if (server.values.any((row) =>
              row['entityType'] == 'task' && row['deleted'] != true &&
              (row['payload'] as Map<String, dynamic>)['listId'] == id)) {
            return http.Response('{"error":"list has tasks"}', 409);
          }
        }
        final version =
            previous == null ? 0 : (previous['version'] as int) + 1;
        final deleted = op['action'] == 'delete';
        server[id] = {
          'entityId': id, 'entityType': type, 'payload': payload,
          'deleted': deleted, 'version': version,
        };
        changes.add({...server[id]!, 'changeId': changes.length + 1});
        return http.Response(jsonEncode({
          'operationId': op['operationId'],
          'version': version, 'changeId': changes.length,
        }), 200);
      }
      if (request.url.path == '/api/v1/sync/changes') {
        final cursor = int.parse(request.url.queryParameters['cursor'] ?? '0');
        final delta = changes.where(
            (row) => (row['changeId'] as int) > cursor).toList();
        return http.Response(jsonEncode({
          'changes': delta,
          'nextCursor': delta.isEmpty ? cursor : delta.last['changeId'],
          'hasMore': false,
        }), 200);
      }
      return http.Response('{}', 404);
    });

    final desktopDb = AppDatabase(NativeDatabase.memory());
    final androidDb = AppDatabase(NativeDatabase.memory());
    ProviderContainer device(AppDatabase database) => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialDataProvider.overrideWithValue(const LocalData()),
        cloudAuthProvider.overrideWith((ref) => _TestAuth()),
        cloudSyncProvider.overrideWith((ref) => CloudSync(ref,
          client: mock, apiBaseUrl: 'https://fake.notes')),
      ],
    );
    final desktop = device(desktopDb);
    final android = device(androidDb);
    addTearDown(() async {
      desktop.dispose();
      android.dispose();
      mock.close();
      await desktopDb.close();
      await androidDb.close();
    });

    await desktop.read(localStoreProvider.notifier).addList('Università');
    final list = desktop.read(localStoreProvider).lists.single;
    await desktop.read(localStoreProvider.notifier).addTask(
      'Preparare analisi', listId: list.id);
    final task = desktop.read(localStoreProvider).tasks.single;
    final child = LocalSubtask(
      id: const Uuid().v4(), title: 'Capitolo 1');
    await desktop.read(localStoreProvider.notifier).editTask(
      task.id, title: task.title, listId: list.id, changeListId: true,
      priority: 3, tags: ['esame', 'urgente'], subtasks: [child],
    );
    final pending = await desktopDb.pendingOperations();
    expect(pending.first.entityType, 'list');
    expect(pending.last.entityType, 'task');
    await desktop.read(cloudSyncProvider.notifier).synchronize();
    expect(desktop.read(cloudSyncProvider).conflict, isFalse);
    expect(await desktopDb.pendingCount(), 0);

    await android.read(cloudSyncProvider.notifier).synchronize();
    final incoming = android.read(localStoreProvider).tasks.single;
    expect(android.read(localStoreProvider).lists.single.title, 'Università');
    expect(incoming.listId, list.id);
    expect(incoming.priority, 3);
    expect(incoming.tags, ['esame', 'urgente']);
    expect(incoming.subtasks.single.title, 'Capitolo 1');

    await android.read(localStoreProvider.notifier)
        .toggleSubtask(incoming.id, child.id);
    await android.read(localStoreProvider.notifier)
        .renameList(list.id, 'Esami');
    await android.read(cloudSyncProvider.notifier).synchronize();
    await desktop.read(cloudSyncProvider.notifier).synchronize();
    expect(desktop.read(localStoreProvider).lists.single.title, 'Esami');
    expect(desktop.read(localStoreProvider).tasks.single
        .subtasks.single.completed, isTrue);

    await desktop.read(localStoreProvider.notifier).deleteList(list.id);
    expect(desktop.read(localStoreProvider).lists, isEmpty);
    expect(desktop.read(localStoreProvider).tasks.single.listId, isNull);
    await desktop.read(cloudSyncProvider.notifier).synchronize();
    expect(desktop.read(cloudSyncProvider).conflict, isFalse);
    expect(await desktopDb.pendingCount(), 0);

    await android.read(cloudSyncProvider.notifier).synchronize();
    expect(android.read(localStoreProvider).lists, isEmpty);
    expect(android.read(localStoreProvider).tasks.single.listId, isNull);
    expect(android.read(localStoreProvider).tasks.single.title,
        'Preparare analisi');
  });
}
