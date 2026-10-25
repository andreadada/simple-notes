import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import '../data/models.dart';
import '../data/task_due_view.dart';
import 'calendar_logic.dart';
import 'inline_editable_title.dart';
import 'inline_quick_add.dart';
import 'notes_theme.dart';
import 'task_due_editor.dart';

/// P1.1: calendar projection over existing SQLite tasks. No new local/cloud
/// storage and no fabricated hour for date-only deadlines.
class CalendarBoard extends ConsumerStatefulWidget {
  const CalendarBoard({super.key});

  @override
  ConsumerState<CalendarBoard> createState() => _CalendarBoardState();
}

class _CalendarBoardState extends ConsumerState<CalendarBoard> {
  CalendarMode mode = CalendarMode.week;
  DateTime selected = calendarCivil(DateTime.now());

  static const _months = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];
  static const _weekdays = [
    'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom',
  ];

  String _dayLabel(DateTime day) =>
      '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]} ${day.year}';

  String _rangeLabel() {
    if (mode == CalendarMode.day) return _dayLabel(selected);
    if (mode == CalendarMode.month) {
      return '${_months[selected.month - 1]} ${selected.year}';
    }
    final days = calendarWeekDays(selected);
    final end = days.last;
    return '${days.first.day} ${_months[days.first.month - 1]}'
        ' – ${end.day} ${_months[end.month - 1]} ${end.year}';
  }

  Future<void> _createTask(String title) =>
      ref.read(localStoreProvider.notifier).addTask(
        title, due: TaskDue.dateOnly(calendarDateKey(selected)));

  Future<void> _updateDue(LocalTask task) async {
    final due = await showTaskDueEditor(context, initial: task.due);
    if (due == null || !mounted) return;
    await ref.read(localStoreProvider.notifier).editTask(task.id,
        title: task.title, due: due, changeDue: true);
  }

  Widget _taskCard(LocalTask task, {bool compact = false}) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 6 : 9),
    child: FCard(child: Row(children: [
      FCheckbox(
        key: Key('calendar-complete-${task.id}'),
        value: task.completed,
        onChange: (_) =>
            ref.read(localStoreProvider.notifier).toggleTask(task.id),
      ),
      const SizedBox(width: 9),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineEditableTitle(
            key: Key('calendar-rename-${task.id}'),
            value: task.title,
            semanticsLabel: 'Titolo attività nel calendario',
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              decoration: task.completed
                  ? TextDecoration.lineThrough : TextDecoration.none,
            ),
            onSave: (value) =>
                ref.read(localStoreProvider.notifier).renameTask(task.id, value),
          ),
          const SizedBox(height: 4),
          Text(calendarClockLabel(task),
              style: const TextStyle(fontSize: 11,
                  color: NotesPalette.secondaryText)),
          if (task.due.kind == 'datetime')
            Text(taskDueLabel(task.due),
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10,
                  color: NotesPalette.secondaryText)),
        ],
      )),
      const SizedBox(width: 5),
      FButton.icon(
        key: Key('calendar-edit-due-${task.id}'),
        variant: FButtonVariant.ghost,
        onPress: () => _updateDue(task),
        child: const Icon(Icons.event_outlined, size: 18),
      ),
    ])),
  );

  Widget _agenda(DateTime day, List<LocalTask> tasks,
      {bool includeHeading = true}) {
    final items = calendarTasksForDay(tasks, day);
    final allDay = items.where((t) => t.due.kind == 'date').toList();
    final scheduled = items.where((t) => t.due.kind != 'date').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeHeading) ...[
          Text(_dayLabel(day), style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
        ],
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nessuna attività con scadenza in questo giorno.',
              style: TextStyle(color: NotesPalette.secondaryText)),
          ),
        if (allDay.isNotEmpty) ...[
          const Text('Senza orario', style: TextStyle(
              color: NotesPalette.secondaryText, fontSize: 12)),
          const SizedBox(height: 8),
          for (final task in allDay) _taskCard(task),
        ],
        if (scheduled.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Orari', style: TextStyle(
              color: NotesPalette.secondaryText, fontSize: 12)),
          const SizedBox(height: 8),
          for (final task in scheduled) _taskCard(task),
        ],
      ],
    );
  }

  Widget _month(List<LocalTask> tasks, double width) {
    final days = calendarMonthDays(selected);
    final cellHeight = width < 650 ? 64.0 : 105.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (final name in _weekdays)
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(name, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11,
                    color: NotesPalette.secondaryText)),
          )),
      ]),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: cellHeight,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final day = days[index];
          final items = calendarTasksForDay(tasks, day);
          final focused = calendarDateKey(day) == calendarDateKey(selected);
          final today = calendarDateKey(day) ==
              calendarDateKey(DateTime.now());
          final inMonth = day.month == selected.month;
          return Material(
            color: focused ? NotesPalette.accent.withValues(alpha: 0.14)
                : const Color(0xff252525),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              key: Key('calendar-date-${calendarDateKey(day)}'),
              borderRadius: BorderRadius.circular(9),
              onTap: () => setState(() => selected = day),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${day.day}', style: TextStyle(fontSize: 12,
                      color: !inMonth ? NotesPalette.secondaryText
                          : today ? NotesPalette.accent : null,
                      fontWeight: today || focused
                          ? FontWeight.bold : FontWeight.normal)),
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text('${items.length} attività',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10,
                            color: NotesPalette.secondaryText)),
                      if (width >= 650)
                        for (final task in items.take(2))
                          Text('• ${task.title}', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough : null)),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 22),
      _agenda(selected, tasks),
    ]);
  }

  Widget _week(List<LocalTask> tasks, double width) {
    final days = calendarWeekDays(selected);
    final cellWidth = width >= 1190 ? (width - 48) / 7 : 162.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final day in days)
          SizedBox(width: cellWidth, child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(children: [
              FButton(
                key: Key('calendar-week-${calendarDateKey(day)}'),
                variant: calendarDateKey(day) == calendarDateKey(selected)
                    ? FButtonVariant.primary : FButtonVariant.outline,
                onPress: () => setState(() {
                  selected = day;
                  mode = CalendarMode.day;
                }),
                child: Text('${_weekdays[day.weekday - 1]} ${day.day}'),
              ),
              const SizedBox(height: 10),
              for (final task in calendarTasksForDay(tasks, day))
                _taskCard(task, compact: true),
              if (calendarTasksForDay(tasks, day).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('—', style: TextStyle(
                      color: NotesPalette.secondaryText)),
                ),
            ]),
          )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(localStoreProvider).tasks;
    final unscheduled = tasks.where((task) =>
        calendarTaskCivilDay(task) == null && !task.completed).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 5, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FButton.icon(
                key: const Key('calendar-prev'),
                variant: FButtonVariant.ghost,
                onPress: () => setState(() =>
                    selected = calendarMove(selected, mode, -1)),
                child: const Icon(Icons.chevron_left),
              ),
              FButton.icon(
                key: const Key('calendar-next'),
                variant: FButtonVariant.ghost,
                onPress: () => setState(() =>
                    selected = calendarMove(selected, mode, 1)),
                child: const Icon(Icons.chevron_right),
              ),
              FButton(
                key: const Key('calendar-today'),
                variant: FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                onPress: () => setState(() =>
                    selected = calendarCivil(DateTime.now())),
                child: const Text('Oggi'),
              ),
              Text(_rangeLabel(), key: const Key('calendar-range'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 6, children: [
            for (final option in CalendarMode.values)
              FButton(
                key: Key('calendar-mode-${option.name}'),
                variant: mode == option
                    ? FButtonVariant.primary : FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                onPress: () => setState(() => mode = option),
                child: Text(switch (option) {
                  CalendarMode.day => 'Giorno',
                  CalendarMode.week => 'Settimana',
                  CalendarMode.month => 'Mese',
                }),
              ),
          ]),
          const SizedBox(height: 6),
          Text('Solo attività con scadenza · $unscheduled senza scadenza',
            style: const TextStyle(fontSize: 11,
                color: NotesPalette.secondaryText)),
        ]),
      ),
      Expanded(child: LayoutBuilder(
        builder: (context, limits) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mode == CalendarMode.day) _agenda(selected, tasks),
              if (mode == CalendarMode.week) _week(tasks, limits.maxWidth - 32),
              if (mode == CalendarMode.month) _month(tasks, limits.maxWidth - 32),
              const SizedBox(height: 18),
              Text('Aggiungi attività al ${selected.day}/${selected.month}/${selected.year}',
                style: const TextStyle(fontSize: 12,
                    color: NotesPalette.secondaryText)),
              const SizedBox(height: 7),
              InlineQuickAdd(
                key: const Key('calendar-quick-add'),
                hint: 'Nuova attività per questo giorno',
                maxLength: 1024,
                onAdd: _createTask,
              ),
            ],
          ),
        ),
      )),
    ]);
  }
}
