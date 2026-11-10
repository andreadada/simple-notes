import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/task_action_automations.dart';
import 'package:simple_notes/data/task_action_cloud_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = TaskActionLibrary(rules: [
    TaskActionLibrary.newRule(trigger: 'created',
      action: 'tag', value: 'Studio'),
  ]);

  test('GET and CAS PUT transfer only catalog with Bearer authorization',
      () async {
    var count = 0;
    final client = MockClient((request) async {
      count++;
      expect(request.url.toString(),
          'https://api.example.com/api/v1/automations/task-actions');
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.method == 'GET') {
        return http.Response(jsonEncode({
          'version': 0,
          'catalog': {'schema': 1, 'rules': <Object>[]},
        }), 200);
      }
      expect(request.method, 'PUT');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['expectedVersion'], 0);
      expect(payload['catalog'], jsonDecode(library.serialize()));
      return http.Response(jsonEncode({
        'version': 1, 'catalog': payload['catalog'],
      }), 200);
    });
    final api = TaskActionCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'test-token', client: client);
    expect((await api.read()).version, 0);
    final saved = await api.replace(expectedVersion: 0, library: library);
    expect(saved.version, 1);
    expect(saved.library.serialize(), library.serialize());
    expect(count, 2);
  });

  test('409 cannot overwrite remote; old deployment 404 fails explicitly',
      () async {
    var status = 409;
    final client = MockClient((request) async => http.Response('{}', status));
    final api = TaskActionCloudApi(baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'test-token', client: client);
    await expectLater(api.replace(expectedVersion: 1, library: library),
        throwsA(isA<TaskActionCloudConflict>()));
    status = 404;
    await expectLater(api.read(),
        throwsA(isA<TaskActionCloudUnavailable>()));
    status = 426;
    await expectLater(api.read(),
        throwsA(isA<TaskActionCloudUnavailable>()));
  });

  test('strict response rejects future schema, oversize, negative revision',
      () {
    expect(() => TaskActionCloudSnapshot.parse(jsonEncode({
      'version': -1, 'catalog': {'schema': 1, 'rules': []},
    })), throwsFormatException);
    expect(() => TaskActionCloudSnapshot.parse(jsonEncode({
      'version': 1, 'catalog': {'schema': 2, 'rules': []},
    })), throwsFormatException);
    expect(() => TaskActionCloudSnapshot.parse(jsonEncode({
      'version': 1, 'catalog': {'schema': 1, 'rules': [], 'extra': true},
    })), throwsFormatException);
    expect(() => TaskActionCloudSnapshot.parse('a' * 70000),
        throwsFormatException);
  });

  test('never send over insecure URL or URL with embedded credentials',
      () async {
    var sent = 0;
    final client = MockClient((request) async {
      sent++;
      return http.Response('{}', 200);
    });
    final api = TaskActionCloudApi(baseUrl: 'http://remote.example.com',
      tokenProvider: () async => 'token', client: client);
    await expectLater(api.read(), throwsStateError);
    final credentials = TaskActionCloudApi(
        baseUrl: 'https://user:pass@api.example.com',
        tokenProvider: () async => 'token', client: client);
    await expectLater(credentials.read(), throwsStateError);
    expect(sent, 0);
  });
}
