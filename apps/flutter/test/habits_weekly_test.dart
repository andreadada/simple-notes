import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/ui/habits_model.dart';
import 'package:simple_notes/ui/habits_weekly.dart';

LocalHabit habit({
  int target = 3,
  String created = '2026-10-19',
  List<String> days = const [],
}) => LocalHabit(id: 'read', title: 'Leggere',
  createdDay: created, weeklyTarget: target, checkIns: days);

void main() {
  test('Legacy P1.11 document safely defaults to daily seven-day target', () {
    const source = '{"schema":1,"habits":[{"id":"read","title":"Leggere",'
        '"createdDay":"2026-10-19","archived":false,'
        '"checkIns":["2026-10-19","2026-10-20"]}]}';
    final restored = HabitsState.deserialize(source).habits.single;
    expect(restored.weeklyTarget, 7);
    expect(restored.checkIns.length, 2);
    final changed = restored.withWeeklyTarget(3);
    expect(changed.weeklyTarget, 3);
    expect(changed.checkIns, restored.checkIns);
    expect(HabitsState.deserialize(HabitsState(habits: [changed])
      .serialize()).habits.single.weeklyTarget, 3);
  });

  test('Invalid weekly targets fail before corrupting preferences', () {
    expect(() => habit(target: 0), throwsFormatException);
    expect(() => habit(target: 8), throwsFormatException);
    expect(() => HabitsState.deserialize(
      '{"schema":1,"habits":[{"id":"read","title":"Leggere",'
      '"createdDay":"2026-10-19","archived":false,'
      '"weeklyTarget":"many","checkIns":[]}]}'), throwsFormatException);
    final item = habit(target: 3);
    expect(() => item.withWeeklyTarget(-1), throwsFormatException);
    expect(item.weeklyTarget, 3);
  });

  test('Monday-first week uses civil days through DST Europe/Rome', () {
    expect(HabitDay.of(HabitWeek.monday(DateTime(2026, 10, 26))),
      '2026-10-26');
    expect(HabitDay.of(HabitWeek.monday(DateTime(2026, 10, 25))),
      '2026-10-19');
    expect(HabitDay.of(HabitWeek.shifted(DateTime(2026, 10, 19), 1)),
      '2026-10-26');
    final item = habit(days: [
      '2026-10-23', '2026-10-24', '2026-10-25',
      '2026-10-26', '2026-10-27',
    ]);
    expect(HabitWeek.count(item, DateTime(2026, 10, 19),
      DateTime(2026, 10, 27)), 3);
    expect(HabitWeek.currentProgress(item, DateTime(2026, 10, 27)), 2);
    expect(HabitWeek.currentGoalReached(item, DateTime(2026, 10, 27)), false);
  });

  test('Ongoing current week does not break a completed prior weekly streak', () {
    final today = DateTime(2026, 10, 27);
    final item = habit(days: [
      '2026-10-19','2026-10-21','2026-10-24',
      '2026-10-26',
    ]);
    expect(HabitWeek.currentProgress(item, today), 1);
    expect(HabitWeek.streak(item, today), 1);
    final reached = item.toggle(DateTime(2026, 10, 27), today)
        .withWeeklyTarget(2);
    expect(HabitWeek.currentGoalReached(reached, today), true);
    expect(HabitWeek.streak(reached, today), 2);
    expect(HabitWeek.streak(item, DateTime(2026, 11, 3)), 0);
  });

  test('Archived and renamed habits keep target, check-ins and history', () {
    final original = habit(target: 4, days: ['2026-10-19']);
    final restored = original.renamed('Leggere bene')
        .withArchived(true).withArchived(false);
    expect(restored.title, 'Leggere bene');
    expect(restored.weeklyTarget, 4);
    expect(restored.checkIns, original.checkIns);
    expect(original.title, 'Leggere');
  });

  test('Changing a weekly goal never credits extra check-in days', () {
    final item = habit(target: 7, days: ['2026-10-26']);
    final changed = item.withWeeklyTarget(1);
    expect(HabitWeek.currentGoalReached(changed, DateTime(2026, 10, 26)), true);
    expect(item.weeklyTarget, 7);
    expect(item.checkIns, {'2026-10-26'});
    expect(changed.checkIns, {'2026-10-26'});
  });
}
