import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/auth/cloud_auth.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/local_store.dart';
import 'package:simple_notes/sync/cloud_sync.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/sync_diagnostics_dialog.dart';

class _UiAuth extends CloudAuth {
  _UiAuth() : super() {
    state = const CloudSession(
        accessToken: 'widget-token', userId: 'widget-account');
  }

  @override
  Future<String> validAccessToken() async => 'widget-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Forui diagnostics show local queue and compatibility without upload',
      (tester) async {
    var sent = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/capabilities') {
        return http.Response(
          '{"taskDueSchema":1,"requiresExplicitDueForModernTasks":true,'
          '"taskDueKinds":["none","date","datetime","legacy"],'
          '"timeBlockSchema":1}', 200);
      }
      sent++;
      return http.Response('{}', 404);
    });
    final db = AppDatabase(NativeDatabase.memory());
    await db.upsertNote(LocalNote(
      id: 'private-note', title: 'Sensitive sample',
      body: 'Never display note text',
      createdAt: DateTime.utc(2026, 10, 24),
    ));

    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      initialDataProvider.overrideWithValue(const LocalData()),
      cloudAuthProvider.overrideWith((ref) => _UiAuth()),
      cloudSyncProvider.overrideWith((ref) => CloudSync(ref,
          client: client, apiBaseUrl: 'https://fake-api.example')),
    ], child: MaterialApp(
      builder: (context, child) => FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: Consumer(
        builder: (context, ref, _) => ElevatedButton(
          onPressed: () => showNotesSyncDiagnostics(context, ref),
          child: const Text('Open diagnostics'),
        ),
      )),
    )));

    await tester.tap(find.text('Open diagnostics'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-diagnostics-dialog')), findsOneWidget);
    expect(find.text('Compatibile (scadenze 1 + blocchi 1)'), findsOneWidget);
    expect(find.text('Modifiche in attesa'), findsOneWidget);
    expect(find.byKey(const Key('sync-diagnostics-copy')), findsOneWidget);
    expect(find.text('Sensitive sample'), findsNothing);
    expect(find.text('Never display note text'), findsNothing);
    expect(sent, 0);

    await tester.tap(find.byKey(const Key('sync-diagnostics-close')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
    await db.close();
  });
}
