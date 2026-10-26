import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/pomodoro_model.dart';

void main() {
  final initial = DateTime.utc(2026, 10, 26, 12);

  test('Focus survives pause, restart, and resume without counting paused time',
      () {
    final started = const PomodoroState().start(initial, 'focus-1');
    final paused = started.pause(initial.add(const Duration(minutes: 7)));
    expect(paused.running, isFalse);
    expect(paused.remainingSeconds, 18 * 60);

    // Reopen app much later: no time should elapse while paused.
    final restored = PomodoroState.deserialize(paused.serialize());
    expect(restored.secondsLeft(initial.add(const Duration(hours: 2))),
        18 * 60);
    final resumed = restored.start(
        initial.add(const Duration(hours: 2)), 'new-id');
    expect(resumed.activeSessionId, 'focus-1');
    expect(resumed.secondsLeft(initial.add(
        const Duration(hours: 2, minutes: 3))), 15 * 60);
    final next = resumed.settle(initial.add(
        const Duration(hours: 2, minutes: 18)));
    expect(next.phase, FocusPhase.shortBreak);
    expect(next.focusCompleted, 1);
    expect(next.records.single.id, 'focus-1');
    expect(next.totalFocusMinutes, 25);
  });

  test('An overdue persisted focus is credited exactly once', () {
    final started = const PomodoroState().start(initial, 'unique-session');
    final raw = started.serialize();
    final later = initial.add(const Duration(hours: 4));
    final first = PomodoroState.deserialize(raw).settle(later);
    expect(first.records.length, 1);
    expect(first.focusCompleted, 1);
    expect(first.running, isFalse);
    final second = PomodoroState.deserialize(first.serialize()).settle(later);
    expect(second.records.length, 1);
    expect(second.focusCompleted, 1);
    expect(second.phase, FocusPhase.shortBreak);
  });

  test('Fourth focus selects long break, skipping breaks earns no minutes', () {
    var current = const PomodoroState();
    var now = initial;
    for (var count = 1; count <= 4; count++) {
      current = current.start(now, 'cycle-$count');
      now = now.add(const Duration(minutes: 25));
      current = current.settle(now);
      expect(current.focusCompleted, count);
      expect(current.phase, count == 4
          ? FocusPhase.longBreak : FocusPhase.shortBreak);
      expect(current.totalFocusMinutes, count * 25);
      current = current.skipBreak();
      expect(current.phase, FocusPhase.focus);
      expect(current.focusCompleted, count);
    }
    expect(current.records.length, 4);
    expect(current.totalFocusMinutes, 100);
  });

  test('Reset does not delete existing records or credit interrupted focus', () {
    final first = const PomodoroState().start(initial, 'first')
        .settle(initial.add(const Duration(minutes: 25)));
    final resumed = first.skipBreak()
        .start(initial.add(const Duration(hours: 1)), 'interrupted')
        .reset();
    expect(resumed.running, isFalse);
    expect(resumed.records.map((r) => r.id), ['first']);
    expect(resumed.totalFocusMinutes, 25);
    expect(resumed.focusCompleted, 1);
    expect(resumed.remainingSeconds, 25 * 60);
  });

  test('Corrupt/unknown records do not silently reset or count sessions', () {
    expect(() => PomodoroState.deserialize('{"schema":2}'),
        throwsFormatException);
    expect(() => PomodoroState.deserialize('not-json'),
        throwsFormatException);
    expect(() => PomodoroState.deserialize(
        '{"schema":1,"phase":"focus","remainingSeconds":1,'
        '"deadlineUtc":"2026-10-26T00:00:00Z",'
        '"focusCompleted":0,"activeSessionId":null,"records":[]}'),
        throwsFormatException);
  });

  test('Stats use device local civil days, never a UTC-midnight shortcut', () {
    final state = const PomodoroState().start(initial, 'by-day')
        .settle(initial.add(const Duration(minutes: 25)));
    final day = state.records.single.completedAtUtc.toLocal();
    expect(state.completedOn(DateTime(day.year, day.month, day.day)), 1);
    expect(state.completedOn(DateTime(day.year, day.month, day.day + 1)), 0);
  });
}
