import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/reminder_automations.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Device-local rules only: no server jobs and no task/outbox mutations.
class ReminderAutomationsBoard extends StatefulWidget {
  const ReminderAutomationsBoard({
    super.key,
    required this.ownerId,
    required this.supported,
    required this.notificationsEnabled,
    required this.onToggleNotifications,
    required this.onChanged,
  });

  final String? ownerId;
  final bool supported;
  final bool notificationsEnabled;
  final Future<void> Function() onToggleNotifications;
  final VoidCallback onChanged;

  @override
  State<ReminderAutomationsBoard> createState() =>
      _ReminderAutomationsBoardState();
}

class _ReminderAutomationsBoardState extends State<ReminderAutomationsBoard> {
  ReminderAutomationLibrary _rules = ReminderAutomationLibrary(rules: const []);
  SharedPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReminderAutomationsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId == widget.ownerId) return;
    _rules = ReminderAutomationLibrary(rules: const []);
    _prefs = null;
    _loading = true;
    _saving = false;
    _error = null;
    _load();
  }

  Future<void> _load() async {
    final owner = widget.ownerId;
    if (owner == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = await const ReminderAutomationStore().load(prefs, owner);
      if (!mounted || widget.ownerId != owner) return;
      setState(() {
        _rules = loaded;
        _prefs = prefs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || widget.ownerId != owner) return;
      setState(() {
        _loading = false;
        _error = 'Regole locali non leggibili: nessun dato è stato '
            'sovrascritto.';
      });
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(value)));
  }

  Future<void> _save(ReminderAutomationLibrary next) async {
    if (_loading || _saving || _error != null ||
        _prefs == null || widget.ownerId == null) {
      return;
    }
    final owner = widget.ownerId!;
    setState(() => _saving = true);
    try {
      await const ReminderAutomationStore().save(_prefs!, owner, next);
      if (!mounted || widget.ownerId != owner) return;
      setState(() => _rules = next);
      widget.onChanged();
    } catch (_) {
      if (mounted && widget.ownerId == owner) {
        _message('Salvataggio non riuscito; regole precedenti preservate.');
      }
    } finally {
      if (mounted && widget.ownerId == owner) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _edit([ReminderAutomationRule? old]) async {
    if (_loading || _saving || _error != null || widget.ownerId == null) return;
    final owner = widget.ownerId;
    var kind = old?.kind ?? 'due';
    var lead = old?.leadMinutes ?? 15;
    var priority = old?.minPriority ?? 0;
    final edited = await showFDialog<ReminderAutomationRule>(
      context: context,
      builder: (ctx, style, animation) => StatefulBuilder(
        builder: (inner, refresh) => NotesDialog(
          style: style, animation: animation,
          title: Text(old == null ? 'Nuova regola' : 'Modifica regola'),
          body: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quando inviare il promemoria'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final option in const [
                  ('due', 'Scadenza con ora'),
                  ('block', 'Inizio blocco'),
                ])
                  FButton(
                    key: Key('rule-kind-${option.$1}'),
                    variant: kind == option.$1
                        ? FButtonVariant.ghost : FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => refresh(() => kind = option.$1),
                    child: Text('${kind == option.$1 ? '✓ ' : ''}${option.$2}'),
                  ),
              ]),
              const SizedBox(height: 16),
              const Text('Anticipo'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final value in const [0, 5, 15, 30, 60, 1440])
                  FButton(
                    key: Key('rule-lead-$value'),
                    variant: lead == value
                        ? FButtonVariant.ghost : FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => refresh(() => lead = value),
                    child: Text('${lead == value ? '✓ ' : ''}'
                        '${value == 1440 ? '1 giorno' : '$value min'}'),
                  ),
              ]),
              const SizedBox(height: 16),
              const Text('Priorità minima'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final value in const [0, 1, 2, 3])
                  FButton(
                    key: Key('rule-priority-$value'),
                    variant: priority == value
                        ? FButtonVariant.ghost : FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => refresh(() => priority = value),
                    child: Text('${priority == value ? '✓ ' : ''}P$value'),
                  ),
              ]),
              const SizedBox(height: 12),
              const Text('P0 include tutte le attività; le date senza ora '
                  'non producono notifiche.'),
            ],
          )),
          actions: [
            FButton(variant: FButtonVariant.ghost,
              onPress: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
            FButton(key: const Key('rule-save'),
              onPress: () => Navigator.pop(ctx,
                old == null
                    ? ReminderAutomationLibrary.create(
                        kind: kind, leadMinutes: lead, minPriority: priority)
                    : old.copyWith(kind: kind, leadMinutes: lead,
                        minPriority: priority)),
              child: const Text('Salva regola')),
          ],
        ),
      ),
    );
    if (!mounted || owner != widget.ownerId || edited == null) return;
    try {
      await _save(_rules.upsert(edited));
    } on FormatException catch (e) {
      _message(e.message);
    }
  }

  Future<void> _delete(ReminderAutomationRule rule) async {
    if (_saving || _loading || _error != null) return;
    final owner = widget.ownerId;
    final approved = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Elimina regola'),
        body: const Text('I promemoria non più necessari saranno '
            'annullati alla riconciliazione. Nessun task viene modificato.'),
        actions: [
          FButton(variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
          FButton(key: const Key('rule-confirm-delete'),
            onPress: () => Navigator.pop(ctx, true),
            child: const Text('Elimina')),
        ],
      ),
    );
    if (!mounted || owner != widget.ownerId || approved != true) return;
    await _save(_rules.remove(rule.id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = NotesPalette.of(context);
    final editable = !_loading && !_saving && _error == null &&
        widget.ownerId != null;
    return ListView(
      key: const Key('reminder-automations-board'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Automazioni promemoria', style: TextStyle(
          color: colors.foreground, fontSize: 18,
          fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Regole sul dispositivo per scadenze e blocchi orari. '
            'Non modificano le attività e non eseguono azioni sul server.',
          style: TextStyle(color: colors.secondaryText, fontSize: 12)),
        const SizedBox(height: 14),
        if (!widget.supported)
          const Text('Notifiche native solo su Android e Windows MSIX, '
              'non su ZIP/EXE.')
        else if (widget.ownerId == null)
          const Text('Accedi con Google per configurare le regole.')
        else
          Row(children: [
            Expanded(child: Text(widget.notificationsEnabled
                ? 'Notifiche abilitate' : 'Notifiche disattivate')),
            FButton(
              key: const Key('rule-global-toggle'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: widget.onToggleNotifications,
              child: Text(widget.notificationsEnabled
                  ? 'Disattiva' : 'Attiva')),
          ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('Regole', style: TextStyle(
            color: colors.foreground, fontWeight: FontWeight.w600))),
          FButton(key: const Key('rule-create'),
            mainAxisSize: MainAxisSize.min,
            onPress: editable && _rules.rules.length < 20
                ? () => _edit() : null,
            child: const Text('Nuova regola')),
        ]),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!,
          key: const Key('rule-load-error'),
          style: const TextStyle(color: Colors.orangeAccent)),
        if (!_loading && _rules.rules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nessuna regola salvata.')),
        for (final rule in _rules.rules)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rule.kind == 'due' ? 'Scadenza con ora' : 'Blocco'}'
                    ' · ${rule.leadMinutes == 1440 ? '1 giorno' : '${rule.leadMinutes} min'}'
                    ' prima · minimo P${rule.minPriority}',
                  style: TextStyle(color: colors.foreground)),
                const SizedBox(height: 6),
                Text(rule.enabled ? 'Attiva' : 'Disattivata',
                  style: TextStyle(color: colors.secondaryText)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FButton(key: Key('rule-toggle-${rule.id}'),
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: editable ? () => _save(_rules.upsert(
                        rule.copyWith(enabled: !rule.enabled))) : null,
                    child: Text(rule.enabled ? 'Disattiva' : 'Attiva')),
                  FButton(key: Key('rule-edit-${rule.id}'),
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: editable ? () => _edit(rule) : null,
                    child: const Text('Modifica')),
                  FButton(key: Key('rule-delete-${rule.id}'),
                    variant: FButtonVariant.ghost,
                    mainAxisSize: MainAxisSize.min,
                    onPress: editable ? () => _delete(rule) : null,
                    child: const Text('Elimina')),
                ]),
              ],
            )),
          ),
        const SizedBox(height: 16),
        Text('Fino a 100 notifiche nei prossimi 14 giorni. '
            'Programmazione inexact su Android; l’app deve essere '
            'avviata per ricalcolare le regole e il sistema operativo '
            'può ritardare la consegna.',
          style: TextStyle(color: colors.secondaryText, fontSize: 12)),
      ],
    );
  }
}
