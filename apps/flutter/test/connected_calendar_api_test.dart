import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_notes/data/connected_calendar_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider OAuth URL and events are JWT-only, redirect-free',() async {
    final calls=<String>[];
    final api=CalendarCloudApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'APP-JWT',
      client:MockClient((request) async {
        expect(request.url.host,'api.example');
        expect(request.headers['Authorization'],'Bearer APP-JWT');
        expect(request.followRedirects,isFalse);
        expect(request.url.path,startsWith('/api/v1/calendars'));
        calls.add('${request.method} ${request.url.path}');
        if(request.url.path.endsWith('/authorize')) {
          return http.Response(jsonEncode({'authorizationUrl':
            'https://accounts.google.com/o/oauth2/v2/auth?state=abc'}),200);
        }
        if(request.method=='DELETE')return http.Response('',204);
        if(request.url.path.endsWith('/events')) {
          expect(request.url.queryParameters['start'],isNotNull);
          expect(request.url.queryParameters['end'],isNotNull);
          return http.Response(jsonEncode({
            'provider':'google','truncated':false,
            'events':[{'id':'e1','title':'Meeting','source':'Google Calendar',
              'startDay':null,'endDay':null,
              'startUtc':'2026-11-12T10:00:00Z',
              'endUtc':'2026-11-12T10:30:00Z'}],
          }),200);
        }
        return http.Response(jsonEncode([
          {'provider':'google','available':true,'connected':true},
          {'provider':'microsoft','available':false,'connected':false},
        ]),200);
      }));
    expect((await api.status()).first.connected,isTrue);
    expect((await api.authorize('google')).host,'accounts.google.com');
    final page=await api.events('google',DateTime.utc(2026,11,12),
        DateTime.utc(2026,11,15));
    expect(page.events.single.title,'Meeting');
    expect(page.events.single.startUtc,DateTime.utc(2026,11,12,10));
    await api.disconnect('google');
    expect(calls.length,4);
  });

  test('unsafe OAuth URLs, redirects and malformed events rejected',() async {
    for(final url in [
      'https://evil.test/authorize',
      'http://accounts.google.com/authorize',
      'https://accounts.google.com.evil.test/authorize',
    ]) {
      final api=CalendarCloudApi(baseUrl:'https://api.example',
        tokenProvider:() async =>'APP-JWT',
        client:MockClient((_) async =>
          http.Response(jsonEncode({'authorizationUrl':url}),200)));
      await expectLater(api.authorize('google'),throwsFormatException);
    }
    final redirect=CalendarCloudApi(baseUrl:'https://api.example',
      tokenProvider:() async =>'APP-JWT',
      client:MockClient((_) async => http.Response('',302)));
    await expectLater(redirect.status(),throwsA(
      isA<CalendarCloudException>().having((e)=>e.status,'status',302)));
    final invalid=CalendarCloudApi(baseUrl:'https://api.example/path',
      tokenProvider:() async =>'APP-JWT',
      client:MockClient((_) async => fail('No HTTP permitted')));
    await expectLater(invalid.status(),throwsFormatException);
    await expectLater(invalid.events('google',DateTime.utc(2026,11,1),
      DateTime.utc(2026,12,3)),throwsFormatException);
    expect(()=>CalendarCloudEvent.parse({
      'id':'bad','title':'bad','source':'Google','startDay':'2026-11-12',
      'endDay':'2026-11-11','startUtc':null,'endUtc':null,
    }),throwsFormatException);
  });
}
