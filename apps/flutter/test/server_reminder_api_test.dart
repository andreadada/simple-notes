import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/server_reminder_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id='11111111-2222-4333-8444-555555555555';
  final preference={'enabled':true,'leadMinutes':15,'version':2};
  final item={'id':id,'taskId':'22222222-3333-4444-8555-666666666666',
    'title':'Appuntamento','dueAt':'2026-11-14T10:00:00Z',
    'fireAt':'2026-11-14T09:45:00Z','leadMinutes':15};

  test('JWT-only owner inbox, acknowledgment and versioned opt-in',() async {
    final requests=<String>[];
    final api=ServerReminderApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'APP-JWT',
      client:MockClient((req) async {
        expect(req.url.host,'api.example');
        expect(req.headers['Authorization'],'Bearer APP-JWT');
        expect(req.followRedirects,isFalse);
        expect(req.url.path,startsWith('/api/v1/reminders/server'));
        requests.add('${req.method} ${req.url.path}');
        if(req.method=='PUT'){
          expect(jsonDecode(req.body),{
            'enabled':true,'leadMinutes':15,'expectedVersion':1});
          return http.Response(jsonEncode(preference),200);
        }
        if(req.method=='POST')return http.Response('',204);
        if(req.url.path.endsWith('preferences')){
          return http.Response(jsonEncode(
            {'enabled':false,'leadMinutes':15,'version':1}),200);
        }
        return http.Response(jsonEncode([item]),200);
      }));
    expect((await api.preferences()).version,1);
    final saved=await api.configure(enabled:true,leadMinutes:15,
      expectedVersion:1);
    expect(saved.enabled,isTrue);
    expect(saved.version,2);
    expect((await api.unread()).single.title,'Appuntamento');
    await api.acknowledge(id);
    expect(requests.length,4);
  });

  test('reject redirects, invalid lead, unsafe origin and broken payload',
      () async {
    final badOrigin=ServerReminderApi(baseUrl:'https://api.example/path',
      tokenProvider:() async =>'APP-JWT',
      client:MockClient((_) async => fail('HTTP must not be reached')));
    await expectLater(badOrigin.preferences(),throwsFormatException);
    final redirect=ServerReminderApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'APP-JWT',
      client:MockClient((_) async => http.Response('',302)));
    await expectLater(redirect.unread(),throwsA(
      isA<ServerReminderHttpException>().having(
        (e)=>e.status,'status',302)));
    await expectLater(redirect.configure(enabled:true,
      leadMinutes:7,expectedVersion:0),throwsFormatException);
    await expectLater(redirect.acknowledge('INVALID'),throwsFormatException);
    expect(()=>ServerReminderPreferences.parse(
      {'enabled':true,'leadMinutes':25,'version':1}),throwsFormatException);
    expect(()=>ServerReminderOccurrence.parse(
      {...item,'fireAt':'not a date'}),throwsFormatException);
  });
}
