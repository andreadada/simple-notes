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
import 'package:simple_notes/ui/time_block_interactions.dart';

class _TestAuth extends CloudAuth {
  _TestAuth() : super() {
    state = const CloudSession(userId: 'test-user', accessToken: 'token');
  }

  @override
  Future<String> validAccessToken() async => 'token';
}

TimeBlock block(int hour) => TimeBlock(
  start: DateTime.utc(2026, 10, 26, hour),
  end: DateTime.utc(2026, 10, 26, hour + 1),
  timeZone: 'Europe/Rome');

ProviderContainer device(AppDatabase db, http.Client api) =>
    ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
      cloudAuthProvider.overrideWith((ref) => _TestAuth()),
      cloudSyncProvider.overrideWith((ref) =>
          CloudSync(ref, client: api, apiBaseUrl: 'https://test.example')),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Multiple blocks keep stable IDs, due, other blocks and SQLite outbox',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ]);
    addTearDown(() async { container.dispose(); await db.close(); });
    final store = container.read(localStoreProvider.notifier);
    await store.addTask('Study', due: TaskDue.dateOnly('2026-10-30'));
    final id = container.read(localStoreProvider).tasks.single.id;
    await store.addTaskTimeSlot(id, block(8));
    await store.addTaskTimeSlot(id, block(12));
    var task = (await db.snapshot()).tasks.single;
    expect(task.timeBlocks.length, 2);
    final firstId = task.timeBlocks[0].id;
    final secondId = task.timeBlocks[1].id;
    expect(firstId, isNot(secondId));
    expect(task.due.date, '2026-10-30');
    expect(calendarTimeSlotsForDay([task], DateTime(2026, 10, 26)).length, 2);
    final layouts = calendarBlockLayout(
        [task], CalendarDayScale(DateTime(2026, 10, 26)), 54);
    expect(layouts.length, 2);
    expect(layouts.map((x) => x.slot.id).toSet(), {firstId, secondId});

    final moved = TimeBlock(
      start: DateTime.utc(2026, 10, 26, 13),
      end: DateTime.utc(2026, 10, 26, 14, 30),
      timeZone: 'Europe/Rome');
    await store.updateTaskTimeSlot(id, secondId, moved);
    task = (await db.snapshot()).tasks.single;
    expect(task.timeBlocks[0].id, firstId);
    expect(task.timeBlocks[0].block.start, block(8).start);
    expect(task.timeBlocks[1].id, secondId);
    expect(task.timeBlocks[1].block.end, moved.end);

    await store.duplicateTaskTimeSlot(id, firstId);
    task = (await db.snapshot()).tasks.single;
    expect(task.timeBlocks.length, 3);
    expect(task.timeBlocks.map((x) => x.id).toSet().length, 3);
    expect(task.timeBlocks.last.block.start,
        block(8).start.add(const Duration(days: 1)));

    await store.removeTaskTimeSlot(id, secondId);
    task = (await db.snapshot()).tasks.single;
    expect(task.timeBlocks.length, 2);
    expect(task.timeBlocks.any((x) => x.id == firstId), isTrue);
    expect(task.timeBlocks.any((x) => x.id == secondId), isFalse);
    expect(task.due.date, '2026-10-30');
    expect(await db.pendingCount(), 6);
    expect(jsonDecode((await db.pendingOperations()).last.payload)
        ['timeBlocks'], hasLength(2));
  });

  test('V8 block-only remote payload migrates to stable legacy slot ID', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.applyRemote(type: 'task', entityId: 'old',
        payload: {
          'title': 'Historic focus',
          'due': {'kind': 'date', 'date': '2026-10-27'},
          'timeBlock': block(8).toJson(),
          'createdAt': '2026-10-26T00:00:00Z',
        }, deleted: false, version: 3);
    final old = (await db.snapshot()).tasks.single;
    expect(old.timeBlocks.single.id, 'legacy');
    expect(old.timeBlock!.start, block(8).start);
    expect(old.due.date, '2026-10-27');
    await db.upsertTask(old.copyWith(title: 'No data loss'));
    final restored = (await db.snapshot()).tasks.single;
    expect(restored.timeBlocks.single.id, 'legacy');
    expect(jsonDecode((await db.pendingOperations()).single.payload)
        ['timeBlocks'], hasLength(1));
  });

  test('Unknown V8 server fails closed and retains all multi-slot edits',
      () async {
    var uploads = 0;
    final api = MockClient((request) async {
      if (request.url.path == '/api/v1/capabilities') {
        return http.Response(
          '{"taskDueSchema":1,"taskDueKinds":'
          '["none","date","datetime","legacy"],'
          '"requiresExplicitDueForModernTasks":true,"timeBlockSchema":1}', 200);
      }
      if (request.method == 'POST') uploads++;
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    final user = device(db, api);
    addTearDown(() async { user.dispose(); api.close(); await db.close(); });
    final store = user.read(localStoreProvider.notifier);
    await store.addTask('No silent downgrade');
    final id = user.read(localStoreProvider).tasks.single.id;
    await store.addTaskTimeSlot(id, block(8));
    await store.addTaskTimeSlot(id, block(12));
    await user.read(cloudSyncProvider.notifier).synchronize();
    expect(user.read(cloudSyncProvider).upgradeRequired, isTrue);
    expect(uploads, 0);
    expect(await db.pendingCount(), 3);
    expect((await db.snapshot()).tasks.single.timeBlocks.length, 2);
  });

  test('TimeSlotCollection rejects duplicate identities and >12 items', () {
    final good = TimeSlot(id: 'legacy', block: block(8));
    expect(() => TimeSlotCollection.validate([good, good]),
        throwsFormatException);
    expect(() => TimeSlotCollection.validate(List.generate(13, (i) =>
        TimeSlot(id: 'slot-$i', block: block(8)))), throwsFormatException);
  });
}
