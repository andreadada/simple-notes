import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/task_insights.dart';
import 'notes_theme.dart';

/// A read-only 14-day planning board, using the actual task due semantics and
/// time blocks. Civil due dates are milestones; they are never converted into
/// fabricated midnight UTC instants.
class TimelineSpan {
  const TimelineSpan({
    required this.startDay,
    required this.endDay,
    required this.milestone,
  });

  final int startDay;
  final int endDay;
  final bool milestone;
}

class TaskTimelineSchedule {
  const TaskTimelineSchedule._();

  static DateTime civilDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static int dayOffset(DateTime day, DateTime anchor) {
    final a = DateTime.utc(day.year, day.month, day.day);
    final b = DateTime.utc(anchor.year, anchor.month, anchor.day);
    return a.difference(b).inDays;
  }

  static List<TimelineSpan> spans(
    LocalTask task, DateTime anchor, {int days = 14}
  ) {
    if (days < 1 || days > 62) {
      throw const FormatException('Finestra Gantt non valida.');
    }
    final values = <TimelineSpan>[];
    for (final slot in task.timeBlocks) {
      final start = dayOffset(slot.block.start.toLocal(), anchor);
      // End is exclusive. A slot ending at local midnight belongs to
      // the previous day; end - 1 microsecond preserves that invariant.
      final end = dayOffset(slot.block.end.toLocal()
          .subtract(const Duration(microseconds: 1)), anchor);
      if (end < 0 || start >= days) continue;
      values.add(TimelineSpan(
        startDay: start.clamp(0, days - 1).toInt(),
        endDay: end.clamp(0, days - 1).toInt(),
        milestone: false,
      ));
    }
    if (values.isEmpty) {
      final due = TaskQuery.taskDay(task);
      if (due != null) {
        final index = dayOffset(due, anchor);
        if (index >= 0 && index < days) {
          values.add(TimelineSpan(
            startDay: index, endDay: index, milestone: true,
          ));
        }
      }
    }
    return values;
  }
}

class TaskTimelineBoard extends StatefulWidget {
  const TaskTimelineBoard({
    super.key,
    required this.tasks,
    required this.onOpenTask,
  });

  final List<LocalTask> tasks;
  final ValueChanged<LocalTask> onOpenTask;

  @override
  State<TaskTimelineBoard> createState() => _TaskTimelineBoardState();
}

class _TaskTimelineBoardState extends State<TaskTimelineBoard> {
  DateTime _anchor = TaskTimelineSchedule.civilDay(DateTime.now());
  static const _dayWidth = 70.0;
  static const _labelWidth = 180.0;
  static const _days = 14;

  void _shift(int delta) => setState(() {
    _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + delta);
  });

  @override
  Widget build(BuildContext context) {
    final colors = NotesPalette.of(context);
    final scheduled = <(LocalTask, List<TimelineSpan>)>[];
    var unscheduled = 0;
    for (final task in widget.tasks) {
      if (task.completed) continue;
      final spans = TaskTimelineSchedule.spans(task, _anchor);
      if (spans.isNotEmpty) {
        scheduled.add((task, spans));
      } else if (task.timeBlocks.isEmpty && task.due.kind == 'none') {
        unscheduled++;
      }
    }
    scheduled.sort((a, b) {
      final comparison = a.$2.first.startDay.compareTo(b.$2.first.startDay);
      return comparison != 0 ? comparison :
          a.$1.title.compareTo(b.$1.title);
    });

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Wrap(
          spacing: 12, runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Pianificazione · 14 giorni', style: TextStyle(
              fontWeight: FontWeight.w600, color: colors.foreground,
            )),
            IconButton(
              key: const Key('timeline-previous'),
              tooltip: '14 giorni precedenti',
              onPressed: () => _shift(-14),
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton(
              key: const Key('timeline-today'),
              onPressed: () => setState(() =>
                  _anchor = TaskTimelineSchedule.civilDay(DateTime.now())),
              child: const Text('Oggi'),
            ),
            IconButton(
              key: const Key('timeline-next'),
              tooltip: '14 giorni successivi',
              onPressed: () => _shift(14),
              icon: const Icon(Icons.chevron_right),
            ),
            if (unscheduled > 0)
              Text('$unscheduled senza data', style: TextStyle(
                color: colors.secondaryText, fontSize: 12,
              )),
          ],
        ),
      ),
      Expanded(child: scheduled.isEmpty
        ? Center(child: Text('Nessuna attività pianificata in questi 14 giorni',
            style: TextStyle(color: colors.secondaryText)))
        : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _labelWidth + _days * _dayWidth,
            child: Column(children: [
              Row(children: [
                SizedBox(width: _labelWidth, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ATTIVITÀ', style: TextStyle(
                    fontSize: 11, color: colors.secondaryText,
                  )),
                )),
                for (var i = 0; i < _days; i++)
                  SizedBox(width: _dayWidth, child: Center(child: Text(
                    _dayLabel(i),
                    style: TextStyle(fontSize: 11,
                      color: colors.secondaryText),
                  ))),
              ]),
              const Divider(height: 18),
              Expanded(child: ListView.builder(
                itemCount: scheduled.length,
                itemExtent: 48,
                itemBuilder: (context, index) {
                  final (task, spans) = scheduled[index];
                  return Row(children: [
                    SizedBox(width: _labelWidth, child: InkWell(
                      key: Key('timeline-task-${task.id}'),
                      onTap: () => widget.onOpenTask(task),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(task.title, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    )),
                    SizedBox(
                      width: _days * _dayWidth,
                      height: 46,
                      child: Stack(children: [
                        for (var d = 0; d < _days; d++)
                          Positioned(
                            left: d * _dayWidth,
                            top: 0, bottom: 0,
                            child: Container(
                              width: _dayWidth,
                              decoration: BoxDecoration(
                                color: _weekend(d)
                                    ? colors.muted.withValues(alpha: .35)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: colors.border.withValues(alpha: .5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (final span in spans)
                          Positioned(
                            left: span.startDay * _dayWidth + 8,
                            top: 12,
                            child: Tooltip(
                              message: task.title,
                              child: InkWell(
                                onTap: () => widget.onOpenTask(task),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  height: 22,
                                  width: (span.endDay - span.startDay + 1) *
                                      _dayWidth - 16,
                                  decoration: BoxDecoration(
                                    color: task.priority >= 2
                                        ? colors.accent
                                        : colors.accent.withValues(alpha: .65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(child: Text(
                                    span.milestone ? '◆' : 'Pianificato',
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 10,
                                    ), maxLines: 1,
                                  )),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ]);
                },
              )),
            ]),
          ),
        ),
      ),
    ]);
  }

  bool _weekend(int offset) {
    final day = DateTime(_anchor.year, _anchor.month, _anchor.day + offset);
    return day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday;
  }

  String _dayLabel(int offset) {
    final day = DateTime(_anchor.year, _anchor.month, _anchor.day + offset);
    return '${day.day}/${day.month}';
  }
}
