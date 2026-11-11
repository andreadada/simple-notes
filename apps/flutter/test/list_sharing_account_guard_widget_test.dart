import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/list_sharing_api.dart';
import 'package:simple_notes/ui/list_sharing_board.dart';
import 'package:simple_notes/ui/notes_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'late previous-account sharing response never appears in new session',
      (tester) async {
    final oldReply = Completer<http.Response>();
    final newReply = Completer<http.Response>();
    var calls = 0;
    final api = ListSharingApi(
      baseUrl: 'https://api.test',
      tokenProvider: () async => 'TEST-JWT',
      client: MockClient((request) {
        expect(request.url.path, '/api/v1/sharing/lists');
        expect(request.headers['Authorization'], 'Bearer TEST-JWT');
        calls++;
        return calls == 1 ? oldReply.future : newReply.future;
      }),
    );

    Widget app(String owner) => MaterialApp(
      home: FTheme(
        data: NotesTheme.forPlatform(TargetPlatform.windows),
        child: Scaffold(
          body: ListSharingBoard(
            ownerId: owner,
            ownedLists: const [],
            baseUrl: 'https://api.test',
            tokenProvider: () async => 'TEST-JWT',
            ownerMatches: (_) async => true,
            api: api,
          ),
        ),
      ),
    );

    await tester.pumpWidget(app('alice'));
    await tester.pump();
    expect(calls, 1);

    // Rebuild the SAME stateful widget without an owner-based key to ensure
    // the panel itself guards responses, not just its parent navigation.
    await tester.pumpWidget(app('bob'));
    await tester.pump();
    expect(calls, 2);

    newReply.complete(http.Response(jsonEncode([
      {'id': '22222222-2222-4222-8222-222222222222',
        'title': 'Solo Bob', 'role': 'VIEWER'},
    ]), 200));
    await tester.pumpAndSettle();
    expect(find.text('Solo Bob', skipOffstage: false), findsOneWidget);

    // The earlier response arrives after Bob's data and must be discarded.
    oldReply.complete(http.Response(jsonEncode([
      {'id': '11111111-1111-4111-8111-111111111111',
        'title': 'Privata Alice', 'role': 'VIEWER'},
    ]), 200));
    await tester.pumpAndSettle();
    expect(find.text('Solo Bob', skipOffstage: false), findsOneWidget);
    expect(find.text('Privata Alice', skipOffstage: false), findsNothing);
  });
}
