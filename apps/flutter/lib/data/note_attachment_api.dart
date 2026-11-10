import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// A signed URL is a bearer capability: never persist it or include it in
/// logs/backups. Cloud attachments are a separate, explicit online flow.
class NoteAttachment {
  const NoteAttachment({
    required this.id, required this.name,
    required this.contentType, required this.sizeBytes,
  });

  final String id;
  final String name;
  final String contentType;
  final int sizeBytes;

  factory NoteAttachment.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String || value['name'] is! String ||
        value['contentType'] is! String || value['sizeBytes'] is! int ||
        (value['sizeBytes'] as int) < 1 ||
        (value['sizeBytes'] as int) > NoteAttachmentApi.maxBytes) {
      throw const FormatException('Metadati allegato non validi.');
    }
    return NoteAttachment(
      id: value['id'] as String, name: value['name'] as String,
      contentType: value['contentType'] as String,
      sizeBytes: value['sizeBytes'] as int,
    );
  }
}

class NoteAttachmentUpload {
  const NoteAttachmentUpload({
    required this.id, required this.url, required this.headers,
  });
  final String id;
  final Uri url;
  final Map<String, String> headers;

  factory NoteAttachmentUpload.parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String || value['uploadUrl'] is! String ||
        value['headers'] is! Map<String, dynamic>) {
      throw const FormatException('Risposta upload non valida.');
    }
    final headers = <String, String>{};
    for (final entry in (value['headers'] as Map<String, dynamic>).entries) {
      if (entry.value is! String ||
          entry.key.toLowerCase() == 'authorization' ||
          entry.key.toLowerCase() == 'cookie') {
        throw const FormatException('Header upload non valido.');
      }
      headers[entry.key] = entry.value as String;
    }
    final url = Uri.parse(value['uploadUrl'] as String);
    NoteAttachmentApi.ensureSecure(url);
    return NoteAttachmentUpload(
      id: value['id'] as String, url: url, headers: headers,
    );
  }
}

class NoteAttachmentException implements Exception {
  const NoteAttachmentException(this.status);
  final int status;
}

/// JWT only to the API origin; S3 PUT uses the one-time signed ticket and
/// strictly NEVER receives the app authentication headers.
class NoteAttachmentApi {
  NoteAttachmentApi({
    required this.baseUrl, required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client(), _ownsClient = client == null;

  static const maxBytes = 10 * 1024 * 1024;
  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  void close() { if (_ownsClient) _client.close(); }

  static void ensureSecure(Uri url) {
    if (url.scheme != 'https' || url.host.isEmpty ||
        url.userInfo.isNotEmpty || url.fragment.isNotEmpty) {
      throw const FormatException('URL allegato non sicuro.');
    }
  }

  Uri _path(String noteId, [String suffix = '']) {
    final base = Uri.parse(baseUrl);
    if (!(base.scheme == 'https' ||
          (base.scheme == 'http' &&
            const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(base.host))) ||
        base.userInfo.isNotEmpty || base.hasQuery ||
        base.hasFragment || (base.path.isNotEmpty && base.path != '/')) {
      throw const FormatException('API non sicura.');
    }
    return base.resolve('/api/v1/notes/${Uri.encodeComponent(noteId)}/attachments$suffix');
  }

  Future<http.Response> _call(String method, Uri url,
      {Object? payload}) async {
    final jwt = await tokenProvider();
    if (jwt.isEmpty) throw StateError('Account cloud non disponibile.');
    final headers = <String, String>{
      'Authorization': 'Bearer $jwt',
      'Accept': 'application/json',
      if (payload != null) 'Content-Type': 'application/json',
    };
    final body = payload == null ? null : jsonEncode(payload);
    final http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(url, headers: headers);
      case 'POST':
        response = await _client.post(url, headers: headers, body: body);
      case 'DELETE':
        response = await _client.delete(url, headers: headers);
      default:
        throw StateError('Metodo non supportato.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NoteAttachmentException(response.statusCode);
    }
    return response;
  }

  static Object? _json(http.Response response) {
    if (response.bodyBytes.length > 128 * 1024) {
      throw const FormatException('Risposta allegati troppo grande.');
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<NoteAttachment>> list(String noteId) async {
    final response = await _call('GET', _path(noteId))
        .timeout(const Duration(seconds: 20));
    final value = _json(response);
    if (value is! List || value.length > 100) {
      throw const FormatException('Lista allegati non valida.');
    }
    return value.map(NoteAttachment.parse).toList(growable: false);
  }

  Future<NoteAttachmentUpload> begin(
      String noteId, String name, String type, int bytes) async {
    if (bytes < 1 || bytes > maxBytes ||
        !const {'image/jpeg', 'image/png', 'text/plain', 'application/pdf'}
            .contains(type) ||
        name.isEmpty || name.length > 180) {
      throw const FormatException('Allegato non supportato.');
    }
    final response = await _call('POST', _path(noteId),
      payload: {'name': name, 'contentType': type, 'sizeBytes': bytes})
      .timeout(const Duration(seconds: 20));
    return NoteAttachmentUpload.parse(_json(response));
  }

  Future<void> upload(NoteAttachmentUpload ticket, Uint8List bytes) async {
    ensureSecure(ticket.url);
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Dimensione allegato non valida.');
    }
    final request = http.Request('PUT', ticket.url)
      ..followRedirects = false
      ..headers.addAll(ticket.headers)
      ..bodyBytes = bytes;
    // No app JWT, refresh token, or cookies are ever forwarded to S3.
    final response = await _client.send(request)
        .timeout(const Duration(seconds: 45));
    final body = await http.Response.fromStream(response);
    if (body.statusCode < 200 || body.statusCode >= 300) {
      throw NoteAttachmentException(body.statusCode);
    }
  }

  Future<NoteAttachment> complete(String noteId, String id) async {
    final response = await _call('POST',
        _path(noteId, '/${Uri.encodeComponent(id)}/complete'))
        .timeout(const Duration(seconds: 30));
    return NoteAttachment.parse(_json(response));
  }

  Future<Uri> download(String noteId, String id) async {
    final response = await _call('GET',
        _path(noteId, '/${Uri.encodeComponent(id)}/download'))
        .timeout(const Duration(seconds: 20));
    final value = _json(response);
    if (value is! Map<String, dynamic> ||
        value['downloadUrl'] is! String) {
      throw const FormatException('Download non valido.');
    }
    final uri = Uri.parse(value['downloadUrl'] as String);
    ensureSecure(uri);
    return uri;
  }

  Future<void> delete(String noteId, String id) async {
    await _call('DELETE', _path(noteId, '/${Uri.encodeComponent(id)}'))
        .timeout(const Duration(seconds: 20));
  }
}
