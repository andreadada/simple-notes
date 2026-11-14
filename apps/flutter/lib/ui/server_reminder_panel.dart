import 'dart:async';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../data/server_reminder_api.dart';

/// Opt-in shared inbox; not push. Requests and responses are account-guarded.
class ServerReminderPanel extends StatefulWidget {
  const ServerReminderPanel({super.key,required this.ownerId,
    required this.baseUrl,this.tokenProvider,this.ownerGuard,this.api});
  final String? ownerId;
  final String baseUrl;
  final Future<String> Function()? tokenProvider;
  final Future<bool> Function(String)? ownerGuard;
  final ServerReminderApi? api;
  @override
  State<ServerReminderPanel> createState()=>_ServerReminderPanelState();
}
class _ServerReminderPanelState extends State<ServerReminderPanel> {
  late final ServerReminderApi _api;
  late final bool _ownsApi;
  ServerReminderPreferences? _prefs;
  List<ServerReminderOccurrence> _unread=const [];
  bool _busy=false;
  String? _error;
  int _epoch=0;

  @override
  void initState() {
    super.initState();
    _ownsApi=widget.api==null;
    _api=widget.api??ServerReminderApi(baseUrl:widget.baseUrl,
      tokenProvider:widget.tokenProvider??() async =>'');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted)unawaited(_refresh());
    });
  }
  @override
  void didUpdateWidget(covariant ServerReminderPanel old) {
    super.didUpdateWidget(old);
    if(old.ownerId==widget.ownerId)return;
    _epoch++;
    _prefs=null;_unread=const [];_busy=false;_error=null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted)unawaited(_refresh());
    });
  }
  @override
  void dispose() {
    _epoch++;
    if(_ownsApi)_api.close();
    super.dispose();
  }
  Future<bool> _valid(String owner,int epoch) async {
    if(!mounted || widget.ownerId!=owner || _epoch!=epoch)return false;
    final guard=widget.ownerGuard;
    final ok=guard==null || await guard(owner);
    return ok && mounted && widget.ownerId==owner && _epoch==epoch;
  }
  Future<void> _refresh() async {
    final owner=widget.ownerId;
    if(owner==null || widget.baseUrl.isEmpty ||
       (widget.tokenProvider==null && widget.api==null) || _busy) { return; }
    final epoch=_epoch;
    if(!await _valid(owner,epoch))return;
    setState((){_busy=true;_error=null;});
    try {
      final prefs=await _api.preferences();
      if(!await _valid(owner,epoch))return;
      final rows=prefs.enabled
        ? await _api.unread():<ServerReminderOccurrence>[];
      if(!await _valid(owner,epoch))return;
      setState((){_prefs=prefs;_unread=rows;});
    }catch(e){
      if(await _valid(owner,epoch)) {
        setState(()=>_error=e is ServerReminderHttpException && e.status==404
          ? 'Aggiorna il backend per la inbox promemoria cloud.'
          : 'Impossibile aggiornare i promemoria cloud.');
      }
    }finally{
      if(await _valid(owner,epoch))setState(()=>_busy=false);
    }
  }
  Future<void> _configure({bool? enabled,int? leadMinutes}) async {
    final owner=widget.ownerId,prefs=_prefs;
    if(owner==null || prefs==null || _busy)return;
    final epoch=_epoch;
    if(!await _valid(owner,epoch))return;
    setState((){_busy=true;_error=null;});
    try{
      final next=await _api.configure(
        enabled:enabled??prefs.enabled,
        leadMinutes:leadMinutes??prefs.leadMinutes,
        expectedVersion:prefs.version);
      if(!await _valid(owner,epoch))return;
      setState((){_prefs=next;if(!next.enabled)_unread=const [];});
    }catch(e){
      if(await _valid(owner,epoch)) {
        setState(()=>_error=e is ServerReminderHttpException && e.status==409
          ? 'Impostazioni modificate altrove. Premi Aggiorna.'
          : 'Impostazioni non salvate.');
      }
    }finally{
      if(await _valid(owner,epoch))setState(()=>_busy=false);
    }
  }
  Future<void> _ack(String id) async {
    final owner=widget.ownerId;
    if(owner==null || _busy)return;
    final epoch=_epoch;
    if(!await _valid(owner,epoch))return;
    setState((){_busy=true;_error=null;});
    try{
      await _api.acknowledge(id);
      if(!await _valid(owner,epoch))return;
      setState(()=>_unread=_unread.where((e)=>e.id!=id).toList());
    }catch(_){
      if(await _valid(owner,epoch)) {
        setState(()=>_error='Conferma non salvata; aggiorna la inbox.');
      }
    }finally{
      if(await _valid(owner,epoch))setState(()=>_busy=false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if(widget.ownerId==null || widget.baseUrl.isEmpty ||
       (widget.tokenProvider==null && widget.api==null)) {
      return const SizedBox.shrink();
    }
    final prefs=_prefs;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Inbox promemoria sul server',
        style:TextStyle(fontWeight:FontWeight.w600)),
      const SizedBox(height:6),
      const Text('Facoltativa: scadenze con ora, visibili su tutti i '
        'dispositivi dopo Aggiorna. Conferma condivisa, senza push. '
        'Le notifiche locali restano indipendenti.',
        style:TextStyle(fontSize:12)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:6,children:[
        FButton(key:const Key('server-reminder-refresh'),
          mainAxisSize:MainAxisSize.min,variant:FButtonVariant.outline,
          onPress:_busy?null:()=>unawaited(_refresh()),
          child:Text(_busy?'Caricamento...':'Aggiorna')),
        if(prefs!=null)
          FButton(key:const Key('server-reminder-toggle'),
            mainAxisSize:MainAxisSize.min,variant:FButtonVariant.outline,
            onPress:_busy?null:()=>unawaited(
              _configure(enabled:!prefs.enabled)),
            child:Text(prefs.enabled?'Disattiva inbox':'Attiva inbox')),
      ]),
      if(prefs!=null && prefs.enabled)...[
        const SizedBox(height:8),
        Wrap(spacing:6,runSpacing:6,children:[
          for(final lead in const [0,5,15,30,60,1440])
            FButton(key:Key('server-reminder-lead-$lead'),
              mainAxisSize:MainAxisSize.min,
              variant:prefs.leadMinutes==lead
                ? FButtonVariant.primary:FButtonVariant.outline,
              onPress:_busy?null:()=>unawaited(
                _configure(leadMinutes:lead)),
              child:Text(lead==1440?'1 giorno':'$lead min')),
        ]),
        const SizedBox(height:12),
        if(_unread.isEmpty)
          const Text('Nessuna occorrenza da confermare.',
            style:TextStyle(fontSize:12)),
        for(final item in _unread)
          Padding(padding:const EdgeInsets.only(bottom:8),
            child:FCard(child:Row(children:[
              Expanded(child:Text(item.title,maxLines:2,
                overflow:TextOverflow.ellipsis)),
              FButton(key:Key('server-reminder-ack-${item.id}'),
                mainAxisSize:MainAxisSize.min,variant:FButtonVariant.ghost,
                onPress:_busy?null:()=>unawaited(_ack(item.id)),
                child:const Text('Conferma')),
            ]))),
      ],
      if(_error!=null)Padding(padding:const EdgeInsets.only(top:8),
        child:Text(_error!,style:TextStyle(
          color:Theme.of(context).colorScheme.error,fontSize:12))),
    ]);
  }
}
