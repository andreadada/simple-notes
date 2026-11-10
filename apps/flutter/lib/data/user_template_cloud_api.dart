import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_task_templates.dart';

class UserTemplateCloudConflict implements Exception {
  const UserTemplateCloudConflict();
}
class UserTemplateCloudUnavailable implements Exception {
  const UserTemplateCloudUnavailable();
}

class UserTemplateCloudSnapshot {
  const UserTemplateCloudSnapshot({
    required this.version, required this.library,
  });
  final int version;
  final UserTaskTemplateLibrary library;

  factory UserTemplateCloudSnapshot.parse(String source) {
    if (utf8.encode(source).length > 160 * 1024) {
      throw const FormatException('Risposta modelli troppo grande.');
    }
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> || json.length != 2 ||
        json['version'] is! int || (json['version'] as int) < 0 ||
        json['catalog'] is! Map<String, dynamic>) {
      throw const FormatException('Risposta modelli cloud non valida.');
    }
    return UserTemplateCloudSnapshot(
      version: json['version'] as int,
      library: UserTaskTemplateLibrary.deserialize(
        jsonEncode(json['catalog'])),
    );
  }
}

/// Scoped versioned manual transfer; no implicit merging or task mutations.
class UserTemplateCloudApi {
  UserTemplateCloudApi({
    required this.baseUrl, required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client(), _owned = client == null;

  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client _client;
  final bool _owned;

  Uri get _url => Uri.parse('$baseUrl/api/v1/templates/catalog');
  void close() { if (_owned) _client.close(); }

  Future<UserTemplateCloudSnapshot> read() => _call('GET');

  Future<UserTemplateCloudSnapshot> replace({
    required int expectedVersion,
    required UserTaskTemplateLibrary library,
  }) {
    if (expectedVersion < 0) {
      throw const FormatException('Versione modelli cloud non valida.');
    }
    UserTaskTemplateLibrary.deserialize(library.serialize());
    return _call('PUT', body: jsonEncode({
      'expectedVersion': expectedVersion,
      'catalog': jsonDecode(library.serialize()),
    }));
  }

  Future<UserTemplateCloudSnapshot> _call(String method,
      {String? body}) async {
    final uri = _url;
    if (!(uri.scheme == 'https' ||
        (uri.scheme == 'http' &&
         const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host))) ||
        uri.userInfo.isNotEmpty) {
      throw StateError('Endpoint modelli non sicuro.');
    }
    final token = await tokenProvider();
    if (token.isEmpty) throw StateError('Sessione non disponibile.');
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
      throw const UserTemplateCloudUnavailable();
    }
    if (result.statusCode == 409) {
      throw const UserTemplateCloudConflict();
    }
    if (result.statusCode != 200) {
      throw StateError('Scambio modelli fallito: HTTP ${result.statusCode}');
    }
    return UserTemplateCloudSnapshot.parse(result.body);
  }
}
