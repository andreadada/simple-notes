import 'dart:convert';
import 'package:http/http.dart' as http;

/// Calendar grants are independent from Google sign-in. The provider tokens
/// never leave the backend; only the Simple Notes JWT is sent here.
class CalendarCloudException implements Exception {
  const CalendarCloudException(this.status);
  final int status;
}

class CalendarCloudProvider {
  const CalendarCloudProvider(this.provider, this.available, this.connected);
  final String provider;
  final bool available, connected;
  factory CalendarCloudProvider.parse(Object? raw) {
    if (raw is! Map<String,dynamic> ||
        !const {'google','microsoft'}.contains(raw['provider']) ||
        raw['available'] is! bool || raw['connected'] is! bool) {
      throw const FormatException('Stato calendario non valido');
    }
    return CalendarCloudProvider(raw['provider'] as String,
      raw['available'] as bool, raw['connected'] as bool);
  }
}

class CalendarCloudEvent {
  const CalendarCloudEvent({required this.id,required this.title,
    required this.source,this.startDay,this.endDay,this.startUtc,this.endUtc});
  final String id,title,source;
  final String? startDay,endDay;
  final DateTime? startUtc,endUtc;
  factory CalendarCloudEvent.parse(Object? raw) {
    if(raw is! Map<String,dynamic> || raw['id'] is! String ||
       (raw['id'] as String).isEmpty ||
       raw['title'] is! String || raw['source'] is! String ||
       (raw['startDay'] != null && raw['startDay'] is! String) ||
       (raw['endDay'] != null && raw['endDay'] is! String) ||
       (raw['startUtc'] != null && raw['startUtc'] is! String) ||
       (raw['endUtc'] != null && raw['endUtc'] is! String)) {
      throw const FormatException('Evento provider non valido');
    }
    final a=raw['startDay'] as String?, b=raw['endDay'] as String?;
    final start=raw['startUtc']==null ? null :
        DateTime.parse(raw['startUtc'] as String).toUtc();
    final end=raw['endUtc']==null ? null :
        DateTime.parse(raw['endUtc'] as String).toUtc();
    if(a!=null) {
      if(b==null || start!=null || end!=null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(a) ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(b) ||
          b.compareTo(a)<=0) {
        throw const FormatException('Intervallo evento non valido');
      }
    } else if(b!=null || start==null || end==null || !end.isAfter(start)) {
      throw const FormatException('Intervallo evento non valido');
    }
    return CalendarCloudEvent(id:raw['id'] as String,
      title:raw['title'] as String,source:raw['source'] as String,
      startDay:a,endDay:b,startUtc:start,endUtc:end);
  }
}

class CalendarCloudPage {
  const CalendarCloudPage(this.events,this.truncated);
  final List<CalendarCloudEvent> events;
  final bool truncated;
  factory CalendarCloudPage.parse(Object? raw) {
    if(raw is! Map<String,dynamic> || raw['events'] is! List ||
       raw['truncated'] is! bool || (raw['events'] as List).length>100) {
      throw const FormatException('Risposta calendario non valida');
    }
    return CalendarCloudPage((raw['events'] as List).map(CalendarCloudEvent.parse)
        .toList(growable:false),raw['truncated'] as bool);
  }
}

class CalendarCloudApi {
  CalendarCloudApi({required this.baseUrl,required this.tokenProvider,
    http.Client? client}) :
      _client=client??http.Client(),_ownsClient=client==null;
  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client _client;
  final bool _ownsClient;
  void close(){if(_ownsClient)_client.close();}

  Uri _uri(String path,[Map<String,String>? query]) {
    final base=Uri.parse(baseUrl);
    if(!(base.scheme=='https' || (base.scheme=='http' &&
         const {'localhost','127.0.0.1','10.0.2.2'}.contains(base.host))) ||
       base.host.isEmpty || base.userInfo.isNotEmpty ||
       base.hasQuery || base.hasFragment ||
       (base.path.isNotEmpty && base.path!='/')) {
      throw const FormatException('Endpoint cloud non sicuro');
    }
    return base.replace(path:'/api/v1/calendars$path',queryParameters:query);
  }

  Future<Object?> _call(String method,String path,
      [Map<String,String>? query]) async {
    final uri=_uri(path,query);
    final jwt=await tokenProvider();
    if(jwt.isEmpty)throw StateError('Sessione cloud assente');
    final request=http.Request(method,uri)..followRedirects=false
      ..headers.addAll({'Authorization':'Bearer $jwt','Accept':'application/json'});
    final stream=await _client.send(request).timeout(const Duration(seconds:20));
    if(stream.contentLength!=null && stream.contentLength!>256*1024) {
      throw const FormatException('Risposta troppo grande');
    }
    final result=await http.Response.fromStream(stream);
    if(result.statusCode<200 || result.statusCode>=300) {
      throw CalendarCloudException(result.statusCode);
    }
    if(method=='DELETE')return null;
    if(result.bodyBytes.length>256*1024)throw const FormatException('Risposta troppo grande');
    return jsonDecode(result.body);
  }

  Future<List<CalendarCloudProvider>> status() async {
    final raw=await _call('GET','');
    if(raw is! List || raw.length!=2)throw const FormatException('Provider non validi');
    return raw.map(CalendarCloudProvider.parse).toList(growable:false);
  }

  Future<Uri> authorize(String provider) async {
    if(!const {'google','microsoft'}.contains(provider)) {
      throw const FormatException('Provider non valido');
    }
    final raw=await _call('POST','/$provider/authorize');
    if(raw is! Map<String,dynamic> || raw['authorizationUrl'] is! String) {
      throw const FormatException('URL OAuth non valido');
    }
    final uri=Uri.parse(raw['authorizationUrl'] as String);
    if(uri.scheme!='https' || uri.userInfo.isNotEmpty || uri.hasFragment ||
        uri.host != (provider=='google'
          ? 'accounts.google.com' : 'login.microsoftonline.com')) {
      throw const FormatException('Destinazione OAuth non consentita');
    }
    return uri;
  }

  Future<void> disconnect(String provider) async {
    if(!const {'google','microsoft'}.contains(provider)) {
      throw const FormatException('Provider non valido');
    }
    await _call('DELETE','/$provider');
  }

  Future<CalendarCloudPage> events(String provider,
      DateTime start,DateTime end) async {
    if(!const {'google','microsoft'}.contains(provider) ||
       !end.isAfter(start) || end.difference(start)>const Duration(days:31)) {
      throw const FormatException('Intervallo calendario non valido');
    }
    return CalendarCloudPage.parse(await _call('GET','/$provider/events',{
      'start':start.toUtc().toIso8601String(),
      'end':end.toUtc().toIso8601String(),
    }));
  }
}
