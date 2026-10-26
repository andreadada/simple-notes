import 'habits_model.dart';

/// Civil Monday–Sunday weeks; never add UTC hours through a DST transition.
abstract final class HabitWeek {
  static DateTime monday(DateTime day) {
    final civil = DateTime(day.year, day.month, day.day);
    return DateTime(civil.year, civil.month,
        civil.day - (civil.weekday - DateTime.monday));
  }

  static DateTime shifted(DateTime monday, int weeks) =>
      DateTime(monday.year, monday.month, monday.day + weeks * 7);

  static int count(LocalHabit habit, DateTime weekStart, DateTime today) {
    final current = HabitDay.of(today);
    final first = HabitDay.of(weekStart);
    var total = 0;
    for (var offset = 0; offset < 7; offset++) {
      final civil = DateTime(weekStart.year, weekStart.month,
          weekStart.day + offset);
      final label = HabitDay.of(civil);
      if (label.compareTo(current) > 0) break;
      if (label.compareTo(first) >= 0 &&
          label.compareTo(habit.createdDay) >= 0 &&
          habit.checkIns.contains(label)) {
        total++;
      }
    }
    return total;
  }

  static int currentProgress(LocalHabit habit, DateTime today) =>
      count(habit, monday(today), today);

  static bool currentGoalReached(LocalHabit habit, DateTime today) =>
      currentProgress(habit, today) >= habit.weeklyTarget;

  /// A week is completed only after its target is met; for an unfinished
  /// current week, streak continues from the immediately preceding week.
  static int streak(LocalHabit habit, DateTime today) {
    var week = monday(today);
    final firstWeek = monday(HabitDay.parse(habit.createdDay));
    if (count(habit, week, today) < habit.weeklyTarget) {
      week = shifted(week, -1);
    }
    var result = 0;
    while (!week.isBefore(firstWeek) &&
        count(habit, week, today) >= habit.weeklyTarget) {
      result++;
      week = shifted(week, -1);
    }
    return result;
  }
}
