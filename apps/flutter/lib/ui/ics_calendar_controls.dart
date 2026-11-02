import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ics_calendar.dart';
import 'ics_feed.dart';
import 'ics_source_details.dart';
import 'inline_editable_title.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// External ICS overlays are local per Google owner. No sync or OAuth writes.
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
  bool _loading=true, _busy=false, _fetching=false;
  bool _showSources=false;
  String? _error;
  String? _sourceErrorId;

  String get _key=>icsOwnerKey(widget.ownerId);

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
    _fetching=false;
    _showSources=false;
    _sourceErrorId=null;
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

  Future<void> _save(IcsLibrary next, {required String expectedKey}) async {
    if(expectedKey!=_key || _loading || _busy || _error!=null || _prefs==null) {
      throw StateError('Archivio ICS non disponibile');
    }
    final key=_key;
    setState(()=>_busy=true);
    try {
      if(!await _prefs!.setString(key,next.serialize())) {
        throw StateError('Salvataggio ICS fallito');
      }
      if(!mounted || key!=_key) return;
      setState(() {
        _library=next;
        _showSources=true;
      });
      widget.onChanged(next);
    } finally {
      if(mounted && key==_key) setState(()=>_busy=false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(text)));
    }
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
    if(_loading || _busy || _fetching || _error!=null) return;
    final ownerKey=_key;
    try {
      final file=await openFile(acceptedTypeGroups:[
        const XTypeGroup(label:'iCalendar',extensions:['ics'],
          mimeTypes:['text/calendar']),
      ]);
      if(file==null || !mounted || ownerKey!=_key) return;
      if(await file.length()>IcsParser.maxBytes) {
        throw const FormatException('File ICS superiore a 1 MB.');
      }
      final candidate=IcsParser.parse(await file.readAsBytes(),file.name);
      final replace=_library.calendars.any((x)=>x.name==candidate.name);
      final next=_library.replace(candidate);
      if(!mounted || ownerKey!=_key) return;
      final ok=await _confirm('Importa calendario ICS',
        "File: ${candidate.name}\nEventi singoli: ${candidate.events.length}\n"
        "Serie ricorrenti: ${candidate.series.length}\n"
        "${replace ? 'Sostituisce solo questo file ICS.' : 'Aggiunge un calendario esterno.'}\n"
        "Gli eventi restano in sola lettura su questo dispositivo; "
        "nessuna attività o modifica cloud verrà creata.",
        'Importa eventi');
      if(!ok || ownerKey!=_key) return;
      await _save(next,expectedKey:ownerKey);
      _message('Calendario ICS disponibile in sola lettura.');
    } on FormatException catch(e) {
      _message(e.message);
    } catch (_) {
      _message('Importazione ICS non riuscita; i dati precedenti sono intatti.');
    }
  }

  Future<String?> _requestSubscriptionUrl() async {
    final controller = TextEditingController();
    return showFDialog<String>(
      context: context,
      builder: (ctx, style, animation) => NotesEditorControllerScope(
        controllers: [controller],
        child: NotesDialog(
          style: style, animation: animation,
          title: const Text('Aggiungi calendario tramite URL'),
          body: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              FTextField(
                key: const Key('ics-feed-url-input'),
                control: FTextFieldControl.managed(controller: controller),
                label: const Text('Indirizzo HTTPS del calendario'),
                hint: 'https://calendario.example.org/eventi.ics',
              ),
              const SizedBox(height: 10),
              const Text('Il feed verrà scaricato solo dopo la conferma. '
                  'Rimane sul dispositivo e non viene aggiornato '
                  'automaticamente.'),
            ]),
          actions: [
            FButton(variant: FButtonVariant.ghost,
              onPress: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
            FButton(key: const Key('ics-feed-download'),
              onPress: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Scarica feed')),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe() async {
    if (_loading || _busy || _fetching || _error != null) return;
    final expectedKey = _key;
    final url = await _requestSubscriptionUrl();
    if (!mounted || expectedKey != _key || url == null) return;
    try {
      IcsFeedPolicy.validate(url);
      setState(() => _fetching = true);
      // Fetch and parse before any write. No silent partial replace.
      final next = await IcsFeedService().subscribe(_library, url);
      if (!mounted || expectedKey != _key) return;
      final nextCal = next.calendars.firstWhere((c) =>
          c.kind == IcsSourceKind.url && c.sourceUrl == url);
      final already = _library.calendars.any((c) =>
          c.kind == IcsSourceKind.url && c.sourceUrl == url);
      final ok = await _confirm('Conferma calendario esterno',
        'Sorgente: ${nextCal.name}\n'
        'Eventi singoli: ${nextCal.events.length}\n'
        'Serie ricorrenti: ${nextCal.series.length}\n'
        '${already ? 'Aggiorna solo il feed esistente.' : 'Aggiunge una sorgente esterna.'}\n'
        'Cache locale in sola lettura, aggiornamento soltanto manuale. '
        'Nessuna attività o modifica cloud sarà creata.',
        already ? 'Aggiorna' : 'Aggiungi');
      if (!ok || expectedKey != _key) return;
      await _save(next, expectedKey: expectedKey);
      _message('Calendario HTTPS salvato in cache locale.');
    } on FormatException catch (error) {
      if (mounted && expectedKey == _key) _message(error.message);
    } catch (_) {
      if (mounted && expectedKey == _key) {
        _message('Feed non importato; i dati locali sono invariati.');
      }
    } finally {
      if (mounted && expectedKey == _key) {
        setState(() => _fetching = false);
      }
    }
  }

  Future<void> _refresh(String id) async {
    if (_loading || _busy || _fetching || _error != null) return;
    final expectedKey = _key;
    try {
      setState(() => _fetching = true);
      final next = await IcsFeedService().refresh(_library, id);
      if (!mounted || expectedKey != _key) return;
      await _save(next, expectedKey: expectedKey);
      setState(() => _sourceErrorId=null);
      _message('Calendario aggiornato. Cache salvata.');
    } catch (_) {
      if (mounted && expectedKey == _key) {
        setState(() => _sourceErrorId=id);
        _message('Aggiornamento non riuscito: cache precedente conservata.');
      }
    } finally {
      if (mounted && expectedKey == _key) {
        setState(() => _fetching = false);
      }
    }
  }

  Future<void> _rename(String id, String label) async {
    if (_loading || _busy || _fetching || _error != null) {
      throw StateError('Sorgenti ICS non disponibili');
    }
    final expectedKey = _key;
    final next = _library.renameById(id, label);
    if (!mounted || expectedKey != _key) {
      throw StateError('Account cambiato durante la modifica');
    }
    await _save(next, expectedKey: expectedKey);
  }

  Future<void> _remove(String id) async {
    if(_loading || _busy || _fetching || _error!=null) return;
    final ownerKey=_key;
    final calendar=_library.calendars.where((c)=>c.id==id);
    if(calendar.isEmpty) return;
    final ok=await _confirm('Rimuovere calendario ICS?',
      'Rimuove soltanto la sorgente locale ${calendar.first.label}. Nessuna attività sarà eliminata.',
      'Rimuovi calendario');
    if(!ok || ownerKey!=_key) return;
    try { await _save(_library.removeById(id),expectedKey:ownerKey); }
    catch (_) { _message('Rimozione non riuscita; archivio invariato.'); }
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = _loading || _busy || _fetching || _error != null;
    final palette = NotesPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FButton(
              key: const Key('calendar-import-ics'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: unavailable ? null : _import,
              child: const Text('Importa ICS'),
            ),
            FButton(
              key: const Key('calendar-subscribe-ics'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: unavailable ? null : _subscribe,
              child: const Text('Aggiungi URL ICS'),
            ),
            FButton(
              key: const Key('calendar-manage-ics'),
              variant: FButtonVariant.ghost,
              mainAxisSize: MainAxisSize.min,
              onPress: _loading ? null :
                  () => setState(() => _showSources = !_showSources),
              child: Text('Sorgenti (${_library.calendars.length}) '
                  '${_showSources ? '▴' : '▾'}'),
            ),
            if (_fetching) const Text('Aggiornamento calendario…'),
            Text(
              'Eventi esterni · ${_library.eventCount} · locali, sola lettura',
              style: TextStyle(fontSize: 11, color: palette.secondaryText),
            ),
          ],
        ),
        if (_showSources) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_library.calendars.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('Nessun calendario esterno aggiunto.',
                      style: TextStyle(color: palette.secondaryText)),
                  ),
                for (final source in _library.calendars)
                  Padding(
                    key: Key('ics-source-row-${source.id}'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: InlineEditableTitle(
                                key: Key('ics-source-name-${source.id}'),
                                value: source.label,
                                maxLength: 80,
                                semanticsLabel: 'Nome calendario esterno',
                                style: TextStyle(
                                  color: palette.foreground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                                onSave: (value) => _rename(source.id, value),
                              )),
                            ]),
                            const SizedBox(height: 5),
                            Text(icsSourceKindLabel(source),
                              style: TextStyle(fontSize: 12,
                                color: palette.secondaryText)),
                            Text(icsSourceEventCount(source),
                              style: TextStyle(fontSize: 12,
                                color: palette.secondaryText)),
                            Text(icsSourceRefreshLabel(source),
                              style: TextStyle(fontSize: 12,
                                color: palette.secondaryText)),
                            if (_sourceErrorId == source.id)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  'Ultimo tentativo non riuscito: cache preservata.',
                                  key: Key('ics-source-refresh-error-${source.id}'),
                                  style: TextStyle(fontSize: 12,
                                    color: Theme.of(context).colorScheme.error),
                                ),
                              ),
                            const SizedBox(height: 7),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              if (source.kind == IcsSourceKind.url)
                                FButton(
                                  key: Key('calendar-refresh-ics-${source.id}'),
                                  variant: FButtonVariant.ghost,
                                  mainAxisSize: MainAxisSize.min,
                                  onPress: unavailable ? null :
                                      () => _refresh(source.id),
                                  child: const Text('Aggiorna'),
                                ),
                              FButton(
                                key: Key('calendar-remove-ics-${source.id}'),
                                variant: FButtonVariant.ghost,
                                mainAxisSize: MainAxisSize.min,
                                onPress: unavailable ? null :
                                    () => _remove(source.id),
                                child: const Text('Rimuovi'),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null) Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }
}
