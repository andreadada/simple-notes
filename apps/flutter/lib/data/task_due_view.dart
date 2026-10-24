import 'models.dart';

/// A stable calendar day number, unaffected by 23/25-hour DST transitions.
int _civilDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day)
        .millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

DateTime? taskDueCalendarDay(TaskDue due) {
  if (due.kind == 'date') {
    final d = due.date!.split('-').map(int.parse).toList();
    return DateTime(d[0], d[1], d[2]);
  }
  // Exact instants appear in the calendar of the device viewing the task.
  // Labels retain the task's saved IANA wall time as well.
  return due.instant?.toLocal();
}

bool taskInToday(LocalTask task, DateTime now) {
  if (task.completed) return false;
  final day = taskDueCalendarDay(task.due);
  return day != null && _civilDay(day) <= _civilDay(now);
}

bool taskInNextSevenDays(LocalTask task, DateTime now) {
  if (task.completed) return false;
  final day = taskDueCalendarDay(task.due);
  // Includes overdue items and 7 civil days beginning with today.
  return day != null && _civilDay(day) < _civilDay(now) + 7;
}

String taskDueLabel(TaskDue due) {
  if (due.kind == 'none') return 'Imposta scadenza';
  String dateText(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  if (due.kind == 'date') {
    return dateText(taskDueCalendarDay(due)!);
  }
  if (due.kind == 'datetime') {
    final date = due.date!.split('-').map(int.parse).toList();
    return '${dateText(DateTime(date[0], date[1], date[2]))}'
        ' · ${due.time} · ${due.timeZone}';
  }
  final local = due.instant!.toLocal();
  final time = local.hour == 0 && local.minute == 0
      ? '' : ' · ${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
  return '${dateText(local)}$time · storica';
}
