import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sharing is online-only and never feeds a collaborator's records into the
/// current account's personal SQLite, /sync ledger or encrypted backup.
class ListSharingHttpException implements Exception {
  const ListSharingHttpException(this.status);
  final int status;
}

class SharedTaskPreview {
  const SharedTaskPreview({
    required this.id, required this.title,
    required this.description, required this.completed,
    required this.version, required this.priority,
  });
  final String id;
  final String title;
  final String? description;
  final bool completed;
  final int version;
  final int priority;

  factory SharedTaskPreview.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String || value['title'] is! String ||
        (value['description'] != null && value['description'] is! String) ||
        (value['completedAt'] != null && value['completedAt'] is! String) ||
        value['version'] is! int || (value['version'] as int) < 0 ||
        value['priority'] is! int || (value['priority'] as int) < 0 ||
        (value['priority'] as int) > 3) {
      throw const FormatException('Attività condivisa non valida.');
    }
    return SharedTaskPreview(
      id: value['id'] as String,
      title: value['title'] as String,
      description: value['description'] as String?,
      completed: value['completedAt'] != null,
      version: value['version'] as int,
      priority: value['priority'] as int,
    );
  }
}

class SharedTaskList {
  const SharedTaskList({
    required this.id, required this.title, required this.role,
  });
  final String id;
  final String title;
  final String role;

  factory SharedTaskList.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String || value['title'] is! String ||
        !const {'VIEWER', 'EDITOR'}.contains(value['role']) ||
        (value['title'] as String).length > 255) {
      throw const FormatException('Lista condivisa non valida.');
    }
    return SharedTaskList(
      id: value['id'] as String, title: value['title'] as String,
      role: value['role'] as String);
  }
}

class SharedSnapshot {
  const SharedSnapshot({
    required this.listId, required this.title,
    required this.tasks, required this.readOnly, this.nextOffset,
  });
  final String listId;
  final String title;
  final bool readOnly;
  final List<SharedTaskPreview> tasks;
  final int? nextOffset;

  factory SharedSnapshot.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['listId'] is! String || value['title'] is! String ||
        value['readOnly'] is! bool || value['tasks'] is! List ||
        (value['tasks'] as List).length > 50 ||
        (value['nextOffset'] != null &&
            (value['nextOffset'] is! int ||
                (value['nextOffset'] as int) < 1 ||
                (value['nextOffset'] as int) > 10050))) {
      throw const FormatException('Snapshot condivisa non valida.');
    }
    return SharedSnapshot(
      listId: value['listId'] as String,
      title: value['title'] as String,
      readOnly: value['readOnly'] as bool,
      tasks: (value['tasks'] as List)
          .map(SharedTaskPreview.parse).toList(growable: false),
      nextOffset: value['nextOffset'] as int?,
    );
  }
}

class ListShareInvitation {
  const ListShareInvitation({
    required this.id, required this.token, required this.expiresAt,
  });
  final String id;
  final String token;
  final DateTime expiresAt;
  factory ListShareInvitation.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String || value['token'] is! String ||
        value['expiresAt'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$')
            .hasMatch(value['token'] as String)) {
      throw const FormatException('Invito non valido.');
    }
    return ListShareInvitation(
      id: value['id'] as String, token: value['token'] as String,
      expiresAt: DateTime.parse(value['expiresAt'] as String),
    );
  }
}

class ListShareMember {
  const ListShareMember({required this.id, this.displayName,
      required this.role});
  final String id;
  final String? displayName;
  final String role;
  factory ListShareMember.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        (value['displayName'] != null && value['displayName'] is! String) ||
        (value['role'] != null &&
            !const {'VIEWER', 'EDITOR'}.contains(value['role']))) {
      throw const FormatException('Collaboratore non valido.');
    }
    return ListShareMember(id: value['id'] as String,
        displayName: value['displayName'] as String?,
        role: value['role'] as String? ?? 'VIEWER');
  }
}

class PendingListInvitation {
  const PendingListInvitation({required this.id, required this.expiresAt});
  final String id;
  final DateTime expiresAt;
  factory PendingListInvitation.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String || value['expiresAt'] is! String) {
      throw const FormatException('Invito pendente non valido.');
    }
    return PendingListInvitation(
      id: value['id'] as String,
      expiresAt: DateTime.parse(value['expiresAt'] as String));
  }
}

/// API-first, foreground-only collaboration. All requests stay on the
/// configured API origin and refuse HTTP redirects (JWT cannot be forwarded).
/// Raw invite tokens are transmitted ONLY in POST JSON bodies.
class ListSharingApi {
  ListSharingApi({
    required this.baseUrl, required this.tokenProvider, http.Client? client,
  }) : _client = client ?? http.Client(), _ownsClient = client == null;

  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  void close() { if (_ownsClient) _client.close(); }

  Uri _url(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    if (!(base.scheme == 'https' ||
          (base.scheme == 'http' &&
            const {'localhost','127.0.0.1','10.0.2.2'}.contains(base.host))) ||
        base.host.isEmpty || base.userInfo.isNotEmpty ||
        base.hasQuery || base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw const FormatException('Endpoint collaborazione non sicuro.');
    }
    return base.replace(path:'/api/v1/sharing$path', queryParameters:query);
  }

  Future<http.Response> _call(String method, String path,
      {Object? payload, Map<String,String>? query}) async {
    final uri = _url(path,query);
    final token = await tokenProvider();
    if (token.isEmpty) throw StateError('Account cloud non disponibile.');
    final request = http.Request(method,uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization':'Bearer $token',
        'Accept':'application/json',
        if (payload != null) 'Content-Type':'application/json',
      });
    if (payload != null) request.body = jsonEncode(payload);
    final stream = await _client.send(request)
        .timeout(const Duration(seconds:20));
    if (stream.contentLength != null && stream.contentLength! > 128 * 1024) {
      throw const FormatException('Risposta collaborazione troppo grande.');
    }
    final response = await http.Response.fromStream(stream);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ListSharingHttpException(response.statusCode);
    }
    return response;
  }

  Object? _body(http.Response response) {
    if (response.bodyBytes.length > 128 * 1024) {
      throw const FormatException('Risposta collaborazione troppo grande.');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static List<T> _list<T>(Object? value, T Function(Object?) parse,
      {required int limit}) {
    if (value is! List || value.length > limit) {
      throw const FormatException('Elenco collaborazione non valido.');
    }
    return value.map(parse).toList(growable:false);
  }

  Future<List<SharedTaskList>> sharedLists() async => _list(
      _body(await _call('GET','/lists')), SharedTaskList.parse,limit:100);

  Future<SharedTaskList> accept(String token) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const FormatException('Il codice invito non è valido.');
    }
    return SharedTaskList.parse(_body(await _call('POST',
        '/invitations/accept',payload:{'token':token})));
  }

  Future<ListShareInvitation> invite(String listId) async =>
      ListShareInvitation.parse(_body(await _call('POST',
        '/lists/${Uri.encodeComponent(listId)}/invitations')));

  Future<SharedSnapshot> snapshot(String listId, {int offset=0}) async {
    if (offset < 0 || offset > 10000) {
      throw const FormatException('Pagina non valida.');
    }
    return SharedSnapshot.parse(_body(await _call('GET',
      '/lists/${Uri.encodeComponent(listId)}/snapshot',
      query:{'offset':'$offset'})));
  }

  Future<void> leave(String listId) async {
    await _call('DELETE','/lists/${Uri.encodeComponent(listId)}/membership');
  }

  Future<List<ListShareMember>> members(String listId) async => _list(
      _body(await _call('GET',
          '/lists/${Uri.encodeComponent(listId)}/members')),
      ListShareMember.parse,limit:20);

  Future<List<PendingListInvitation>> pending(String listId) async => _list(
      _body(await _call('GET',
          '/lists/${Uri.encodeComponent(listId)}/invitations')),
      PendingListInvitation.parse,limit:10);

  Future<void> revokeMember(String listId,String memberId) async {
    await _call('DELETE','/lists/${Uri.encodeComponent(listId)}/members/'
        '${Uri.encodeComponent(memberId)}');
  }

  /// Owner-only role change. A token never carries EDITOR permission.
  Future<ListShareMember> changeRole(String listId, String memberId,
      String role) async {
    if (!const {'VIEWER', 'EDITOR'}.contains(role)) {
      throw const FormatException('Ruolo non valido.');
    }
    return ListShareMember.parse(_body(await _call('PUT',
      '/lists/${Uri.encodeComponent(listId)}/members/'
      '${Uri.encodeComponent(memberId)}/role',
      payload: {'role': role})));
  }

  /// Online CAS update; 409 must be surfaced to the user, never retried
  /// silently. Only the four owner-approved editable task attributes pass.
  Future<int> editTask(String listId, String taskId, {
    required int expectedVersion, String? title, String? description,
    bool? completed, int? priority,
  }) async {
    if (expectedVersion < 0 || (title == null && description == null &&
        completed == null && priority == null)) {
      throw const FormatException('Nessuna modifica valida al task.');
    }
    if (title != null && (title.trim().isEmpty || title.length > 1024)) {
      throw const FormatException('Titolo non valido.');
    }
    if (description != null && description.length > 20000) {
      throw const FormatException('Descrizione troppo lunga.');
    }
    if (priority != null && (priority < 0 || priority > 3)) {
      throw const FormatException('Priorità non valida.');
    }
    final response = _body(await _call('PATCH',
      '/lists/${Uri.encodeComponent(listId)}/tasks/'
      '${Uri.encodeComponent(taskId)}',
      payload: {
        'expectedVersion': expectedVersion,
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description,
        if (completed != null) 'completed': completed,
        if (priority != null) 'priority': priority,
      }));
    if (response is! Map<String, dynamic> ||
        response['version'] is! int || (response['version'] as int) < 0 ||
        response['changeId'] is! int ||
        (response['changeId'] as int) < 1) {
      throw const FormatException('Risposta modifica non valida.');
    }
    return response['version'] as int;
  }

  Future<void> revokeInvitation(String listId,String invitationId) async {
    await _call('DELETE','/lists/${Uri.encodeComponent(listId)}/invitations/'
        '${Uri.encodeComponent(invitationId)}');
  }
}
