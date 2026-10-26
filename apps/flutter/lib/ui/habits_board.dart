import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'habits_model.dart';
import 'inline_editable_title.dart';
import 'inline_quick_add.dart';
import 'notes_theme.dart';

/// V1 device-local habits. Never touches the cloud task outbox.
class HabitsBoard extends StatefulWidget {
  const HabitsBoard({super.key, required this.ownerId});
  final String? ownerId;

  @override
  State<HabitsBoard> createState() => _HabitsBoardState();
}

class _HabitsBoardState extends State<HabitsBoard>
    with WidgetsBindingObserver {
  HabitsState _data = HabitsState();
  SharedPreferences? _prefs;
  bool _loading = true;
  bool _busy = false;
  bool _showArchived = false;
  String? _error;
  String? _loadError;

  String get _key {
    final owner = widget.ownerId ?? 'signed-out-local';
    return 'simple_notes.habits.v1.'
        '${sha256.convert(utf8.encode(owner))}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HabitsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      // Never display the previous owner's habit data even for one frame.
      _data = HabitsState();
      _prefs = null;
      _busy = false;
      _loading = true;
      _showArchived = false;
      _error = null;
      _loadError = null;
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {}); // Recalculate today's civil date and streaks.
    }
  }

  Future<void> _load() async {
    final identity = _key;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(identity);
      final state = raw == null ? HabitsState() : HabitsState.deserialize(raw);
      if (!mounted || identity != _key) return;
      setState(() {
        _data = state;
        _prefs = prefs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || identity != _key) return;
      setState(() {
        _loading = false;
        _loadError = 'L’archivio locale non è leggibile. '
            'I dati non verranno cancellati o sovrascritti.';
      });
    }
  }

  Future<void> _save(HabitsState next, {bool propagateFailure = false}) async {
    if (_busy || _loading || _loadError != null || _prefs == null) {
      if (propagateFailure) throw StateError('Salvataggio non disponibile');
      return;
    }
    final identity = _key;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await _prefs!.setString(identity, next.serialize());
      if (!success) throw StateError('Preferenze non salvate');
      if (!mounted || identity != _key) return;
      setState(() => _data = next);
    } catch (_) {
      if (!mounted || identity != _key) return;
      setState(() => _error = 'Salvataggio locale non riuscito. '
          'Nessuna modifica confermata.');
      // InlineQuickAdd must preserve the text on failure instead of clearing it.
      if (propagateFailure) rethrow;
    } finally {
      if (mounted && identity == _key) setState(() => _busy = false);
    }
  }

  Future<void> _create(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 120) {
      throw StateError('Titolo: massimo 120 caratteri.');
    }
    await _save(_data.add(const Uuid().v4(), trimmed, DateTime.now()),
        propagateFailure: true);
  }

  Future<void> _rename(String id, String title) async {
    final value = title.trim();
    if (value.isEmpty || value.length > 120) {
      throw StateError('Titolo: da 1 a 120 caratteri.');
    }
    await _save(_data.update(id, (habit) => habit.renamed(value)),
        propagateFailure: true);
  }

  Future<void> _toggle(String id, DateTime date) async {
    final today = DateTime.now();
    await _save(_data.update(id, (habit) => habit.toggle(date, today)));
  }

  Future<void> _archive(String id, bool archive) =>
      _save(_data.update(id, (habit) => habit.withArchived(archive)));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          key: Key('habits-loading')));
    }
    if (_loadError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_loadError!, key: const Key('habits-load-error'),
          textAlign: TextAlign.center)));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = List.generate(7, (index) =>
        HabitDay.shift(today, index - 6));
    final active = _data.active;
    final archived = _data.archived;

    return LayoutBuilder(builder: (context, bounds) => SingleChildScrollView(
      key: const Key('habits-board'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Abitudini quotidiane', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Check-in giornalieri e streak sul dispositivo. '
          'Non sincronizzati tra Windows e Android.',
          style: TextStyle(fontSize: 12,
            color: NotesPalette.secondaryText)),
        const SizedBox(height: 12),
        FCard(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_data.checkedToday(today)} / ${active.length} '
                'completate oggi', key: const Key('habits-progress-label'),
                style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const Key('habits-progress'),
                value: active.isEmpty
                    ? 0 : _data.checkedToday(today) / active.length,
                color: NotesPalette.accent,
                backgroundColor: NotesPalette.muted, minHeight: 7),
              const SizedBox(height: 10),
              InlineQuickAdd(
                key: const Key('habits-create'),
                hint: 'Nuova abitudine',
                maxLength: 120,
                onAdd: _create,
              ),
            ],
          ),
        )),
        const SizedBox(height: 14),
        if (active.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Aggiungi la prima abitudine per iniziare.')),
        for (final habit in active)
          Padding(
            key: Key('habit-card-${habit.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: FCard(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    FCheckbox(
                      key: Key('habit-today-${habit.id}'),
                      value: habit.checked(today),
                      onChange: _busy ? null : (_) =>
                          _toggle(habit.id, today),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: InlineEditableTitle(
                      key: Key('habit-title-${habit.id}'),
                      value: habit.title,
                      maxLength: 120,
                      semanticsLabel: 'Nome abitudine modificabile',
                      style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w600),
                      onSave: (value) => _rename(habit.id, value),
                    )),
                    FButton.icon(
                      key: Key('habit-archive-${habit.id}'),
                      variant: FButtonVariant.ghost,
                      onPress: _busy ? null : () => _archive(habit.id, true),
                      child: const Icon(Icons.archive_outlined,
                        size: 18),
                    ),
                  ]),
                  const SizedBox(height: 7),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    Text('${habit.streak(today)} giorni di streak',
                      key: Key('habit-streak-${habit.id}'),
                      style: const TextStyle(fontSize: 12,
                        color: NotesPalette.secondaryText)),
                    Text('${habit.countLast(today, 7)} / 7 '
                      'check-in negli ultimi 7 giorni',
                      style: const TextStyle(fontSize: 12,
                        color: NotesPalette.secondaryText)),
                    Text('${habit.countLast(today, 30)} / 30 '
                      'negli ultimi 30 giorni',
                      style: const TextStyle(fontSize: 12,
                        color: NotesPalette.secondaryText)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final day in week)
                      if (!day.isBefore(HabitDay.parse(habit.createdDay)))
                        FButton(
                          key: Key('habit-day-${habit.id}-${HabitDay.of(day)}'),
                          variant: habit.checked(day)
                              ? FButtonVariant.primary
                              : FButtonVariant.outline,
                          mainAxisSize: MainAxisSize.min,
                          onPress: _busy
                              ? null : () => _toggle(habit.id, day),
                          child: Text('${day.day}/${day.month}',
                            style: const TextStyle(fontSize: 11)),
                        ),
                  ]),
                ],
              ),
            )),
          ),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 4),
          FButton(
            key: const Key('habits-show-archived'),
            variant: FButtonVariant.ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: () => setState(() => _showArchived = !_showArchived),
            child: Text(_showArchived
                ? 'Nascondi archiviate'
                : 'Archiviate (${archived.length})')),
          if (_showArchived)
            for (final habit in archived)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FCard(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Text(habit.title)),
                    Text('${habit.checkIns.length} check-in',
                      style: const TextStyle(fontSize: 12,
                        color: NotesPalette.secondaryText)),
                    const SizedBox(width: 8),
                    FButton(
                      key: Key('habit-restore-${habit.id}'),
                      variant: FButtonVariant.outline,
                      onPress: _busy ? null :
                          () => _archive(habit.id, false),
                      child: const Text('Ripristina'),
                    ),
                  ]),
                ))),
        ],
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, key: const Key('habits-save-error'),
              style: const TextStyle(color: Colors.orangeAccent))),
      ]),
    ));
  }
}
