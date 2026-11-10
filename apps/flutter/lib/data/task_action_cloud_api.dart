import 'dart:convert';

import 'package:http/http.dart' as http;

import 'task_action_automations.dart';

class TaskActionCloudConflict implements Exception {
  const TaskActionCloudConflict();
}

class TaskActionCloudUnavailable implements Exception {
  const TaskActionCloudUnavailable();
}

class TaskActionCloudSnapshot {
  const TaskActionCloudSnapshot({
    required this.version, required this.library,
  });
  final int version;
  final TaskActionLibrary library;

  factory TaskActionCloudSnapshot.parse(String source) {
    if (utf8.encode(source).length > 64 * 1024) {
      throw const FormatException('Risposta automazioni troppo grande.');
    }
    final obj = jsonDecode(source);
    if (obj is! Map<String, dynamic> || obj.length != 2 ||
        obj['version'] is! int || (obj['version'] as int) < 0 ||
        obj['catalog'] is! Map<String, dynamic>) {
      throw const FormatException('Risposta automazioni incompatibile.');
    }
    final lib = TaskActionLibrary.deserialize(jsonEncode(obj['catalog']));
    return TaskActionCloudSnapshot(
      version: obj['version'] as int, library: lib);
  }
}

/// Explicit, guarded cloud exchange of rule *definitions*. No task mutations,
/// background jobs or implicit last-writer-wins updates are performed.
class TaskActionCloudApi {
  TaskActionCloudApi({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client(), _ownsClient = client == null;

  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) _client.close();
  }

  Uri get _url => Uri.parse(
      '$baseUrl/api/v1/automations/task-actions');

  Future<TaskActionCloudSnapshot> read() async {
    return _request('GET');
  }

  Future<TaskActionCloudSnapshot> replace({
    required int expectedVersion, required TaskActionLibrary library,
  }) async {
    if (expectedVersion < 0) {
      throw const FormatException('Versione cloud non valida.');
    }
    // Validation before any network transmission.
    TaskActionLibrary.deserialize(library.serialize());
    return _request('PUT', body: jsonEncode({
      'expectedVersion': expectedVersion,
      'catalog': jsonDecode(library.serialize()),
    }));
  }

  Future<TaskActionCloudSnapshot> _request(String method,
      {String? body}) async {
    final uri = _url;
    if (!(uri.scheme == 'https' ||
          (uri.scheme == 'http' &&
              const {'localhost', '127.0.0.1', '10.0.2.2'}
                  .contains(uri.host))) ||
        uri.userInfo.isNotEmpty) {
      throw StateError('Endpoint cloud non sicuro.');
    }
    final token = await tokenProvider();
    if (token.isEmpty) throw StateError('Sessione cloud non disponibile.');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (method == 'PUT') 'Content-Type': 'application/json',
    };
    final http.Response result;
    if (method == 'PUT') {
      result = await _client.put(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    } else {
      result = await _client.get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    }
    if (result.statusCode == 404 || result.statusCode == 426) {
      throw const TaskActionCloudUnavailable();
    }
    if (result.statusCode == 409) {
      throw const TaskActionCloudConflict();
    }
    if (result.statusCode != 200) {
      throw StateError('Operazione cloud non riuscita (HTTP '
          '${result.statusCode}).');
    }
    return TaskActionCloudSnapshot.parse(result.body);
  }
}
