import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/task_due.dart';
import 'package:simple_notes/ui/countdowns_model.dart';

TaskDue dated(String day) => TaskDue.dateOnly(day);

TaskDue timed(DateTime instant) => TaskDue.timed(
  date: '2026-11-01',
  time: '12:00',
  timeZone: 'Europe/Rome',
  instant: instant,
  offsetSeconds: 3600,
);

void main() {
  test('Civil countdown does not invent midnight or cross DST hours', () {
    final now = DateTime(2026, 10, 25, 23, 58);
    expect(CountdownClock.remaining(dated('2026-10-26'), now), '1 giorno');
    expect(CountdownClock.remaining(dated('2026-10-25'), now), 'Oggi');
    expect(CountdownClock.remaining(dated('2026-10-24'), now), 'Da 1 giorno');
    expect(CountdownClock.civilDaysBetween(
      DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    expect(CountdownClock.overdue(dated('2026-10-25'), now), false);
    expect(CountdownClock.overdue(dated('2026-10-24'), now), true);
  });

  test('Timed countdown is based on UTC instant and rounds remaining minutes up', () {
    final now = DateTime.utc(2026, 11, 1, 9, 0);
    final event = timed(DateTime.utc(2026, 11, 1, 11, 0));
    expect(CountdownClock.remaining(event, now), '2 h · 0 min');
    expect(CountdownClock.remaining(event,
      now.add(const Duration(hours: 1, minutes: 59, seconds: 40))),
      '1 min');
    expect(CountdownClock.remaining(event,
      now.add(const Duration(hours: 2))), 'Scaduto');
    expect(CountdownClock.overdue(event, now), false);
    expect(CountdownClock.overdue(event,
      now.add(const Duration(hours: 2))), true);
  });

  test('Stable order by civil date, then timed event, then ID', () {
    final state = CountdownsState(events: [
      CountdownEvent(id: 'date', title: 'Civile',
        due: dated('2026-11-01')),
      CountdownEvent(id: 'next', title: 'Dopo',
        due: dated('2026-11-02')),
      CountdownEvent(id: 'timed', title: 'Con ora',
        due: timed(DateTime.utc(2026, 11, 1, 11, 0))),
      CountdownEvent(id: 'old', title: 'Prima',
        due: dated('2026-10-30')),
    ]);
    expect(state.active.map((e) => e.id),
      ['old', 'timed', 'date', 'next']);
  });

  test('Archive and restore do not erase or duplicate events', () {
    var state = CountdownsState().add('id', 'Esame',
      dated('2026-11-20'));
    state = state.update('id', (event) => event.renamed('Esame Fisica'));
    state = state.update('id', (event) => event.withArchived(true));
    expect(state.active, isEmpty);
    expect(state.archived.single.title, 'Esame Fisica');
    state = CountdownsState.deserialize(state.serialize());
    expect(state.archived.single.due.date, '2026-11-20');
    state = state.update('id', (event) => event.withArchived(false));
    expect(state.active.single.title, 'Esame Fisica');
    expect(state.events.length, 1);
  });

  test('Corrupt, duplicate, missing or legacy dates are rejected', () {
    expect(() => CountdownsState.deserialize('{"schema":2,"events":[]}'),
      throwsFormatException);
    expect(() => CountdownsState.deserialize('bad-data'),
      throwsFormatException);
    expect(() => CountdownsState.deserialize(
      '{"schema":1,"events":[{"id":"x","title":"E",'
      '"due":{"kind":"none"},"archived":false}]}'),
      throwsFormatException);
    expect(() => CountdownEvent(id: 'x', title: 'Expired old',
        due: TaskDue.legacy(DateTime.utc(2026, 1, 1))),
      throwsFormatException);
    expect(() => CountdownsState(events: [
      CountdownEvent(id: 'same', title: 'A', due: dated('2026-10-26')),
      CountdownEvent(id: 'same', title: 'B', due: dated('2026-10-27')),
    ]), throwsFormatException);
  });
}
