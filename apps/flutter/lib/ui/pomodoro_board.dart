import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'notes_theme.dart';
import 'pomodoro_model.dart';

/// P1.10: isolated device-only focus sessions. Timers resume from a persisted
/// UTC deadline; the widget never touches task data or the cloud outbox.
class PomodoroBoard extends StatefulWidget {
  const PomodoroBoard({super.key, required this.ownerId});
  final String? ownerId;

  @override
  State<PomodoroBoard> createState() => _PomodoroBoardState();
}

class _PomodoroBoardState extends State<PomodoroBoard>
    with WidgetsBindingObserver {
  PomodoroState _value = const PomodoroState();
  SharedPreferences? _prefs;
  Timer? _timer;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String get _storageKey {
    final owner = widget.ownerId ?? 'signed-out-local';
    final hash = sha256.convert(utf8.encode(owner)).toString();
    return 'simple_notes.pomodoro.v1.$hash';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    unawaited(_restore());
  }

  @override
  void didUpdateWidget(covariant PomodoroBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      // A different Google account MUST NOT see the previous account's timer.
      _prefs = null;
      _value = const PomodoroState();
      _loading = true;
      _error = null;
      unawaited(_restore());
    }
  }

  Future<void> _restore() async {
    final key = _storageKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final snapshot = raw == null
          ? const PomodoroState() : PomodoroState.deserialize(raw);
      if (!mounted || key != _storageKey) return;
      _prefs = prefs;
      _value = snapshot;
      setState(() => _loading = false);
      if (snapshot.running) _refresh();
    } catch (_) {
      if (!mounted || key != _storageKey) return;
      // Corrupt or unsupported data is NOT overwritten or silently reset.
      setState(() {
        _loading = false;
        _error = 'Impossibile leggere il timer: dati locali conservati. '
            'Non verranno sovrascritti.';
      });
    }
  }

  Future<void> _save(PomodoroState next) async {
    if (_loading || _saving || _error != null) return;
    final prefs = _prefs;
    if (prefs == null) return;
    final key = _storageKey;
    setState(() {
      _value = next;
      _saving = true;
    });
    try {
      final saved = await prefs.setString(key, next.serialize());
      if (!saved) throw StateError('Scrittura preferenze non riuscita');
    } catch (_) {
      if (mounted && key == _storageKey) {
        setState(() => _error = 'Salvataggio locale non riuscito. '
            'Riprova senza cancellare i dati.');
      }
    } finally {
      if (mounted && key == _storageKey) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _retrySave() async {
    if (_prefs == null || _loading || _saving || _error == null) return;
    // Parsing failures have no valid state to retry and must not overwrite.
    if (_error!.startsWith('Impossibile leggere')) return;
    setState(() => _error = null);
    await _save(_value);
  }

  void _refresh() {
    if (!mounted || _loading || _error != null || !_value.running) return;
    final next = _value.settle(DateTime.now());
    if (!identical(next, _value)) {
      unawaited(_save(next));
    } else {
      // Repaint only; wall time, not ticker counts, determines remaining.
      setState(() {});
    }
  }

  void _startOrPause() {
    if (_saving || _loading || _error != null) return;
    final now = DateTime.now();
    final current = _value.settle(now);
    final next = current.running
        ? current.pause(now)
        : current.start(now, const Uuid().v4());
    unawaited(_save(next));
  }

  void _reset() {
    if (_saving || _loading || _error != null) return;
    unawaited(_save(_value.reset()));
  }

  void _skipBreak() {
    if (_saving || _loading || _error != null) return;
    unawaited(_save(_value.skipBreak()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  static String _clock(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
        key: Key('pomodoro-loading')));
    }
    if (_error != null && _error!.startsWith('Impossibile leggere')) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_error!, key: const Key('pomodoro-load-error'),
          textAlign: TextAlign.center)));
    }
    final now = DateTime.now();
    final seconds = _value.secondsLeft(now);
    final total = _value.phase.durationSeconds;
    final progress = (1 - seconds / total).clamp(0.0, 1.0);
    final days = List.generate(7, (index) =>
      DateTime(now.year, now.month, now.day - (6 - index)));
    final maxDaily = days.fold<int>(1, (max, day) {
      final count = _value.completedOn(day);
      return count > max ? count : max;
    });

    return LayoutBuilder(builder: (context, bounds) {
      final narrow = bounds.maxWidth < 650;
      final timer = FCard(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_value.phase.label,
              style: const TextStyle(fontSize: 20,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(_clock(seconds),
              key: const Key('pomodoro-clock'),
              style: TextStyle(fontSize: narrow ? 48 : 66,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('pomodoro-progress'),
              value: progress, minHeight: 7,
              color: NotesPalette.accent,
              backgroundColor: NotesPalette.muted),
            const SizedBox(height: 12),
            const Text('25 min focus · 5 min pausa breve · '
              '15 min ogni 4 focus',
              textAlign: TextAlign.center,
              style: TextStyle(color: NotesPalette.secondaryText,
                fontSize: 12)),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FButton(
                  key: const Key('pomodoro-toggle'),
                  onPress: _saving || _error != null
                      ? null : _startOrPause,
                  prefix: Icon(_value.running
                      ? Icons.pause : Icons.play_arrow, size: 17),
                  child: Text(_value.running ? 'Pausa' : 'Avvia'),
                ),
                FButton(
                  key: const Key('pomodoro-reset'),
                  variant: FButtonVariant.outline,
                  onPress: _saving || _error != null ? null : _reset,
                  child: const Text('Ricomincia'),
                ),
                if (_value.phase != FocusPhase.focus)
                  FButton(
                    key: const Key('pomodoro-skip'),
                    variant: FButtonVariant.ghost,
                    onPress: _saving || _error != null ? null : _skipBreak,
                    child: const Text('Salta pausa'),
                  ),
              ],
            ),
          ],
        ),
      ));

      final stats = FCard(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistiche locali', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Text('${_value.completedOn(now)} sessioni oggi',
              key: const Key('pomodoro-today')),
            const SizedBox(height: 6),
            Text('${_value.totalFocusMinutes} minuti di '
              'concentrazione completati',
              key: const Key('pomodoro-total')),
            const SizedBox(height: 6),
            Text('${_value.focusCompleted} cicli focus completati',
              key: const Key('pomodoro-cycles')),
            const SizedBox(height: 16),
            const Text('Ultimi 7 giorni', style: TextStyle(
              fontSize: 12, color: NotesPalette.secondaryText)),
            const SizedBox(height: 10),
            for (final day in days) ...[
              Row(children: [
                SizedBox(width: 50, child: Text(
                  '${day.day}/${day.month}', style: const TextStyle(
                    fontSize: 12, color: NotesPalette.secondaryText))),
                Expanded(child: LinearProgressIndicator(
                  value: _value.completedOn(day) / maxDaily,
                  minHeight: 9,
                  color: NotesPalette.accent,
                  backgroundColor: NotesPalette.muted)),
                SizedBox(width: 28, child: Text(
                  '${_value.completedOn(day)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12))),
              ]),
              const SizedBox(height: 8),
            ],
            const Text('Solo su questo dispositivo. Nessuna '
              'sincronizzazione o notifica con app chiusa.',
              style: TextStyle(fontSize: 12,
                color: NotesPalette.secondaryText)),
          ],
        ),
      ));
      return SingleChildScrollView(
        key: const Key('pomodoro-board'),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Expanded(child: Text(_error!,
                  style: const TextStyle(color: Colors.orangeAccent))),
                FButton(
                  key: const Key('pomodoro-retry'),
                  variant: FButtonVariant.outline,
                  onPress: _retrySave,
                  child: const Text('Riprova'),
                ),
              ])),
          if (narrow) ...[
            timer,
            const SizedBox(height: 12),
            stats,
          ] else
            Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: timer),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: stats),
              ]),
        ]),
      );
    });
  }
}
