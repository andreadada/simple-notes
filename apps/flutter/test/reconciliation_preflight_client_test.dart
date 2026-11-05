import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/reconciliation_preflight_client.dart';
import 'package:simple_notes/data/restore_cloud_inventory.dart';

void main() {
  const note = '10000000-0000-4000-8000-000000000001';
  const task = '10000000-0000-4000-8000-000000000002';

  RestoreServerInventory inventory() => const RestoreServerInventory(91, {
    'note:$note': RestoreInventoryRevision(
      version: 4, deleted: false, changeId: 80,
    ),
    'task:$task': RestoreInventoryRevision(
      version: 6, deleted: true, changeId: 90,
    ),
  });

  Map<String, Object?> observation({
    int cursor = 91,
    int noteVersion = 4,
    bool noteMatches = true,
    bool cursorMatches = true,
    bool consistent = true,
  }) => {
    'cursor': cursor,
    'cursorMatches': cursorMatches,
    'consistent': consistent,
    'items': [
      {
        'entityType': 'note', 'entityId': note,
        'changeId': 80, 'version': noteVersion,
        'deleted': false, 'matches': noteMatches,
      },
      {
        'entityType': 'task', 'entityId': task,
        'changeId': 90, 'version': 6,
        'deleted': true, 'matches': true,
      },
    ],
  };

  test('read-only POST checks entire inventory without sending note contents',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/sync/reconciliation/check');
      expect(request.headers['Authorization'], 'Bearer temporary-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'expectedCursor', 'items'});
      expect(body['expectedCursor'], 91);
      final items = body['items'] as List;
      expect(items.length, 2);
      expect(items[0]['entityId'], note);
      expect(items[1]['entityId'], task);
      expect(request.body, isNot(contains('PRIVATE-NOTE-BODY')));
      expect(request.body, isNot(contains('password')));
      return http.Response(jsonEncode(observation()), 200);
    });
    addTearDown(client.close);
    final result = await const ReconciliationPreflightClient().inspect(
      client: client,
      apiBase: Uri.parse('https://notes.example'),
      accessToken: () async => 'temporary-token',
      inventory: inventory(),
    );
    expect(calls, 1);
    expect(result.consistent, isTrue);
    expect(result.checkedEntities, 2);
    expect(result.mismatchedEntities, 0);
    expect(result.canRestoreLive, isFalse);
    expect(result.canApplyDecisions, isFalse);
    expect(result.canWriteCloud, isFalse);
    expect(result.canReplayImportedOutbox, isFalse);
    expect(result.canResumeAutoSync, isFalse);
    expect(result.summary, isNot(contains('temporary-token')));
    expect(result.summary, isNot(contains(note)));
    expect(result.summary, contains('NON autorizza'));
  });

  test('changed revision or cursor is reported without authorizing a write',
      () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode(observation(
        cursor: 95, noteVersion: 5,
        noteMatches: false, cursorMatches: false, consistent: false,
      )),
      200,
    ));
    addTearDown(client.close);
    final result = await const ReconciliationPreflightClient().inspect(
      client: client,
      apiBase: Uri.parse('https://notes.example'),
      accessToken: () async => 'token',
      inventory: inventory(),
    );
    expect(result.consistent, isFalse);
    expect(result.cursorMatches, isFalse);
    expect(result.mismatchedEntities, 1);
    expect(result.canResumeAutoSync, isFalse);
  });

  test('incoherent server flags or payload are refused', () async {
    final responses = [
      observation(consistent: false),
      observation(noteVersion: 5),
      {...observation(), 'payload': 'PRIVATE'},
      {
        ...observation(),
        'items': [
          {
            ...((observation()['items'] as List).first as Map),
            'entityId': task,
          },
          (observation()['items'] as List).last,
        ],
      },
      {...observation(), 'cursor': 'unknown'},
    ];
    for (final response in responses) {
      final client = MockClient((request) async =>
          http.Response(jsonEncode(response), 200));
      try {
        await expectLater(
          const ReconciliationPreflightClient().inspect(
            client: client,
            apiBase: Uri.parse('https://notes.example'),
            accessToken: () async => 'token',
            inventory: inventory(),
          ),
          throwsFormatException,
        );
      } finally {
        client.close();
      }
    }
  });

  test('HTTP 404/401 is never considered verification', () async {
    for (final status in [401, 404, 409, 500]) {
      final client = MockClient((request) async =>
          http.Response('not supported', status));
      try {
        await expectLater(
          const ReconciliationPreflightClient().inspect(
            client: client,
            apiBase: Uri.parse('https://notes.example'),
            accessToken: () async => 'token',
            inventory: inventory(),
          ),
          throwsFormatException,
        );
      } finally {
        client.close();
      }
    }
  });

  test('invalid inventory and HTTP URL are rejected without network', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(jsonEncode(observation()), 200);
    });
    addTearDown(client.close);
    final overLimit = RestoreServerInventory(200, {
      for (var i = 0; i < 101; i++)
        'note:10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}':
            const RestoreInventoryRevision(
          version: 0, deleted: false, changeId: 1,
        ),
    });
    for (final (base, data) in [
      (Uri.parse('http://public.example'), inventory()),
      (Uri.parse('https://notes.example'),
        const RestoreServerInventory(0, {})),
      (Uri.parse('https://notes.example'), overLimit),
      (Uri.parse('https://notes.example'),
        const RestoreServerInventory(8, {
          'note:invalid-id': RestoreInventoryRevision(
            version: 1, deleted: false, changeId: 3,
          ),
        })),
    ]) {
      await expectLater(
        const ReconciliationPreflightClient().inspect(
          client: client,
          apiBase: base,
          accessToken: () async => 'token',
          inventory: data,
        ),
        throwsFormatException,
      );
    }
    expect(calls, 0);
  });

  test('missing token prevents a network request', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(jsonEncode(observation()), 200);
    });
    addTearDown(client.close);
    await expectLater(
      const ReconciliationPreflightClient().inspect(
        client: client,
        apiBase: Uri.parse('https://notes.example'),
        accessToken: () async => '',
        inventory: inventory(),
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });
}
