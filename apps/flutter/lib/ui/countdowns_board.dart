import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/task_due.dart';
import '../data/task_due_view.dart';
import 'countdowns_model.dart';
import 'inline_editable_title.dart';
import 'inline_quick_add.dart';
import 'notes_theme.dart';
import 'task_due_editor.dart';

/// Countdowns are local to one device and one Google owner. No task sync.
class CountdownsBoard extends StatefulWidget {
  const CountdownsBoard({super.key, required this.ownerId});
  final String? ownerId;

  @override
  State<CountdownsBoard> createState() => _CountdownsBoardState();
}

class _CountdownsBoardState extends State<CountdownsBoard>
    with WidgetsBindingObserver {
  CountdownsState _state = CountdownsState();
  SharedPreferences? _prefs;
  Timer? _ticker;
  bool _loading = true;
  bool _busy = false;
  bool _showArchived = false;
  TaskDue? _draftDue;
  String? _loadError;
  String? _saveError;

  String get _storageKey {
    final owner = widget.ownerId ?? 'signed-out-local';
    return 'simple_notes.countdowns.v1.'
        '${sha256.convert(utf8.encode(owner))}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) setState(() {});
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CountdownsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId == widget.ownerId) return;
    _prefs = null;
    _state = CountdownsState();
    _draftDue = null;
    _loading = true;
    _busy = false;
    _showArchived = false;
    _loadError = null;
    _saveError = null;
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> _load() async {
    final key = _storageKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final next = raw == null
          ? CountdownsState() : CountdownsState.deserialize(raw);
      if (!mounted || _storageKey != key) return;
      setState(() {
        _prefs = prefs;
        _state = next;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _storageKey != key) return;
      setState(() {
        _loading = false;
        _loadError = 'Archivio Countdown non leggibile. '
            'Nessun dato locale è stato sovrascritto.';
      });
    }
  }

  Future<void> _save(CountdownsState next) async {
    if (_busy || _loading || _loadError != null || _prefs == null) {
      throw StateError('Archivio Countdown non disponibile');
    }
    final key = _storageKey;
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      final success = await _prefs!.setString(key, next.serialize());
      if (!success) throw StateError('Salvataggio non riuscito');
      if (!mounted || _storageKey != key) return;
      setState(() => _state = next);
    } catch (_) {
      if (mounted && key == _storageKey) {
        setState(() => _saveError =
            'Salvataggio fallito: i dati precedenti sono conservati.');
      }
      rethrow;
    } finally {
      if (mounted && _storageKey == key) setState(() => _busy = false);
    }
  }

  Future<void> _pickNewDate() async {
    final selection = await showTaskDueEditor(context,
      initial: _draftDue ?? TaskDue.none);
    if (!mounted || selection == null) return;
    if (selection.kind != 'date' && selection.kind != 'datetime') {
      setState(() => _draftDue = null);
      return;
    }
    setState(() => _draftDue = selection);
  }

  Future<void> _create(String title) async {
    final due = _draftDue;
    if (due == null) {
      // InlineQuickAdd catches the exception and preserves the typed title.
      throw StateError('Seleziona prima la data');
    }
    final value = title.trim();
    if (value.isEmpty || value.length > 120) {
      throw StateError('Titolo troppo lungo');
    }
    await _save(_state.add(const Uuid().v4(), value, due));
    if (mounted) setState(() => _draftDue = null);
  }

  Future<void> _editDue(CountdownEvent event) async {
    final next = await showTaskDueEditor(context, initial: event.due);
    if (!mounted || next == null ||
        next.kind != 'date' && next.kind != 'datetime') return;
    await _save(_state.update(event.id, (existing) =>
        existing.rescheduled(next)));
  }

  Future<void> _rename(String id, String title) {
    final next = title.trim();
    if (next.isEmpty || next.length > 120) {
      throw StateError('Titolo non valido');
    }
    return _save(_state.update(id, (event) => event.renamed(next)));
  }

  Future<void> _archive(String id, bool archive) =>
      _save(_state.update(id, (event) => event.withArchived(archive)));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(
      child: CircularProgressIndicator(key: Key('countdown-loading')));
    if (_loadError != null) return Center(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(_loadError!, key: const Key('countdown-load-error'),
        textAlign: TextAlign.center),
    ));

    final now = DateTime.now();
    final active = _state.active;
    final archived = _state.archived;
    return SingleChildScrollView(
      key: const Key('countdown-board'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Conti alla rovescia', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 20)),
        const SizedBox(height: 6),
        const Text('Date civili o scadenze con ora e fuso IANA. '
          'Solo su questo dispositivo, senza notifiche automatiche.',
          style: TextStyle(fontSize: 12,
            color: NotesPalette.secondaryText)),
        const SizedBox(height: 16),
        FCard(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FButton(
                key: const Key('countdown-new-date'),
                variant: FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                onPress: _busy ? null : _pickNewDate,
                prefix: const Icon(Icons.event_outlined, size: 17),
                child: Text(_draftDue == null
                    ? 'Scegli data / ora'
                    : taskDueLabel(_draftDue!)),
              ),
              const SizedBox(height: 8),
              InlineQuickAdd(
                key: const Key('countdown-add'),
                hint: 'Titolo evento (scegli prima una data)',
                maxLength: 120,
                onAdd: _create,
              ),
            ],
          ),
        )),
        const SizedBox(height: 16),
        if (active.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Nessun evento: aggiungi il primo countdown.')),
        for (final event in active)
          Padding(
            key: Key('countdown-event-${event.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: FCard(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: InlineEditableTitle(
                      key: Key('countdown-title-${event.id}'),
                      value: event.title,
                      maxLength: 120,
                      semanticsLabel: 'Titolo evento modificabile',
                      style: const TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w600),
                      onSave: (text) => _rename(event.id, text),
                    )),
                    FButton.icon(
                      key: Key('countdown-archive-${event.id}'),
                      variant: FButtonVariant.ghost,
                      onPress: _busy ? null :
                          () => _archive(event.id, true),
                      child: const Icon(Icons.archive_outlined, size: 19),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(CountdownClock.remaining(event.due, now),
                    key: Key('countdown-remaining-${event.id}'),
                    style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: CountdownClock.overdue(event.due, now)
                          ? NotesPalette.secondaryText
                          : NotesPalette.accent)),
                  const SizedBox(height: 8),
                  FButton(
                    key: Key('countdown-edit-due-${event.id}'),
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: _busy ? null : () => _editDue(event),
                    prefix: const Icon(Icons.edit_calendar_outlined, size: 15),
                    child: Text(taskDueLabel(event.due)),
                  ),
                ],
              ),
            )),
          ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 8),
          FButton(
            key: const Key('countdown-toggle-archive'),
            variant: FButtonVariant.ghost,
            onPress: () =>
                setState(() => _showArchived = !_showArchived),
            child: Text(_showArchived
                ? 'Nascondi archivio'
                : 'Archiviati (${archived.length})'),
          ),
          if (_showArchived)
            for (final event in archived)
              Padding(
                key: Key('countdown-archived-${event.id}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: FCard(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Text(event.title)),
                    FButton(
                      key: Key('countdown-restore-${event.id}'),
                      variant: FButtonVariant.outline,
                      onPress: _busy ? null :
                          () => _archive(event.id, false),
                      child: const Text('Ripristina'),
                    ),
                  ]),
                ))),
              ),
        ],
        if (_saveError != null)
          Padding(padding: const EdgeInsets.only(top: 10),
            child: Text(_saveError!,
              key: const Key('countdown-save-error'),
              style: const TextStyle(color: Colors.orangeAccent))),
      ]),
    );
  }
}
