import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/data/task_due_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Daily weekly monthly recurrence advances civil dates not UTC days', () {
    final day = TaskDue.dateOnly('2026-10-25');
    expect(TaskRecurrence('daily').advance(day).date, '2026-10-26');
    expect(TaskRecurrence('weekly', interval: 2).advance(day).date,
        '2026-11-08');
    expect(TaskRecurrence('monthly').advance(
      TaskDue.dateOnly('2026-01-31')).date, '2026-02-28');
    expect(TaskRecurrence('monthly').advance(
      TaskDue.dateOnly('2028-01-31')).date, '2028-02-29');
    expect(TaskRecurrence('monthly', interval: 2).advance(
      TaskDue.dateOnly('2026-12-31')).date, '2027-02-28');
    expect(() => TaskRecurrence('weekly', interval: 13),
        throwsFormatException);
    expect(() => TaskRecurrence('invalid'), throwsFormatException);
  });

  test('Timed recurrence resolves DST gap and fold with explicit UTC offset', () {
    final original = TaskDueClock.resolve('2027-03-27', '02:30',
        'Europe/Rome');
    final next = TaskRecurrence('daily').advance(original);
    // 2027-03-28 at 02:30 is nonexistent in Europe/Rome. Skip.
    expect(next.date, '2027-03-29');
    expect(next.time, '02:30');
    expect(next.timeZone, 'Europe/Rome');
    final summer = TaskDueClock.resolve('2026-10-24', '02:30',
        'Europe/Rome');
    final folded = TaskRecurrence('daily').advance(summer);
    expect(folded.date, '2026-10-25');
    expect(folded.instant, DateTime.utc(2026, 10, 25, 0, 30));
    expect(folded.offsetSeconds, 7200);
  });

  test('Completing recurrence enqueues one upsert, advances same task ID',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ]);
    addTearDown(() async { container.dispose(); await db.close(); });
    final store = container.read(localStoreProvider.notifier);
    await store.addTask('Lavare piatti',
        due: TaskDue.dateOnly('2026-10-26'));
    final id = container.read(localStoreProvider).tasks.single.id;
    await store.setTaskRecurrence(id, TaskRecurrence('daily'));
    expect((await db.pendingOperations()).length, 2);
    await store.toggleTask(id);
    final tasks = (await db.snapshot()).tasks;
    expect(tasks, hasLength(1));
    expect(tasks.single.id, id);
    expect(tasks.single.completed, isFalse);
    expect(tasks.single.due.date, '2026-10-27');
    expect(tasks.single.recurrence.kind, 'daily');
    expect((await db.pendingOperations()).length, 3);
    await store.setTaskRecurrence(id, TaskRecurrence.none);
    await store.toggleTask(id);
    expect((await db.snapshot()).tasks.single.completed, isTrue);
    expect((await db.snapshot()).tasks.single.recurrence.enabled, isFalse);
  });

  test('Clearing due clears recurrence, independent blocks stay intact',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
    ]);
    addTearDown(() async { container.dispose(); await db.close(); });
    final store = container.read(localStoreProvider.notifier);
    await store.addTask('Studio', due: TaskDue.dateOnly('2026-11-20'));
    final id = container.read(localStoreProvider).tasks.single.id;
    await store.addTaskTimeSlot(id, TimeBlock(
      start: DateTime.utc(2026, 11, 19, 8),
      end: DateTime.utc(2026, 11, 19, 9),
      timeZone: 'Europe/Rome'));
    await store.setTaskRecurrence(id, TaskRecurrence('weekly'));
    await store.setTaskDueSemantics(id, TaskDue.none);
    final task = (await db.snapshot()).tasks.single;
    expect(task.due.kind, 'none');
    expect(task.recurrence.kind, 'none');
    expect(task.timeBlocks, hasLength(1));
  });

  test('JSON fallback and invalid rule reject without destructive changes',
      () {
    expect(TaskRecurrence.fromJson(null).kind, 'none');
    expect(TaskRecurrence.fromJson({'kind':'weekly','interval':2})
        .interval, 2);
    expect(TaskRecurrence.fromJson({'kind':'none'}).enabled, isFalse);
    expect(() => TaskRecurrence.fromJson({'kind':'weekly'}),
        throwsFormatException);
  });
}
