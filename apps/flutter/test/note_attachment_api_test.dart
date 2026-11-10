import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/note_attachment_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = 'd42e9bf3-24dc-4815-a90a-31ec2b200108';
  const note = 'bd7b98a6-5e1b-46ee-8e0e-0095534c3838';

  test('JWT sent only to API and never to temporary S3 PUT URL',
      () async {
    final seen = <String>[];
    final client = MockClient((request) async {
      seen.add('${request.method} ${request.url.host}');
      if (request.url.host == 'object.example') {
        expect(request.method, 'PUT');
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.headers['content-type'], 'text/plain');
        expect(request.bodyBytes, [104, 101, 108, 108, 111]);
        return http.Response('', 200);
      }
      expect(request.headers['Authorization'], 'Bearer PRIVATE-ACCESS-JWT');
      expect(request.url.path, contains('/notes/$note/attachments'));
      if (request.method == 'GET' && request.url.path.endsWith('attachments')) {
        return http.Response(jsonEncode([
          {'id': id, 'name': 'test.txt',
            'contentType': 'text/plain', 'sizeBytes': 5},
        ]), 200);
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/attachments')) {
        final fields = jsonDecode(request.body);
        expect(fields['sizeBytes'], 5);
        return http.Response(jsonEncode({
          'id': id,
          'uploadUrl': 'https://object.example/staging/opaque?X-Amz-Signature=opaque',
          'headers': {'content-type': 'text/plain'},
          'expiresAt': '2026-11-10T20:00:00Z',
        }), 201);
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/complete')) {
        return http.Response(jsonEncode({
          'id': id, 'name': 'test.txt',
          'contentType': 'text/plain', 'sizeBytes': 5,
        }), 200);
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/download')) {
        return http.Response(jsonEncode({
          'downloadUrl': 'https://object.example/files/opaque?sig=opaque',
          'expiresAt': '2026-11-10T20:00:00Z',
        }), 200);
      }
      if (request.method == 'DELETE') return http.Response('', 204);
      return http.Response('unexpected', 500);
    });
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'PRIVATE-ACCESS-JWT',
      client: client,
    );

    final ticket = await api.begin(note, 'test.txt', 'text/plain', 5);
    await api.upload(ticket, Uint8List.fromList([104, 101, 108, 108, 111]));
    final completed = await api.complete(note, id);
    expect(completed.name, 'test.txt');
    expect((await api.list(note)).single.id, id);
    final uri = await api.download(note, id);
    expect(uri.scheme, 'https');
    await api.delete(note, id);
    expect(seen, [
      'POST api.test',
      'PUT object.example',
      'POST api.test',
      'GET api.test',
      'GET api.test',
      'DELETE api.test',
    ]);
  });

  test('404/409/503 and invalid file are non-destructive failures', () async {
    for (final code in [404, 409, 503]) {
      final api = NoteAttachmentApi(
        baseUrl: 'https://api.test', tokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response('', code)),
      );
      await expectLater(api.list(note),
          throwsA(isA<NoteAttachmentException>()
              .having((x) => x.status, 'status', code)));
    }
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test', tokenProvider: () async => 'token',
      client: MockClient((_) async => fail('network must not be called')),
    );
    await expectLater(api.begin(note, 'huge.pdf', 'application/pdf',
        NoteAttachmentApi.maxBytes + 1), throwsFormatException);
    await expectLater(api.begin(note, 'unsafe.svg', 'image/svg+xml', 100),
        throwsFormatException);
    await expectLater(api.upload(
        NoteAttachmentUpload(
          id: id, url: Uri.parse('http://insecure.example/object'),
          headers: const {},
        ), Uint8List.fromList([1])), throwsFormatException);
  });

  test('malicious signed URLs and invalid response payload are rejected',
      () async {
    for (final url in [
      'http://object.example/upload',
      'https://user:password@object.example/upload',
      'https://object.example/upload#fragment',
    ]) {
      expect(() => NoteAttachmentUpload.parse({
        'id': id, 'uploadUrl': url, 'headers': <String, String>{},
      }), throwsFormatException);
    }
    expect(() => NoteAttachmentUpload.parse({
      'id': id, 'uploadUrl': 'https://object.example/upload',
      'headers': {'Authorization': 'Bearer SECRET'},
    }), throwsFormatException);
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test', tokenProvider: () async => 'token',
      client: MockClient((_) async =>
          http.Response('{"not":"an attachment list"}', 200)),
    );
    await expectLater(api.list(note), throwsFormatException);
  });
}
