import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/task_action_automations.dart';
import 'package:simple_notes/data/task_action_cloud_api.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/task_action_automations_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, TaskActionCloudApi api,
      {Future<bool> Function(String)? guard}) async {
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: SingleChildScrollView(
          child: TaskActionAutomationsPanel(
            ownerId: 'owner-a', lists: const [],
            cloudApi: api,
            cloudOwnerGuard: guard ?? (_) async => true,
          ),
        )),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('explicit cloud download replaces local rules after confirmation',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final old = TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(trigger: 'created',
          action: 'tag', value: 'LOCAL-OLD'),
    ]);
    final remote = TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(trigger: 'completed',
          action: 'tag', value: 'CLOUD-NEW'),
    ]);
    await const TaskActionStore().save(prefs, 'owner-a', old);
    var reads = 0;
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      reads++;
      return http.Response(jsonEncode({
        'version': 4, 'catalog': jsonDecode(remote.serialize()),
      }), 200);
    });
    final api = TaskActionCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'test-token', client: client);
    await mount(tester, api);
    await tester.ensureVisible(find.byKey(const Key('action-cloud-download')));
    await tester.tap(find.byKey(const Key('action-cloud-download')));
    await tester.pumpAndSettle();
    // No silent replacement before explicit user confirmation.
    expect((await const TaskActionStore().load(prefs, 'owner-a')).serialize(),
        old.serialize());
    await tester.tap(find.byKey(const Key('action-cloud-confirm')));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect((await const TaskActionStore().load(prefs, 'owner-a')).serialize(),
        remote.serialize());
  });

  testWidgets('stale cloud PUT is a safe conflict and keeps local catalog',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final local = TaskActionLibrary(rules: [
      TaskActionLibrary.newRule(trigger: 'created',
          action: 'priority', value: '3'),
    ]);
    await const TaskActionStore().save(prefs, 'owner-a', local);
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({
          'version': 5, 'catalog': {'schema': 1, 'rules': []},
        }), 200);
      }
      attempts++;
      final body = jsonDecode(request.body);
      expect(body['expectedVersion'], 5);
      return http.Response('{}', 409);
    });
    final api = TaskActionCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'test-token', client: client);
    await mount(tester, api);
    await tester.ensureVisible(find.byKey(const Key('action-cloud-upload')));
    await tester.tap(find.byKey(const Key('action-cloud-upload')));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    await tester.tap(find.byKey(const Key('action-cloud-confirm')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect((await const TaskActionStore().load(prefs, 'owner-a')).serialize(),
        local.serialize());
  });

  testWidgets('owner guard prevents any cloud HTTP request', (tester) async {
    var network = 0;
    final api = TaskActionCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'test-token',
      client: MockClient((_) async {
        network++;
        return http.Response('{}', 200);
      }),
    );
    await mount(tester, api, guard: (_) async => false);
    await tester.ensureVisible(find.byKey(const Key('action-cloud-download')));
    await tester.tap(find.byKey(const Key('action-cloud-download')));
    await tester.pumpAndSettle();
    expect(network, 0);
  });
  testWidgets('panel reports editor visibility outside lifecycle builds',
      (tester) async {
    final calls = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: TaskActionAutomationsPanel(
          ownerId: 'account-auto', lists: const [],
          onEditorVisibilityChanged: calls.add,
          autoSyncLabel: 'Regole cloud allineate',
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls, [true, false]);
  });

}
