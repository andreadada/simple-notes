import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/task_action_automations.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/task_action_automations_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Forui task rule editor persists user-selected trigger and value',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: SingleChildScrollView(
          child: TaskActionAutomationsPanel(
            ownerId: 'owner-a', lists: const [],
          ),
        )),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-rule-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-trigger-completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-type-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-tag')), 'reviewed');
    await tester.enterText(find.byKey(const Key('action-keyword')), 'esame');
    await tester.ensureVisible(find.byKey(const Key('action-rule-save')));
    await tester.tap(find.byKey(const Key('action-rule-save')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final rules = await const TaskActionStore().load(prefs, 'owner-a');
    expect(rules.rules, hasLength(1));
    final saved = rules.rules.single;
    expect(saved.trigger, 'completed');
    expect(saved.action, 'tag');
    expect(saved.value, 'reviewed');
    expect(saved.titleContains, 'esame');
    await tester.ensureVisible(find.byKey(Key('action-rule-toggle-${saved.id}')));
    await tester.tap(find.byKey(Key('action-rule-toggle-${saved.id}')));
    await tester.pumpAndSettle();
    expect((await const TaskActionStore().load(prefs, 'owner-a'))
        .rules.single.enabled, isFalse);
  });

  testWidgets('invalid local catalog is read-only and never reset',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final key = TaskActionStore.keyForOwner('owner-b');
    await prefs.setString(key, 'CORRUPT');
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: TaskActionAutomationsPanel(
          ownerId: 'owner-b', lists: const [],
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('action-rule-load-error')), findsOneWidget);
    expect(prefs.getString(key), 'CORRUPT');
  });
}
