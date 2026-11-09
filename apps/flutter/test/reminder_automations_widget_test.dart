import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/reminder_automations.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/reminder_automations_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Forui editor creates and disables a persisted local rule',
      (tester) async {
    var changed = 0;
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: ReminderAutomationsBoard(
          ownerId: 'rules-account', lists: const [],
          supported: true,
          notificationsEnabled: false,
          onToggleNotifications: () async {},
          onChanged: () => changed++,
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-automations-board')),
        findsOneWidget);
    expect(find.byKey(const Key('rule-toggle-rule-default-due')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('rule-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-lead-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-priority-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-save')));
    await tester.pumpAndSettle();
    const store = ReminderAutomationStore();
    final prefs = await SharedPreferences.getInstance();
    final library = await store.load(prefs, 'rules-account');
    expect(library.rules, hasLength(3));
    final created = library.rules.last;
    expect(created.leadMinutes, 30);
    expect(created.minPriority, 2);
    expect(changed, 1);
    await tester.ensureVisible(find.byKey(Key('rule-toggle-${created.id}')));
    await tester.tap(find.byKey(Key('rule-toggle-${created.id}')));
    await tester.pumpAndSettle();
    final disabled = await store.load(prefs, 'rules-account');
    expect(disabled.rules.last.enabled, isFalse);
    expect(changed, 2);
  });

  testWidgets('invalid stored rules block edits without overwriting data',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final key = ReminderAutomationStore.keyForOwner('corrupt');
    await prefs.setString(key, 'BAD-RULE-JSON');
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: ReminderAutomationsBoard(
          ownerId: 'corrupt', lists: const [], supported: true, notificationsEnabled: false,
          onToggleNotifications: () async {}, onChanged: () {},
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rule-load-error')), findsOneWidget);
    expect(find.byKey(const Key('rule-create')), findsOneWidget);
    expect(prefs.getString(key), 'BAD-RULE-JSON');
  });
}
