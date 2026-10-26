import 'dart:convert';

/// P1.10 is intentionally device-only. This model never reads or writes task,
/// note or sync entities, and does not invent cloud capabilities.
enum FocusPhase { focus, shortBreak, longBreak }

extension FocusPhaseDetails on FocusPhase {
  String get label => switch (this) {
    FocusPhase.focus => 'Concentrazione',
    FocusPhase.shortBreak => 'Pausa breve',
    FocusPhase.longBreak => 'Pausa lunga',
  };

  int get durationSeconds => switch (this) {
    FocusPhase.focus => 25 * 60,
    FocusPhase.shortBreak => 5 * 60,
    FocusPhase.longBreak => 15 * 60,
  };
}

class FocusRecord {
  const FocusRecord({
    required this.id,
    required this.completedAtUtc,
    required this.seconds,
  });

  final String id;
  final DateTime completedAtUtc;
  final int seconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
    'seconds': seconds,
  };

  factory FocusRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final timestamp = json['completedAtUtc'];
    final seconds = json['seconds'];
    if (id is! String || id.isEmpty || timestamp is! String ||
        seconds is! int || seconds < 1 || seconds > 24 * 3600) {
      throw const FormatException('Record Pomodoro non valido');
    }
    return FocusRecord(
      id: id,
      completedAtUtc: DateTime.parse(timestamp).toUtc(),
      seconds: seconds,
    );
  }
}

/// Immutable timer persisted as ONE JSON preference per local account.
/// A completed focus session is credited once, by stable session ID.
/// There is no background alarm or automatic break start.
class PomodoroState {
  const PomodoroState({
    this.phase = FocusPhase.focus,
    this.remainingSeconds = 25 * 60,
    this.deadlineUtc,
    this.focusCompleted = 0,
    this.activeSessionId,
    this.records = const [],
  });

  final FocusPhase phase;
  final int remainingSeconds;
  final DateTime? deadlineUtc;
  final int focusCompleted;
  final String? activeSessionId;
  final List<FocusRecord> records;

  bool get running => deadlineUtc != null;

  int secondsLeft(DateTime now) {
    if (deadlineUtc == null) return remainingSeconds;
    final milliseconds = deadlineUtc!.difference(now.toUtc()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  PomodoroState start(DateTime now, String newSessionId) {
    if (running) return this;
    if (newSessionId.isEmpty) throw ArgumentError('Session ID richiesto');
    return PomodoroState(
      phase: phase,
      remainingSeconds: remainingSeconds,
      deadlineUtc: now.toUtc().add(Duration(seconds: remainingSeconds)),
      focusCompleted: focusCompleted,
      activeSessionId: activeSessionId ?? newSessionId,
      records: records,
    );
  }

  PomodoroState pause(DateTime now) {
    if (!running) return this;
    final current = settle(now);
    if (!current.running) return current;
    return PomodoroState(
      phase: phase,
      remainingSeconds: secondsLeft(now),
      focusCompleted: focusCompleted,
      activeSessionId: activeSessionId,
      records: records,
    );
  }

  PomodoroState settle(DateTime now) {
    if (!running || now.toUtc().isBefore(deadlineUtc!)) return this;
    if (phase != FocusPhase.focus) {
      return PomodoroState(
        focusCompleted: focusCompleted,
        records: records,
      );
    }
    final id = activeSessionId;
    if (id == null) throw const FormatException('ID Pomodoro mancante');
    final alreadyRecorded = records.any((record) => record.id == id);
    final nextCompleted = focusCompleted + (alreadyRecorded ? 0 : 1);
    final nextPhase = nextCompleted % 4 == 0
        ? FocusPhase.longBreak : FocusPhase.shortBreak;
    final nextRecords = [
      ...records,
      if (!alreadyRecorded)
        FocusRecord(
          id: id,
          completedAtUtc: deadlineUtc!,
          seconds: FocusPhase.focus.durationSeconds,
        ),
    ];
    // Bounded local history. This is per-device, NOT user task data.
    final retained = nextRecords.length > 500
        ? nextRecords.sublist(nextRecords.length - 500)
        : nextRecords;
    return PomodoroState(
      phase: nextPhase,
      remainingSeconds: nextPhase.durationSeconds,
      focusCompleted: nextCompleted,
      records: List.unmodifiable(retained),
    );
  }

  /// Reset only the current countdown. Completed history is never erased.
  PomodoroState reset() => PomodoroState(
    phase: phase,
    remainingSeconds: phase.durationSeconds,
    focusCompleted: focusCompleted,
    records: records,
  );

  /// Skipping a break cannot accidentally credit a focus session.
  PomodoroState skipBreak() => phase == FocusPhase.focus ? this
      : PomodoroState(focusCompleted: focusCompleted, records: records);

  int completedOn(DateTime civilDay) => records.where((record) {
    final local = record.completedAtUtc.toLocal();
    return local.year == civilDay.year && local.month == civilDay.month &&
        local.day == civilDay.day;
  }).length;

  int get totalFocusMinutes => records.fold<int>(
    0, (sum, record) => sum + record.seconds) ~/ 60;

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'phase': phase.name,
    'remainingSeconds': remainingSeconds,
    'deadlineUtc': deadlineUtc?.toUtc().toIso8601String(),
    'focusCompleted': focusCompleted,
    'activeSessionId': activeSessionId,
    'records': records.map((record) => record.toJson()).toList(),
  };

  String serialize() => jsonEncode(toJson());

  factory PomodoroState.deserialize(String value) {
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic> || json['schema'] != 1) {
      throw const FormatException('Formato Pomodoro non supportato');
    }
    final phase = FocusPhase.values.where((p) => p.name == json['phase'])
        .firstOrNull;
    final remaining = json['remainingSeconds'];
    final completed = json['focusCompleted'];
    final deadline = json['deadlineUtc'];
    final activeId = json['activeSessionId'];
    final rawRecords = json['records'];
    if (phase == null || remaining is! int || remaining < 0 ||
        remaining > phase.durationSeconds || completed is! int ||
        completed < 0 || deadline != null && deadline is! String ||
        activeId != null && activeId is! String ||
        deadline != null && (activeId == null || activeId.isEmpty) ||
        rawRecords is! List || rawRecords.length > 500) {
      throw const FormatException('Stato Pomodoro non valido');
    }
    final records = rawRecords.map((raw) {
      if (raw is! Map) throw const FormatException('Record non valido');
      return FocusRecord.fromJson(Map<String, dynamic>.from(raw));
    }).toList();
    if (records.map((record) => record.id).toSet().length != records.length) {
      throw const FormatException('Sessioni Pomodoro duplicate');
    }
    return PomodoroState(
      phase: phase,
      remainingSeconds: remaining,
      deadlineUtc: deadline == null ? null : DateTime.parse(deadline).toUtc(),
      focusCompleted: completed,
      activeSessionId: activeId,
      records: List.unmodifiable(records),
    );
  }
}
