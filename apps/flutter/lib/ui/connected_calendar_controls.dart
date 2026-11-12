import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/cloud_auth.dart';
import '../data/connected_calendar_api.dart';
import 'ics_calendar.dart';
import 'notes_dialogs.dart';

/// Ephemeral, account-guarded provider events; never copied into SQLite,
/// SharedPreferences, personal sync/outbox or encrypted backup.
class ConnectedCalendarControls extends ConsumerStatefulWidget {
  const ConnectedCalendarControls({super.key, required this.ownerId,
    required this.day, required this.onChanged, this.api});
  final String? ownerId;
  final DateTime day;
  final ValueChanged<List<IcsEvent>> onChanged;
  final CalendarCloudApi? api;
  @override
  ConsumerState<ConnectedCalendarControls> createState() =>
    _ConnectedCalendarControlsState();
}

class _ConnectedCalendarControlsState
    extends ConsumerState<ConnectedCalendarControls> {
  late final CalendarCloudApi _api;
  late final bool _ownsApi;
  List<CalendarCloudProvider> _providers=const [];
  bool _busy=false,_loaded=false;
  String? _error;
  int _epoch=0;

  @override
  void initState() {
    super.initState();
    _ownsApi=widget.api==null;
    _api=widget.api ?? CalendarCloudApi(baseUrl:CloudConfig.apiBaseUrl,
      tokenProvider:()=>ref.read(cloudAuthProvider.notifier).validAccessToken());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted)unawaited(_refresh());
    });
  }

  @override
  void didUpdateWidget(covariant ConnectedCalendarControls old) {
    super.didUpdateWidget(old);
    if(old.ownerId==widget.ownerId)return;
    _epoch++;
    _providers=const [];
    _loaded=false;
    _busy=false;
    _error=null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(!mounted)return;
      widget.onChanged(const []);
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _epoch++;
    if(_ownsApi)_api.close();
    super.dispose();
  }

  bool _same(String owner,int epoch) =>
    mounted && epoch==_epoch && widget.ownerId==owner &&
    ref.read(cloudAuthProvider).authenticated &&
    ref.read(cloudAuthProvider).userId==owner;

  Future<void> _refresh() async {
    final owner=widget.ownerId;
    if(owner==null || !CloudConfig.enabled ||
      !ref.read(cloudAuthProvider).authenticated ||
      ref.read(cloudAuthProvider).userId!=owner || _busy)return;
    final epoch=_epoch;
    setState((){_busy=true;_error=null;});
    try {
      final providers=await _api.status();
      if(!_same(owner,epoch))return;
      final start=DateTime(widget.day.year,widget.day.month,widget.day.day)
        .subtract(const Duration(days:14));
      final end=start.add(const Duration(days:30));
      final events=<IcsEvent>[];
      for(final p in providers.where((p)=>p.connected && p.available)) {
        if(!_same(owner,epoch))return;
        final page=await _api.events(p.provider,start,end);
        for(final e in page.events) {
          events.add(IcsEvent(uid:e.id,title:e.title,source:e.source,
            startDay:e.startDay,endDay:e.endDay,
            startUtc:e.startUtc,endUtc:e.endUtc));
        }
      }
      if(!_same(owner,epoch))return;
      setState((){_providers=providers;_loaded=true;});
      widget.onChanged(List.unmodifiable(events));
    } catch(e) {
      if(_same(owner,epoch))setState(() {
        _loaded=true;
        _error=e is CalendarCloudException && e.status==404
          ? 'Aggiorna il backend per i calendari cloud.'
          : 'Aggiornamento calendario fallito; eventi precedenti conservati.';
      });
    } finally {
      if(_same(owner,epoch))setState(()=>_busy=false);
    }
  }

  Future<void> _connect(String provider) async {
    final owner=widget.ownerId;
    if(owner==null || !_same(owner,_epoch) || _busy)return;
    final epoch=_epoch;
    setState((){_busy=true;_error=null;});
    try {
      final uri=await _api.authorize(provider);
      if(!_same(owner,epoch))return;
      if(!await launchUrl(uri,mode:LaunchMode.externalApplication)) {
        throw StateError('Browser non disponibile');
      }
      if(_same(owner,epoch)) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content:Text('Completa il consenso nel browser, poi premi Aggiorna.')));
      }
    } catch(_) {
      if(_same(owner,epoch))setState(
        ()=>_error='Consenso provider non avviato.');
    } finally {
      if(_same(owner,epoch))setState(()=>_busy=false);
    }
  }

  Future<void> _disconnect(String provider) async {
    final owner=widget.ownerId;
    if(owner==null || !_same(owner,_epoch) || _busy)return;
    final ok=await showFDialog<bool>(
      context:context,
      builder:(ctx,style,animation)=>NotesDialog(
        style:style,animation:animation,
        title:const Text('Scollega calendario'),
        body:const Text('Il collegamento sarà eliminato dal server. '
          'Nessuna attività verrà modificata. Per revocare anche il consenso '
          'del provider usa le impostazioni di sicurezza del tuo account.'),
        actions:[
          FButton(variant:FButtonVariant.ghost,
            onPress:()=>Navigator.pop(ctx,false),
            child:const Text('Annulla')),
          FButton(onPress:()=>Navigator.pop(ctx,true),
            child:const Text('Scollega')),
        ],
      ),
    );
    if(ok!=true || !_same(owner,_epoch))return;
    final epoch=_epoch;
    setState((){_busy=true;_error=null;});
    try {
      await _api.disconnect(provider);
      if(!_same(owner,epoch))return;
      setState(()=>_busy=false);
      await _refresh();
    } catch(_) {
      if(_same(owner,epoch))setState(()=>_error='Scollegamento fallito.');
    } finally {
      if(_same(owner,epoch))setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session=ref.watch(cloudAuthProvider);
    if(widget.ownerId==null || !CloudConfig.enabled ||
       !session.authenticated || session.userId!=widget.ownerId) {
      return const SizedBox.shrink();
    }
    String label(String provider) =>
      provider=='google'?'Google Calendar':'Outlook';
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(spacing:8,runSpacing:6,crossAxisAlignment:WrapCrossAlignment.center,
        children:[
          const Text('Calendari collegati',
            style:TextStyle(fontWeight:FontWeight.w600)),
          FButton(key:const Key('calendar-cloud-refresh'),
            variant:FButtonVariant.ghost,mainAxisSize:MainAxisSize.min,
            onPress:_busy?null:()=>unawaited(_refresh()),
            child:Text(_busy?'Aggiornamento...':'Aggiorna')),
          if(_loaded)
            for(final p in _providers)
              FButton(key:Key('calendar-cloud-' + p.provider),
                mainAxisSize:MainAxisSize.min,
                variant:FButtonVariant.outline,
                onPress:_busy || (!p.available && !p.connected)
                  ? null : p.connected
                    ? ()=>unawaited(_disconnect(p.provider))
                    : ()=>unawaited(_connect(p.provider)),
                child:Text(label(p.provider) +
                  (p.connected?' · Scollega':' · Collega'))),
        ],
      ),
      if(_error!=null)Padding(
        padding:const EdgeInsets.only(top:6),
        child:Text(_error!,style:TextStyle(
          color:Theme.of(context).colorScheme.error,fontSize:12))),
      if(_providers.any((p)=>p.connected))
        const Padding(padding:EdgeInsets.only(top:4),
          child:Text('Eventi in sola lettura · aggiornamento manuale · '
            'nessun salvataggio sul dispositivo.',
            style:TextStyle(fontSize:11))),
    ]);
  }
}
