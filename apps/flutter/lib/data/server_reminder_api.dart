import 'dart:convert';
import 'package:http/http.dart' as http;

/// Opt-in shared server inbox; not OS push or a task mutation.
class ServerReminderHttpException implements Exception {
  const ServerReminderHttpException(this.status);
  final int status;
}

class ServerReminderPreferences {
  const ServerReminderPreferences(this.enabled, this.leadMinutes, this.version);
  final bool enabled;
  final int leadMinutes, version;
  factory ServerReminderPreferences.parse(Object? data) {
    if (data is! Map<String,dynamic> || data['enabled'] is! bool ||
        data['leadMinutes'] is! int || data['version'] is! int ||
        !const {0,5,15,30,60,1440}.contains(data['leadMinutes']) ||
        (data['version'] as int)<0) {
      throw const FormatException('Preferenze promemoria server non valide.');
    }
    return ServerReminderPreferences(data['enabled'] as bool,
      data['leadMinutes'] as int, data['version'] as int);
  }
}

class ServerReminderOccurrence {
  const ServerReminderOccurrence({required this.id,required this.taskId,
    required this.title,required this.dueAt,required this.fireAt,
    required this.leadMinutes});
  final String id,taskId,title;
  final DateTime dueAt,fireAt;
  final int leadMinutes;
  factory ServerReminderOccurrence.parse(Object? data) {
    if (data is! Map<String,dynamic> ||
        data['id'] is! String || data['taskId'] is! String ||
        data['title'] is! String || data['dueAt'] is! String ||
        data['fireAt'] is! String || data['leadMinutes'] is! int ||
        !const {0,5,15,30,60,1440}.contains(data['leadMinutes'])) {
      throw const FormatException('Occorrenza promemoria non valida.');
    }
    return ServerReminderOccurrence(
      id:data['id'] as String,taskId:data['taskId'] as String,
      title:data['title'] as String,
      dueAt:DateTime.parse(data['dueAt'] as String).toUtc(),
      fireAt:DateTime.parse(data['fireAt'] as String).toUtc(),
      leadMinutes:data['leadMinutes'] as int);
  }
}

class ServerReminderApi {
  ServerReminderApi({required this.baseUrl,required this.tokenProvider,
      http.Client? client}) :
      _client=client??http.Client(),_ownsClient=client==null;

  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final http.Client _client;
  final bool _ownsClient;
  void close(){if(_ownsClient)_client.close();}

  Uri _uri(String path) {
    final base=Uri.parse(baseUrl);
    if (!(base.scheme=='https' || (base.scheme=='http' &&
          const {'127.0.0.1','localhost','10.0.2.2'}.contains(base.host))) ||
        base.host.isEmpty || base.userInfo.isNotEmpty ||
        base.hasQuery || base.hasFragment ||
        (base.path.isNotEmpty && base.path!='/')) {
      throw const FormatException('Endpoint promemoria server non sicuro.');
    }
    return base.replace(path:'/api/v1/reminders/server$path');
  }

  Future<Object?> _call(String method,String path,{Object? body}) async {
    final uri=_uri(path);
    final jwt=await tokenProvider();
    if(jwt.isEmpty)throw StateError('Accesso cloud non disponibile.');
    final request=http.Request(method,uri)..followRedirects=false
      ..headers.addAll({'Authorization':'Bearer $jwt',
        'Accept':'application/json',
        if(body!=null)'Content-Type':'application/json'});
    if(body!=null)request.body=jsonEncode(body);
    final stream=await _client.send(request)
      .timeout(const Duration(seconds:15));
    if(stream.contentLength!=null && stream.contentLength!>64*1024) {
      throw const FormatException('Risposta cloud troppo grande.');
    }
    final response=await http.Response.fromStream(stream);
    if(response.statusCode<200 || response.statusCode>=300) {
      throw ServerReminderHttpException(response.statusCode);
    }
    if(method=='POST')return null;
    if(response.bodyBytes.length>64*1024) {
      throw const FormatException('Risposta cloud troppo grande.');
    }
    return jsonDecode(response.body);
  }

  Future<ServerReminderPreferences> preferences() async =>
      ServerReminderPreferences.parse(await _call('GET','/preferences'));

  Future<ServerReminderPreferences> configure({
      required bool enabled,required int leadMinutes,
      required int expectedVersion}) async {
    if(!const {0,5,15,30,60,1440}.contains(leadMinutes) ||
       expectedVersion<0)throw const FormatException('Anticipo non valido.');
    return ServerReminderPreferences.parse(await _call('PUT','/preferences',
      body:{'enabled':enabled,'leadMinutes':leadMinutes,
            'expectedVersion':expectedVersion}));
  }

  Future<List<ServerReminderOccurrence>> unread() async {
    final data=await _call('GET','/occurrences');
    if(data is! List || data.length>50) {
      throw const FormatException('Inbox promemoria server non valida.');
    }
    return data.map(ServerReminderOccurrence.parse).toList(growable:false);
  }

  Future<void> acknowledge(String id) async {
    if(!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) {
      throw const FormatException('ID promemoria non valido.');
    }
    await _call('POST','/occurrences/$id/ack');
  }
}
