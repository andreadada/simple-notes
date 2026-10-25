import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/calendar_board.dart';
import 'package:simple_notes/ui/calendar_logic.dart';
import 'package:simple_notes/ui/notes_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Calendar navigates day/week/month and edits synced task fields',
      (tester) async {
    tester.view.physicalSize = const Size(1250, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase(NativeDatabase.memory());
    final today = DateTime.now();
    final existing = LocalTask(id: 'calendar-task', title: 'Task prova',
      dueAt: null, due: TaskDue.dateOnly(calendarDateKey(today)),
      completed: false, createdAt: today);
    await db.upsertTask(existing);
    final initial = await db.snapshot();

    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(initial),
    ], child: MaterialApp(
      builder: (context, child) => FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: CalendarBoard()),
    )));

    expect(find.byKey(const Key('calendar-mode-week')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-mode-day')));
    await tester.pumpAndSettle();
    expect(find.text('Task prova'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-complete-calendar-task')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarBoard)));
    expect(container.read(localStoreProvider).tasks.single.completed, isTrue);

    await tester.tap(find.byKey(const Key('calendar-mode-month')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('calendar-date-${calendarDateKey(today)}')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-date-${calendarDateKey(today)}')));
    await tester.pumpAndSettle();
    expect(find.text('Task prova'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}
