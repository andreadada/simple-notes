import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/time_block_interactions.dart';
import 'package:simple_notes/ui/time_block_timeline.dart';

TimeBlock _block(DateTime start, int minutes) => TimeBlock(
  start: start, end: start.add(Duration(minutes: minutes)),
  timeZone: 'Europe/Rome',
);

LocalTask _task(String id, TimeBlock block, {TaskDue? due}) => LocalTask(
  id: id, title: id, completed: false,
  dueAt: null, due: due, timeBlock: block,
  createdAt: DateTime.utc(2026, 10, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gesture moves snap to quarter hours, not every frame', () {
    expect(calendarGestureMinutes(13.5, 54), 15);
    expect(calendarGestureMinutes(27, 54), 30);
    expect(calendarGestureMinutes(-27, 54), -30);
    expect(calendarGestureMinutes(5, 54), 0);
    expect(() => calendarGestureMinutes(10, 0), throwsArgumentError);
  });

  test('Move and resize preserve zone, duration and validate bounds', () {
    final start = DateTime.utc(2026, 10, 26, 8);
    final original = _block(start, 90);
    final moved = calendarMoveBlock(original, 30);
    expect(moved.start, start.add(const Duration(minutes: 30)));
    expect(moved.end, start.add(const Duration(hours: 2)));
    expect(moved.duration, original.duration);
    expect(moved.timeZone, original.timeZone);
    final resized = calendarResizeBlock(moved, -30);
    expect(resized.start, moved.start);
    expect(resized.duration, const Duration(minutes: 60));
    expect(() => calendarResizeBlock(original, -90), throwsFormatException);
    expect(() => calendarResizeBlock(original, 23 * 60),
        throwsFormatException);
    expect(() => calendarMoveBlock(original, 11), throwsFormatException);
  });

  test('Moving across days uses original IANA wall clock without altering duration', () {
    final source = _block(DateTime.utc(2026, 10, 25, 1, 30), 75);
    // Source 02:30 CET after fall-back.
    final dest = calendarMoveBlockToDay(source, DateTime(2026, 10, 26));
    expect(dest.start, DateTime.utc(2026, 10, 26, 1, 30));
    expect(dest.end.difference(dest.start), source.duration);
    expect(dest.timeZone, 'Europe/Rome');

    // 02:30 Europe/Rome does not exist on spring-forward day.
    expect(() => calendarMoveBlockToDay(
      _block(DateTime.utc(2026, 10, 28, 1, 30), 30),
      DateTime(2027, 3, 28)), throwsFormatException);

    // Source 02:30 CEST retains the first DST-fold occurrence on the
    // autumn transition, instead of silently flipping to standard time.
    final summer = _block(DateTime.utc(2026, 7, 2, 0, 30), 60);
    final fold = calendarMoveBlockToDay(summer, DateTime(2026, 10, 25));
    expect(fold.start, DateTime.utc(2026, 10, 25, 0, 30));
  });

  test('Calendar scale is local midnight-to-midnight, never assumed 24h UTC', () {
    final day = DateTime(2026, 10, 25);
    final scale = CalendarDayScale(day);
    expect(scale.start, day.toUtc());
    expect(scale.end, DateTime(2026, 10, 26).toUtc());
    expect(scale.minutes, scale.end.difference(scale.start).inMinutes);
    expect(scale.hours, isNotEmpty);
    expect(scale.getHeight(54), closeTo(scale.minutes / 60 * 54, 0.001));
  });

  test('Overlapping blocks receive different lanes, adjacent blocks share one',
      () {
    final day = DateTime(2026, 10, 26);
    final scale = CalendarDayScale(day);
    final base = scale.start.add(const Duration(hours: 8));
    final a = _task('a', _block(base, 90));
    final b = _task('b', _block(base.add(const Duration(minutes: 30)), 60));
    final c = _task('c', _block(base.add(const Duration(hours: 2)), 60));
    final layout = calendarBlockLayout([c, b, a], scale, 60);
    expect(layout.length, 3);
    expect(layout.first.task.id, 'a');
    expect(layout.first.lane, isNot(layout[1].lane));
    expect(layout.last.totalLanes, 2);
    expect(layout.last.lane, anyOf(0, 1));
  });

  test('A completed drag queues one SQLite upsert and retains the deadline', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final day = DateTime(2026, 10, 26);
    final base = DateTime(day.year, day.month, day.day, 10).toUtc();
    final task = _task('task', _block(base, 60),
      due: TaskDue.dateOnly('2026-10-29'));
    await db.upsertTask(task);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(await db.snapshot()),
    ]);
    addTearDown(() async { container.dispose(); await db.close(); });
    final revised = calendarMoveBlock(task.timeBlock!, 45);
    await container.read(localStoreProvider.notifier)
        .setTaskTimeBlock(task.id, revised);
    final actual = (await db.snapshot()).tasks.single;
    expect(actual.timeBlock!.start, revised.start);
    expect(actual.timeBlock!.end, revised.end);
    expect(actual.due.date, '2026-10-29');
    expect((await db.pendingOperations()).length, 2);
    expect((await db.pendingOperations()).last.entityType, 'task');
  });

  testWidgets('Vertical drag changes start; resize handle changes end',
      (tester) async {
    tester.view.physicalSize = const Size(650, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final day = DateTime(2026, 10, 26);
    final start = DateTime(day.year, day.month, day.day, 10).toUtc();
    final block = _block(start, 90);
    final task = _task('touch-block', block);
    final changes = <TimeBlock>[];
    Future<void> changed(String id, TimeBlock value) async {
      expect(id, 'touch-block');
      changes.add(value);
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: SingleChildScrollView(
          child: TimeBlockTimeline(
            day: day, tasks: [task], onChange: changed),
        ),
      ),
    )));
    final moveKey = find.byKey(const Key('calendar-block-move-touch-block'));
    final resizeKey = find.byKey(const Key('calendar-block-resize-touch-block'));
    await tester.ensureVisible(moveKey);
    await tester.drag(moveKey, const Offset(0, 27));
    await tester.pumpAndSettle();
    expect(changes.length, 1);
    expect(changes.first.start, block.start.add(const Duration(minutes: 30)));
    expect(changes.first.duration, block.duration);

    await tester.ensureVisible(resizeKey);
    await tester.drag(resizeKey, const Offset(0, 13.5));
    await tester.pumpAndSettle();
    expect(changes.length, 2);
    expect(changes.last.start, block.start);
    expect(changes.last.duration, const Duration(minutes: 105));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
