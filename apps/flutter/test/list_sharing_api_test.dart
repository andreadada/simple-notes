import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/list_sharing_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const listId = '11111111-2222-4333-8444-555555555555';
  const memberId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
  const inviteId = '99999999-8888-4777-8666-555555555555';
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';
  final ticket = {
    'id':inviteId, 'token':token, 'expiresAt':'2026-11-18T12:00:00Z',
  };
  final shared = {
    'id':listId, 'title':'Squadra', 'role':'VIEWER',
    'updatedAt':'2026-11-11T12:00:00Z',
  };

  test('token only travels in POST body; requests keep JWT on API origin',
      () async {
    final seen = <String>[];
    final client = MockClient((request) async {
      expect(request.url.host,'api.example');
      expect(request.headers['Authorization'],'Bearer TEST-ACCESS-JWT');
      expect(request.followRedirects,isFalse);
      expect(request.url.toString(),isNot(contains(token)));
      expect(request.url.path,startsWith('/api/v1/sharing/'));
      seen.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/invitations/accept')) {
        expect(request.method,'POST');
        expect(jsonDecode(request.body),{'token':token});
        return http.Response(jsonEncode(shared),200);
      }
      if (request.method=='POST' &&
          request.url.path.endsWith('/invitations')) {
        expect(request.body,isEmpty);
        return http.Response(jsonEncode(ticket),201);
      }
      if (request.method=='GET' &&
          request.url.path.endsWith('/snapshot')) {
        expect(request.url.queryParameters['offset'],'0');
        return http.Response(jsonEncode({
          'listId':listId,'title':'Squadra','readOnly':true,
          'nextOffset':null,'tasks':[
            {'id':memberId,'title':'Preparare report',
              'description':'Dettagli','completedAt':null,
              'version':3,'priority':1},
          ],
        }),200);
      }
      if (request.method=='GET' && request.url.path.endsWith('/members')) {
        return http.Response(jsonEncode([
          {'id':memberId,'displayName':'Amico','acceptedAt':
            '2026-11-11T10:00:00Z'},
        ]),200);
      }
      if (request.method=='GET' && request.url.path.endsWith('/invitations')) {
        return http.Response(jsonEncode([
          {'id':inviteId,'expiresAt':'2026-11-18T12:00:00Z'},
        ]),200);
      }
      if (request.method=='GET' && request.url.path.endsWith('/lists')) {
        return http.Response(jsonEncode([shared]),200);
      }
      if (request.method=='DELETE') return http.Response('',204);
      return http.Response('unexpected',500);
    });
    final api=ListSharingApi(baseUrl:'https://api.example',
        tokenProvider:() async =>'TEST-ACCESS-JWT',client:client);
    expect((await api.sharedLists()).single.title,'Squadra');
    final issued=await api.invite(listId);
    expect(issued.token,token);
    expect((await api.accept(token)).role,'VIEWER');
    final snapshot=await api.snapshot(listId);
    expect(snapshot.tasks.single.title,'Preparare report');
    expect(snapshot.nextOffset,isNull);
    expect((await api.members(listId)).single.id,memberId);
    expect((await api.pending(listId)).single.id,inviteId);
    await api.revokeInvitation(listId,inviteId);
    await api.revokeMember(listId,memberId);
    await api.leave(listId);
    expect(seen.length,9);
  });

  test('backend unavailable, replay conflict and redirect are explicit',
      () async {
    for (final status in [302,404,409,503]) {
      final api=ListSharingApi(baseUrl:'https://api.example',
        tokenProvider:() async =>'token',
        client:MockClient((_) async => http.Response('',status)));
      await expectLater(api.sharedLists(),throwsA(
        isA<ListSharingHttpException>().having(
          (e)=>e.status,'status',status)));
    }
    final api=ListSharingApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'token',
      client:MockClient((_) async => fail('invalid code must not call HTTP')));
    await expectLater(api.accept('short'),throwsFormatException);
    await expectLater(api.snapshot(listId,offset:-1),throwsFormatException);
    await expectLater(api.snapshot(listId,offset:10001),throwsFormatException);
  });

  test('EDITOR role, version CAS and role updates use dedicated JWT routes',
      () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      expect(request.url.scheme,'https');
      expect(request.url.host,'api.example');
      expect(request.headers['Authorization'],'Bearer TEST-JWT');
      expect(request.followRedirects,isFalse);
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'PUT') {
        expect(request.url.path,
          '/api/v1/sharing/lists/$listId/members/$memberId/role');
        expect(jsonDecode(request.body), {'role':'EDITOR'});
        return http.Response(jsonEncode({
          'id':memberId,'displayName':'Collaboratore','role':'EDITOR',
        }),200);
      }
      if (request.method == 'PATCH') {
        expect(request.url.path,
          '/api/v1/sharing/lists/$listId/tasks/$memberId');
        expect(request.url.queryParameters,isEmpty);
        final body=jsonDecode(request.body);
        expect(body['expectedVersion'],4);
        expect(body['title'],'Titolo aggiornato');
        expect(body['completed'],true);
        expect(body.containsKey('listId'),isFalse);
        expect(body.containsKey('ownerId'),isFalse);
        return http.Response(jsonEncode({'version':5,'changeId':133}),200);
      }
      return http.Response('',404);
    });
    final api=ListSharingApi(
      baseUrl:'https://api.example',tokenProvider:() async =>'TEST-JWT',
      client:client);
    final changed=await api.changeRole(listId,memberId,'EDITOR');
    expect(changed.role,'EDITOR');
    final next=await api.editTask(listId,memberId,
      expectedVersion:4,title:'Titolo aggiornato',completed:true);
    expect(next,5);
    expect(calls,[
      'PUT /api/v1/sharing/lists/$listId/members/$memberId/role',
      'PATCH /api/v1/sharing/lists/$listId/tasks/$memberId',
    ]);
    final preview=SharedTaskPreview.parse({
      'id':memberId,'title':'Titolo aggiornato',
      'description':'Dettagli','completedAt':null,
      'version':5,'priority':3,
    });
    expect(preview.version,5);
    expect(preview.priority,3);
    final snap=SharedSnapshot.parse({
      'listId':listId,'title':'Squadra','readOnly':false,
      'nextOffset':null,'tasks':[{
        'id':memberId,'title':'Titolo aggiornato',
        'description':'Dettagli','completedAt':null,
        'version':5,'priority':3,
      }],
    });
    expect(snap.readOnly,isFalse);
    expect(snap.tasks.single.version,5);
    expect(SharedTaskList.parse({
      'id':listId,'title':'Squadra','role':'EDITOR',
    }).role,'EDITOR');
  });

  test('EDITOR rejects bad edits locally and surfaces 409 without retry',
      () async {
    var requests=0;
    final api=ListSharingApi(
      baseUrl:'https://api.example',tokenProvider:() async =>'token',
      client:MockClient((request) async {
        requests++;
        return http.Response('',409);
      }));
    await expectLater(api.editTask(listId,memberId,
      expectedVersion:-1,title:'X'),throwsFormatException);
    await expectLater(api.editTask(listId,memberId,
      expectedVersion:1),throwsFormatException);
    await expectLater(api.editTask(listId,memberId,
      expectedVersion:1,title:'  '),throwsFormatException);
    await expectLater(api.editTask(listId,memberId,
      expectedVersion:1,priority:8),throwsFormatException);
    await expectLater(api.changeRole(listId,memberId,'ADMIN'),
      throwsFormatException);
    expect(requests,0);
    await expectLater(api.editTask(listId,memberId,
      expectedVersion:5,completed:true),
      throwsA(isA<ListSharingHttpException>().having(
        (e)=>e.status,'status',409)));
    expect(requests,1);
  });

  test('validation rejects malformed snapshots and unsafe API addresses',
      () async {
    expect(()=>SharedSnapshot.parse({
      'listId':listId,'title':'X','readOnly':'not-a-bool','tasks':[],
    }),throwsFormatException);
    expect(()=>SharedSnapshot.parse({
      'listId':listId,'title':'X','readOnly':true,
      'tasks':List.generate(51,(_)=>{}),
    }),throwsFormatException);
    expect(()=>SharedTaskList.parse({
      'id':listId,'title':'X','role':'ADMIN',
    }),throwsFormatException);
    expect(()=>ListShareInvitation.parse({
      'id':inviteId,'token':'short','expiresAt':'2026-11-18T12:00:00Z',
    }),throwsFormatException);
    for (final url in [
      'http://remote.example',
      'https://user:password@api.example',
      'https://api.example/unsafe-prefix',
      'https://api.example/?private=1',
    ]) {
      final api=ListSharingApi(baseUrl:url,
          tokenProvider:() async =>'token',
          client:MockClient((_) async => fail('should reject origin')));
      await expectLater(api.sharedLists(),throwsFormatException);
    }
  });
}
