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
import 'package:simple_notes/ui/time_block_view.dart';
import 'package:simple_notes/data/task_due_clock.dart';

class _P1Auth extends CloudAuth {
  _P1Auth() : super() {
    state = const CloudSession(userId: 'same-account',
        accessToken: 'test-access-token');
  }
  @override
  Future<String> validAccessToken() async => 'test-access-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer device(AppDatabase db, http.Client client) =>
      ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        initialDataProvider.overrideWithValue(const LocalData()),
        cloudAuthProvider.overrideWith((ref) => _P1Auth()),
        cloudSyncProvider.overrideWith((ref) =>
            CloudSync(ref, client: client,
                apiBaseUrl: 'https://p1.example')),
      ]);

  test('Time blocks survive SQLite and sync Windows to Android and back',
      () async {
    final changes = <Map<String, dynamic>>[];
    final versions = <String, int>{};
    final api = MockClient((req) async {
      if (req.url.path == '/api/v1/capabilities') {
        return http.Response(
            '{"taskDueSchema":1,"taskDueKinds":'
            '["none","date","datetime","legacy"],'
            '"requiresExplicitDueForModernTasks":true,'
            '"timeBlockSchema":1}', 200);
      }
      if (req.url.path == '/api/v1/sync/apply') {
        final op = jsonDecode(req.body) as Map<String, dynamic>;
        final id = op['entityId'] as String;
        if (versions[id] != op['expectedVersion']) {
          return http.Response('{"error":"conflict"}', 409);
        }
        final version = (versions[id] ?? -1) + 1;
        versions[id] = version;
        changes.add({
          'changeId': changes.length + 1,
          'entityId': id, 'entityType': op['entityType'],
          'version': version, 'payload': op['payload'],
          'deleted': false,
        });
        return http.Response(jsonEncode({
          'version': version, 'operationId': op['operationId'],
        }), 200);
      }
      if (req.url.path == '/api/v1/sync/changes') {
        final cursor = int.parse(req.url.queryParameters['cursor'] ?? '0');
        final delta = changes.where((x) =>
            (x['changeId'] as int) > cursor).toList();
        return http.Response(jsonEncode({
          'changes': delta, 'hasMore': false,
          'nextCursor': delta.isEmpty ? cursor : delta.last['changeId'],
        }), 200);
      }
      return http.Response('{}', 404);
    });
    final aDb = AppDatabase(NativeDatabase.memory());
    final bDb = AppDatabase(NativeDatabase.memory());
    final a = device(aDb, api);
    final b = device(bDb, api);
    addTearDown(() async {
      a.dispose();
      b.dispose();
      api.close();
      await aDb.close();
      await bDb.close();
    });
    await a.read(localStoreProvider.notifier).addTask(
        'Focus', due: TaskDue.dateOnly('2026-10-28'));
    final task = a.read(localStoreProvider).tasks.single;
    final block = TimeBlock(
      start: DateTime.utc(2026, 10, 26, 8),
      end: DateTime.utc(2026, 10, 26, 9, 30),
      timeZone: 'Europe/Rome',
    );
    await a.read(localStoreProvider.notifier)
        .setTaskTimeBlock(task.id, block);
    expect((await aDb.snapshot()).tasks.single.timeBlock!.duration,
        const Duration(minutes: 90));
    expect((await aDb.snapshot()).tasks.single.due.date, '2026-10-28');
    expect(await aDb.pendingCount(), 2);

    await a.read(cloudSyncProvider.notifier).synchronize();
    await b.read(cloudSyncProvider.notifier).synchronize();
    expect(await bDb.pendingCount(), 0);
    final received = b.read(localStoreProvider).tasks.single;
    expect(received.timeBlock!.start, block.start);
    expect(received.timeBlock!.end, block.end);
    expect(received.timeBlock!.timeZone, 'Europe/Rome');
    expect(received.due.date, '2026-10-28');

    await b.read(localStoreProvider.notifier).renameTask(task.id, 'Focus 2');
    await b.read(localStoreProvider.notifier)
        .setTaskTimeBlock(task.id, null);
    await b.read(cloudSyncProvider.notifier).synchronize();
    await a.read(cloudSyncProvider.notifier).synchronize();
    expect(a.read(localStoreProvider).tasks.single.timeBlock, isNull);
    expect(a.read(localStoreProvider).tasks.single.due.date, '2026-10-28');
    expect(a.read(localStoreProvider).tasks.single.title, 'Focus 2');
    expect(await aDb.pendingCount(), 0);
    expect(await bDb.pendingCount(), 0);
  });

  test('Older API cannot silently acknowledge task block changes', () async {
    var posted = 0;
    final api = MockClient((req) async {
      if (req.url.path == '/api/v1/capabilities') {
        return http.Response('{"taskDueSchema":1}', 200);
      }
      if (req.method == 'POST') posted++;
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final a = device(db, api);
    addTearDown(() async {
      a.dispose(); api.close(); await db.close();
    });
    await a.read(localStoreProvider.notifier).addTask('No silent loss');
    final task = a.read(localStoreProvider).tasks.single;
    await a.read(localStoreProvider.notifier).setTaskTimeBlock(task.id,
        TimeBlock(start: DateTime.utc(2026, 10, 26, 8),
            end: DateTime.utc(2026, 10, 26, 9),
            timeZone: 'Europe/Rome'));
    await a.read(cloudSyncProvider.notifier).synchronize();
    expect(a.read(cloudSyncProvider).upgradeRequired, isTrue);
    expect(posted, 0);
    expect(await db.pendingCount(), 2);
    expect((await db.snapshot()).tasks.single.timeBlock, isNotNull);
  });

  test('Invalid ranges rejected and DST fold remains unambiguous', () {
    expect(() => TimeBlock(start: DateTime.utc(2026, 10, 26, 10),
        end: DateTime.utc(2026, 10, 26, 9),
        timeZone: 'Europe/Rome'), throwsFormatException);
    expect(() => TimeBlock(start: DateTime.utc(2026, 10, 26, 10),
        end: DateTime.utc(2026, 10, 27, 11),
        timeZone: 'Europe/Rome'), throwsFormatException);
    final choices = TaskDueClock.possibilities(
        '2026-10-25', '02:30', 'Europe/Rome');
    expect(choices.length, 2);
    final first = TimeBlock(start: choices.first.instant,
        end: choices.last.instant, timeZone: 'Europe/Rome');
    expect(first.duration, const Duration(hours: 1));
    expect(timeBlockLabel(first), contains('Europe/Rome'));
  });
}
