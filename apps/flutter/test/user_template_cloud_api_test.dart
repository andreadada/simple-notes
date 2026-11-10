import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/user_task_templates.dart';
import 'package:simple_notes/data/user_template_cloud_api.dart';

void main() {
  final example = UserTaskTemplateLibrary(templates: [
    UserTaskTemplateLibrary.newTemplate(
      title: 'Studiare', description: 'Esempio',
      subtasks: ['Capitolo 1']),
  ]);

  test('strict read and PUT CAS preserve catalog and ID', () async {
    var version = 2, puts = 0;
    var remote = example;
    final api = UserTemplateCloudApi(
      baseUrl: 'https://example.test',
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body);
          expect(body['expectedVersion'], version);
          remote = UserTaskTemplateLibrary.deserialize(
              jsonEncode(body['catalog']));
          version++;
          puts++;
        }
        return http.Response(jsonEncode({
          'version': version,
          'catalog': jsonDecode(remote.serialize()),
        }), 200);
      }),
    );
    final snapshot = await api.read();
    expect(snapshot.version, 2);
    expect(snapshot.library.serialize(), example.serialize());
    final written = await api.replace(
      expectedVersion: snapshot.version, library: example);
    expect(written.version, 3);
    expect(written.library.templates.single.id, example.templates.single.id);
    expect(puts, 1);
  });

  test('HTTP 404/426/409 fail closed', () async {
    for (final status in [404, 426, 409]) {
      final api = UserTemplateCloudApi(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(api.read(), throwsA(status == 409
          ? isA<UserTemplateCloudConflict>()
          : isA<UserTemplateCloudUnavailable>()));
    }
  });

  test('invalid JSON, wrong schema, untrusted URL rejected', () async {
    for (final body in [
      '{invalid',
      '{"version":2,"catalog":{"schema":7,"templates":[]}}',
      '{"version":-1,"catalog":{"schema":1,"templates":[]}}',
    ]) {
      final api = UserTemplateCloudApi(
        baseUrl: 'https://example.test',
        tokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(api.read(), throwsFormatException);
    }
    final api = UserTemplateCloudApi(
      baseUrl: 'http://public.example',
      tokenProvider: () async => 'token',
      client: MockClient((_) async => fail('must not reach network')),
    );
    await expectLater(api.read(), throwsStateError);
  });
}
