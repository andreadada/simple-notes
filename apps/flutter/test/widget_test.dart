import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/main.dart';
import 'package:simple_notes/data/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Creates a task and keeps it in the local store', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
      child: const SimpleNotesApp(),
    ));
    await tester.enterText(find.byKey(const Key('task-input')), 'Comprare il pane');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Comprare il pane'), findsOneWidget);
    expect(prefs.getString('simple_notes.local.v1'), contains('Comprare il pane'));
  });
}
