import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ics_calendar.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// File overlays are local per Google owner. No SQLite, sync, or OAuth writes.
class IcsCalendarControls extends StatefulWidget {
  const IcsCalendarControls({super.key, required this.ownerId,
    required this.onChanged});
  final String? ownerId;
  final ValueChanged<IcsLibrary> onChanged;
  @override
  State<IcsCalendarControls> createState()=>_IcsCalendarControlsState();
}

class _IcsCalendarControlsState extends State<IcsCalendarControls> {
  IcsLibrary _library=const IcsLibrary();
  SharedPreferences? _prefs;
  bool _loading=true, _busy=false;
  String? _error;

  String get _key=>'simple_notes.ics.v1.'+
      sha256.convert(utf8.encode(widget.ownerId??'signed-out-local')).toString();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant IcsCalendarControls old) {
    super.didUpdateWidget(old);
    if(old.ownerId==widget.ownerId) return;
    _library=const IcsLibrary();
    _prefs=null;
    _loading=true;
    _busy=false;
    _error=null;
    // The parent resets its overlay at the same time as owner changes.
    unawaited(_load());
  }

  Future<void> _load() async {
    final key=_key;
    try {
      final prefs=await SharedPreferences.getInstance();
      final raw=prefs.getString(key);
      final lib=raw==null ? const IcsLibrary() : IcsLibrary.deserialize(raw);
      if(!mounted || key!=_key) return;
      setState((){
        _library=lib;
        _prefs=prefs;
        _loading=false;
      });
      widget.onChanged(lib);
    } catch (_) {
      if(!mounted || key!=_key) return;
      setState((){
        _loading=false;
        _error='Archivio ICS non leggibile. Nessun dato è stato modificato.';
      });
    }
  }

  Future<void> _save(IcsLibrary next) async {
    if(_loading || _busy || _error!=null || _prefs==null) {
      throw StateError('Archivio ICS non disponibile');
    }
    final key=_key;
    setState(()=>_busy=true);
    try {
      if(!await _prefs!.setString(key,next.serialize())) {
        throw StateError('Salvataggio ICS fallito');
      }
      if(!mounted || key!=_key) return;
      setState(()=>_library=next);
      widget.onChanged(next);
    } finally {
      if(mounted && key==_key) setState(()=>_busy=false);
    }
  }

  void _message(String text) {
    if(mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content:Text(text)));
  }

  Future<bool> _confirm(String title,String body,String accept) async {
    final choice=await showFDialog<bool>(
      context:context,
      builder:(ctx,style,animation)=>NotesDialog(
        style:style,animation:animation,
        title:Text(title),body:Text(body),
        actions:[
          FButton(variant:FButtonVariant.ghost,
            onPress:()=>Navigator.pop(ctx,false),child:const Text('Annulla')),
          FButton(onPress:()=>Navigator.pop(ctx,true),child:Text(accept)),
        ],
      ),
    );
    return choice==true && mounted;
  }

  Future<void> _import() async {
    if(_loading || _busy || _error!=null) return;
    try {
      final file=await openFile(acceptedTypeGroups:[
        const XTypeGroup(label:'iCalendar',extensions:['ics'],
          mimeTypes:['text/calendar']),
      ]);
      if(file==null) return;
      if(await file.length()>IcsParser.maxBytes) {
        throw const FormatException('File ICS superiore a 1 MB.');
      }
      final candidate=IcsParser.parse(await file.readAsBytes(),file.name);
      final replace=_library.calendars.any((x)=>x.name==candidate.name);
      final next=_library.replace(candidate);
      if(!mounted) return;
      final ok=await _confirm('Importa calendario ICS',
        'File: '+candidate.name+'\nEventi: '+
        candidate.events.length.toString()+'\n'+
        (replace ? 'Sostituisce solo questo file ICS.\n':
          'Aggiunge un calendario esterno.\n')+
        'Gli eventi restano in sola lettura su questo dispositivo; '
        'nessuna attività o modifica cloud verrà creata.',
        'Importa eventi');
      if(!ok) return;
      await _save(next);
      _message('Calendario ICS disponibile in sola lettura.');
    } on FormatException catch(e) {
      _message(e.message);
    } catch (_) {
      _message('Importazione ICS non riuscita; i dati precedenti sono intatti.');
    }
  }

  Future<void> _remove(String name) async {
    if(_loading || _busy || _error!=null) return;
    final ok=await _confirm('Rimuovere calendario ICS?',
      'Rimuove soltanto il file locale '+name+'. Nessuna attività sarà eliminata.',
      'Rimuovi calendario');
    if(!ok) return;
    try { await _save(_library.remove(name)); }
    catch (_) { _message('Rimozione non riuscita; archivio invariato.'); }
  }

  @override
  Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Wrap(spacing:8,runSpacing:6,crossAxisAlignment:WrapCrossAlignment.center,
        children:[
          FButton(key:const Key('calendar-import-ics'),
            variant:FButtonVariant.outline,mainAxisSize:MainAxisSize.min,
            onPress:_loading||_busy||_error!=null ? null : _import,
            child:const Text('Importa ICS')),
          Text('Eventi esterni · '+_library.eventCount.toString()+
            ' · locali, sola lettura',style:TextStyle(fontSize:11,
              color:NotesPalette.of(context).secondaryText)),
          for(final cal in _library.calendars)
            FButton(key:Key('calendar-remove-ics-'+cal.name),
              variant:FButtonVariant.ghost,mainAxisSize:MainAxisSize.min,
              onPress:_busy ? null : ()=>_remove(cal.name),
              child:Text('× '+cal.name,maxLines:1,
                overflow:TextOverflow.ellipsis)),
        ],
      ),
      if(_error!=null) Text(_error!,
        style:TextStyle(color:Theme.of(context).colorScheme.error)),
    ]);
}
