import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/habits_model.dart';

void main() {
  final today = DateTime(2026, 10, 26);
  final yesterday = DateTime(2026, 10, 25);

  test('Date-only stamps are local civil days and reject rollover days', () {
    expect(HabitDay.of(DateTime(2026, 10, 26, 23, 59)), '2026-10-26');
    expect(HabitDay.parse('2026-10-26'), DateTime(2026, 10, 26));
    expect(() => HabitDay.parse('2026-02-30'), throwsFormatException);
    expect(() => HabitDay.parse('2026-2-3'), throwsFormatException);
    expect(HabitDay.of(HabitDay.shift(DateTime(2026, 3, 29), 1)),
        '2026-03-30'); // DST boundary: advance civil calendar, not UTC hours.
  });

  test('Today and yesterday retain streak; missed days break streak', () {
    final habit = LocalHabit(id: 'a', title: 'Leggere',
      createdDay: '2026-10-20', checkIns: [
        '2026-10-23', '2026-10-24', '2026-10-25',
      ]);
    expect(habit.streak(today), 3);
    expect(habit.checked(today), isFalse);
    final completed = habit.toggle(today, today);
    expect(completed.streak(today), 4);
    expect(completed.countLast(today, 7), 4);
    final undone = completed.toggle(today, today);
    expect(undone.checkIns, habit.checkIns);
    expect(undone.streak(today), 3);
    expect(habit.streak(DateTime(2026, 10, 28)), 0);
  });

  test('A future day and days before creation are never accepted', () {
    final habit = LocalHabit(id: 'a', title: 'Acqua',
        createdDay: '2026-10-25');
    expect(() => habit.toggle(DateTime(2026, 10, 27), today), throwsStateError);
    expect(() => habit.toggle(DateTime(2026, 10, 24), today), throwsStateError);
    expect(habit.toggle(yesterday, today).checked(yesterday), isTrue);
  });

  test('Rename and archive preserve history; restore is lossless', () {
    var state = HabitsState().add('one', 'Studiare', yesterday);
    state = state.update('one', (h) => h.toggle(yesterday, today));
    state = state.update('one', (h) => h.renamed('Studiare bene'));
    state = state.update('one', (h) => h.withArchived(true));
    expect(state.active, isEmpty);
    expect(state.archived.single.checkIns, {'2026-10-25'});
    state = HabitsState.deserialize(state.serialize());
    state = state.update('one', (h) => h.withArchived(false));
    expect(state.active.single.title, 'Studiare bene');
    expect(state.active.single.checkIns, {'2026-10-25'});
    expect(state.checkedToday(today), 0);
  });

  test('Malformed JSON and repeated check-ins never silently overwrite', () {
    expect(() => HabitsState.deserialize('{"schema":2,"habits":[]}'),
      throwsFormatException);
    expect(() => HabitsState.deserialize('invalid'), throwsFormatException);
    expect(() => HabitsState.deserialize(
        '{"schema":1,"habits":[{"id":"a","title":"X",'
        '"createdDay":"2026-10-25","archived":false,'
        '"checkIns":["2026-10-25","2026-10-25"]}]}'),
      throwsFormatException);
    expect(() => HabitsState(habits: [
      LocalHabit(id: 'id', title: 'Uno', createdDay: '2026-10-26'),
      LocalHabit(id: 'id', title: 'Due', createdDay: '2026-10-26'),
    ]), throwsFormatException);
  });

  test('Check-in does not modify source and 30-day count handles gaps', () {
    final habit = LocalHabit(id: 'a', title: 'Esercizi',
      createdDay: '2026-10-01', checkIns: ['2026-10-01', '2026-10-25']);
    final changed = habit.toggle(today, today);
    expect(habit.checked(today), isFalse);
    expect(changed.checked(today), isTrue);
    expect(changed.countLast(today, 30), 3);
    expect(changed.countLast(today, 7), 2);
    expect(changed.streak(today), 2);
  });
}
