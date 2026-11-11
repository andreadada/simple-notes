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
  const listId='11111111-2222-4333-8444-555555555555';
  const taskId='aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

  testWidgets('EDITOR modifies task title inline with version CAS and refresh',
      (tester) async {
    var version=4;
    var title='Titolo originale';
    var edits=0;
    final client=MockClient((req) async {
      expect(req.headers['Authorization'],'Bearer EDITOR-JWT');
      if (req.url.path=='/api/v1/sharing/lists') {
        return http.Response(jsonEncode([
          {'id':listId,'title':'Lista del gruppo','role':'EDITOR'},
        ]),200);
      }
      if (req.url.path=='/api/v1/sharing/lists/$listId/snapshot') {
        return http.Response(jsonEncode({
          'listId':listId,'title':'Lista del gruppo','readOnly':false,
          'tasks':[{
            'id':taskId,'title':title,'description':'Testo',
            'completedAt':null,'priority':1,'version':version,
          }],'nextOffset':null,
        }),200);
      }
      if (req.method=='PATCH' &&
          req.url.path=='/api/v1/sharing/lists/$listId/tasks/$taskId') {
        final body=jsonDecode(req.body);
        expect(body['expectedVersion'],4);
        expect(body['title'],'Titolo condiviso');
        expect(body['description'],'Testo');
        expect(body.containsKey('listId'),isFalse);
        edits++;
        version=5;
        title=body['title'] as String;
        return http.Response(jsonEncode({'version':5,'changeId':17}),200);
      }
      return http.Response('',404);
    });
    final api=ListSharingApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'EDITOR-JWT',client:client);
    await tester.pumpWidget(MaterialApp(home:FTheme(
      data:NotesTheme.forPlatform(TargetPlatform.windows),
      child:Scaffold(body:ListSharingBoard(
        ownerId:'member',ownedLists:const [],baseUrl:'https://api.example',
        tokenProvider:() async =>'EDITOR-JWT',
        ownerMatches:(_) async=>true,api:api,
      )),
    )));
    await tester.pumpAndSettle();
    final open=find.byKey(const Key('share-open-$listId'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    final edit=find.byKey(const Key('share-edit-$taskId'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-edit-title')),findsOneWidget);
    await tester.enterText(find.byKey(const Key('share-edit-title')),
      'Titolo condiviso');
    final save=find.byKey(const Key('share-save-task'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(edits,1);
    expect(title,'Titolo condiviso');
    expect(version,5);
  });

  testWidgets('VIEWER never displays task mutation controls',
      (tester) async {
    final api=ListSharingApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'VIEWER-JWT',
      client:MockClient((req) async {
        if (req.url.path=='/api/v1/sharing/lists') {
          return http.Response(jsonEncode([
            {'id':listId,'title':'Lista letta','role':'VIEWER'},
          ]),200);
        }
        if (req.url.path.endsWith('/snapshot')) {
          return http.Response(jsonEncode({
            'listId':listId,'title':'Lista letta','readOnly':true,
            'nextOffset':null,'tasks':[{
              'id':taskId,'title':'Solo lettura','description':null,
              'completedAt':null,'priority':0,'version':2,
            }],
          }),200);
        }
        fail('VIEWER should not call any mutation route');
      }));
    await tester.pumpWidget(MaterialApp(home:FTheme(
      data:NotesTheme.forPlatform(TargetPlatform.windows),
      child:Scaffold(body:ListSharingBoard(
        ownerId:'viewer',ownedLists:const [],baseUrl:'https://api.example',
        tokenProvider:() async =>'VIEWER-JWT',
        ownerMatches:(_) async=>true,api:api,
      )),
    )));
    await tester.pumpAndSettle();
    final open=find.byKey(const Key('share-open-$listId'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-edit-$taskId')),findsNothing);
    expect(find.byKey(const Key('share-toggle-$taskId')),findsNothing);
  });
}
