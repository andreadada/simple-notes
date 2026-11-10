import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/user_task_templates.dart';
import 'package:simple_notes/data/user_template_cloud_api.dart';
import 'package:simple_notes/ui/notes_theme.dart';
import 'package:simple_notes/ui/task_productivity_boards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final local = UserTaskTemplateLibrary(templates: [
    UserTaskTemplateLibrary.newTemplate(
      title: 'Locale', description: '', subtasks: []),
  ]);
  final remote = UserTaskTemplateLibrary(templates: [
    UserTaskTemplateLibrary.newTemplate(
      title: 'Cloud', description: '', subtasks: ['Verifica']),
  ]);

  Future<void> mount(WidgetTester tester, UserTemplateCloudApi api,
      {Future<bool> Function(String)? guard}) async {
    await tester.pumpWidget(MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(body: TaskTemplatesBoard(
          ownerId: 'account-a',
          cloudApi: api,
          cloudOwnerGuard: guard ?? (_) async => true,
          onCreate: (_) async {},
        )),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('download with confirmation preserves local until accepted',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await const UserTaskTemplateStore().save(prefs, 'account-a', local);
    var reads = 0;
    final api = UserTemplateCloudApi(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        reads++;
        return http.Response(jsonEncode({
          'version': 4, 'catalog': jsonDecode(remote.serialize()),
        }), 200);
      }),
    );
    await mount(tester, api);
    await tester.ensureVisible(find.byKey(const Key('download-custom-templates')));
    await tester.tap(find.byKey(const Key('download-custom-templates')));
    await tester.pumpAndSettle();
    expect((await const UserTaskTemplateStore().load(prefs, 'account-a'))
        .serialize(), local.serialize());
    await tester.tap(find.byKey(const Key('confirm-template-cloud')));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect((await const UserTaskTemplateStore().load(prefs, 'account-a'))
        .serialize(), remote.serialize());
  });

  testWidgets('download never overwrites if revision changes during consent',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await const UserTaskTemplateStore().save(prefs, 'account-a', local);
    var reads = 0;
    final api = UserTemplateCloudApi(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        reads++;
        return http.Response(jsonEncode({
          'version': reads == 1 ? 5 : 6,
          'catalog': jsonDecode(remote.serialize()),
        }), 200);
      }),
    );
    await mount(tester, api);
    await tester.ensureVisible(find.byKey(const Key('download-custom-templates')));
    await tester.tap(find.byKey(const Key('download-custom-templates')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-template-cloud')));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect((await const UserTaskTemplateStore().load(prefs, 'account-a'))
        .serialize(), local.serialize());
  });

  testWidgets('owner guard blocks any network request', (tester) async {
    var count = 0;
    final api = UserTemplateCloudApi(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: MockClient((_) async {
        count++;
        return http.Response('{}', 200);
      }),
    );
    await mount(tester, api, guard: (_) async => false);
    await tester.ensureVisible(find.byKey(const Key('publish-custom-templates')));
    await tester.tap(find.byKey(const Key('publish-custom-templates')));
    await tester.pumpAndSettle();
    expect(count, 0);
  });

  testWidgets('stale PUT 409 keeps local templates untouched', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await const UserTaskTemplateStore().save(prefs, 'account-a', local);
    var writes = 0;
    final api = UserTemplateCloudApi(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({
            'version': 3, 'catalog': jsonDecode(remote.serialize()),
          }), 200);
        }
        writes++;
        return http.Response('{}', 409);
      }),
    );
    await mount(tester, api);
    await tester.ensureVisible(find.byKey(const Key('publish-custom-templates')));
    await tester.tap(find.byKey(const Key('publish-custom-templates')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-template-cloud')));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect((await const UserTaskTemplateStore().load(prefs, 'account-a'))
        .serialize(), local.serialize());
  });
}
