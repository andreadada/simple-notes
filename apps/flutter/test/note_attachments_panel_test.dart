import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/note_attachment_api.dart';
import 'package:simple_notes/ui/note_attachments_panel.dart';
import 'package:simple_notes/ui/notes_theme.dart';

void main() {
  const note = '7e4b1e49-d176-4ec6-b043-5f9703339d7a';
  const file = '97f55e73-d96b-40a6-badd-0213acd5f2a0';

  Future<void> mount(WidgetTester tester, NoteAttachmentApi api,
      Future<bool> Function(String) guard) async {
    await tester.pumpWidget(MaterialApp(home: FTheme(
      data: NotesTheme.forPlatform(TargetPlatform.windows),
      child: Scaffold(body: NoteAttachmentsPanel(
        ownerId: 'owner-1', noteId: note, api: api, ownerMatches: guard,
      )),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('lists ready attachments without modifying them', (tester) async {
    var reads = 0;
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test', tokenProvider: () async => 'token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        reads++;
        return http.Response(jsonEncode([
          {'id': file, 'name': 'appunti.pdf', 'contentType': 'application/pdf',
            'sizeBytes': 1024},
        ]), 200);
      }),
    );
    await mount(tester, api, (_) async => true);
    expect(find.text('appunti.pdf'), findsOneWidget);
    expect(reads, 1);
  });

  testWidgets('delete requires explicit confirmation', (tester) async {
    var deletes = 0;
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test', tokenProvider: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          deletes++;
          return http.Response('', 204);
        }
        return http.Response(jsonEncode([
          {'id': file, 'name': 'appunti.pdf', 'contentType': 'application/pdf',
            'sizeBytes': 1024},
        ]), 200);
      }),
    );
    await mount(tester, api, (_) async => true);
    await tester.tap(find.byKey(const Key('delete-note-attachment-$file')));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.byKey(const Key('confirm-delete-attachment')));
    await tester.pumpAndSettle();
    expect(deletes, 1);
  });

  testWidgets('owner mismatch performs zero network requests', (tester) async {
    var requests = 0;
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test', tokenProvider: () async => 'token',
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await mount(tester, api, (_) async => false);
    expect(requests, 0);
    expect(find.byKey(const Key('note-attachment-error')), findsOneWidget);
  });

  testWidgets('server without S3 shows clear error, no lost local data',
      (tester) async {
    final api = NoteAttachmentApi(
      baseUrl: 'https://api.test', tokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await mount(tester, api, (_) async => true);
    expect(find.textContaining('non ancora configurati'), findsOneWidget);
  });
}
