import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import '../data/task_due_clock.dart';
import '../data/task_due_view.dart';
import 'calendar_logic.dart';
import 'ics_calendar.dart';
import 'ics_calendar_controls.dart';
import 'calendar_plan_summary.dart';
import 'calendar_quick_planner.dart';
import 'inline_editable_title.dart';
import 'inline_quick_add.dart';
import 'notes_theme.dart';
import 'task_due_editor.dart';
import 'time_block_editor.dart';
import 'time_block_view.dart';
import 'time_block_interactions.dart';
import 'time_block_timeline.dart';

/// P1.1: calendar projection over existing SQLite tasks. No new local/cloud
/// storage and no fabricated hour for date-only deadlines.
class CalendarBoard extends ConsumerStatefulWidget {
  const CalendarBoard({super.key, this.ownerId});
  final String? ownerId;

  @override
  ConsumerState<CalendarBoard> createState() => _CalendarBoardState();
}

class _CalendarBoardState extends ConsumerState<CalendarBoard> {
  CalendarMode mode = CalendarMode.week;
  DateTime selected = calendarCivil(DateTime.now());
  CalendarTaskStatus statusFilter = CalendarTaskStatus.all;
  bool importantOnly = false;
  int quickDurationMinutes = 60;
  String searchTerm = '';
  final searchController = TextEditingController();
  bool quickPlanning = false;
  IcsLibrary _ics = const IcsLibrary();

  @override
  void didUpdateWidget(covariant CalendarBoard old) {
    super.didUpdateWidget(old);
    if (old.ownerId != widget.ownerId) _ics = const IcsLibrary();
  }


  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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

  void _showPlanningMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)));
    }
  }

  /// Find an unoccupied civil-time interval among ALL tasks, never just
  /// currently filtered tasks; add exactly one slot via the existing outbox.
  Future<void> _planQuickly(String taskId) async {
    if (quickPlanning) return;
    setState(() => quickPlanning = true);
    try {
      final zone = await TaskDueClock.deviceZone();
      if (!mounted) return;
      if (zone == null) {
        _showPlanningMessage(
          'Impossibile rilevare il fuso IANA. Usa Pianifica per selezionarlo.');
        return;
      }
      final all = ref.read(localStoreProvider).tasks;
      final current = all.where((item) => item.id == taskId).firstOrNull;
      if (current == null || current.completed ||
          current.timeBlocks.length >= TimeSlotCollection.maxBlocks) {
        _showPlanningMessage('Attività non pianificabile.');
        return;
      }
      final suggested = suggestNextFreeBlock(
        tasks: all, day: selected, now: DateTime.now(),
        timeZone: zone, durationMinutes: quickDurationMinutes);
      if (suggested == null) {
        _showPlanningMessage(
          'Nessuno slot libero dalle 09:00 alle 20:00. Scegli un altro giorno '
          'o usa Pianifica.');
        return;
      }
      await ref.read(localStoreProvider.notifier)
          .addTaskTimeSlot(taskId, suggested);
      _showPlanningMessage('Blocco di $quickDurationMinutes minuti aggiunto.');
    } on FormatException catch (error) {
      _showPlanningMessage(error.message);
    } catch (_) {
      _showPlanningMessage('Pianificazione non riuscita. I dati sono intatti.');
    } finally {
      if (mounted) setState(() => quickPlanning = false);
    }
  }

  Future<void> _updateDue(LocalTask task) async {
    final due = await showTaskDueEditor(context, initial: task.due);
    if (due == null || !mounted) return;
    await ref.read(localStoreProvider.notifier).editTask(task.id,
        title: task.title, due: due, changeDue: true);
  }

  Future<void> _updateBlock(LocalTask task, {TimeSlot? slot}) async {
    final decision = await showTimeBlockEditor(context,
        initial: slot?.block, selectedDay: selected);
    if (decision == null || !mounted) return;
    final store = ref.read(localStoreProvider.notifier);
    if (slot != null) {
      if (decision.block == null) {
        await store.removeTaskTimeSlot(task.id, slot.id);
      } else {
        await store.updateTaskTimeSlot(task.id, slot.id, decision.block!);
      }
    } else if (decision.block != null) {
      await store.addTaskTimeSlot(task.id, decision.block!);
    }
  }

  Future<void> _saveBlock(String id, String slotId, TimeBlock block) =>
      ref.read(localStoreProvider.notifier)
          .updateTaskTimeSlot(id, slotId, block);

  Future<void> _shiftBlock(ScheduledSlot entry,
      TimeBlock Function(TimeBlock) mutate) async {
    try {
      await _saveBlock(entry.task.id, entry.slot.id,
          mutate(entry.slot.block));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Modifica non riuscita.')));
      }
    }
  }

  Future<void> _moveBlockToDay(
      String id, String slotId, DateTime day) async {
    final current = ref.read(localStoreProvider).tasks
        .where((task) => task.id == id).firstOrNull;
    final slot = current?.timeBlocks.where((s) => s.id == slotId).firstOrNull;
    if (slot == null) return;
    try {
      await _saveBlock(id, slotId,
          calendarMoveBlockToDay(slot.block, day));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Spostamento non riuscito.')));
      }
    }
  }

  Widget _blockCard(ScheduledSlot entry) {
    final task = entry.task;
    final slot = entry.slot;
    return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FCard(child: Row(children: [
      LongPressDraggable<CalendarBlockDrag>(
        data: CalendarBlockDrag(task.id, slot.id),
        feedback: Material(
          color: const Color(0xFF303B52),
          child: Padding(padding: const EdgeInsets.all(10),
              child: Text(task.title, style:
                const TextStyle(color: Colors.white))),
        ),
        child: Tooltip(message: 'Trascina sul giorno di destinazione',
          child: Icon(Icons.drag_indicator, size: 18,
            color: NotesPalette.of(context).accent)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(timeBlockLabel(slot.block),
              style: TextStyle(fontSize: 11,
                  color: NotesPalette.of(context).secondaryText)),
        ],
      )),
      if (task.timeBlocks.isNotEmpty) ...[
        IconButton(
          key: Key('calendar-block-earlier-${task.id}-${slot.id}'),
          tooltip: 'Sposta 15 minuti prima',
          onPressed: () => _shiftBlock(entry,
              (block) => calendarMoveBlock(block, -15)),
          icon: const Icon(Icons.keyboard_arrow_up, size: 17),
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          key: Key('calendar-block-later-${task.id}-${slot.id}'),
          tooltip: 'Sposta 15 minuti dopo',
          onPressed: () => _shiftBlock(entry,
              (block) => calendarMoveBlock(block, 15)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 17),
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          padding: EdgeInsets.zero,
        ),
      ],
      FButton.icon(
        key: Key('calendar-edit-block-${task.id}-${slot.id}'),
        variant: FButtonVariant.ghost,
        onPress: () => _updateBlock(task, slot: slot),
        child: const Icon(Icons.edit_calendar_outlined, size: 18),
      ),
    ])),
  );
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
            maxLength: 1024,
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
              style: TextStyle(fontSize: 11,
                  color: NotesPalette.of(context).secondaryText)),
          if (task.due.kind == 'datetime')
            Text(taskDueLabel(task.due),
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10,
                  color: NotesPalette.of(context).secondaryText)),
        ],
      )),
      const SizedBox(width: 5),
      FButton.icon(
        key: Key('calendar-schedule-${task.id}'),
        variant: FButtonVariant.ghost,
        onPress: () => _updateBlock(task),
        child: const Icon(Icons.timelapse_outlined, size: 18),
      ),
      FButton.icon(
        key: Key('calendar-edit-due-${task.id}'),
        variant: FButtonVariant.ghost,
        onPress: () => _updateDue(task),
        child: const Icon(Icons.event_outlined, size: 18),
      ),
    ])),
  );

  Widget _icsCard(IcsEvent e, {bool compact = false}) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 6 : 9),
    child: FCard(child: Row(children: [
      Icon(Icons.lock_outline, size: 17,
        color: NotesPalette.of(context).secondaryText),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.title, maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 12 : 14)),
          Text('${e.clock} · ICS: ${e.source} · sola lettura',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10,
              color: NotesPalette.of(context).secondaryText)),
        ],
      )),
    ])),
  );

  Widget _agenda(DateTime day, List<LocalTask> tasks,
      {bool includeHeading = true}) {
    final items = calendarTasksForDay(tasks, day);
    final external = _ics.onDay(day);
    final blocks = calendarTimeSlotsForDay(tasks, day);
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
        if (blocks.isEmpty && items.isEmpty && external.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nessun blocco o attività in questo giorno.',
              style: TextStyle(color: NotesPalette.of(context).secondaryText)),
          ),
        if (mode != CalendarMode.day && blocks.isNotEmpty) ...[
          Text('BLOCCHI DI TEMPO', style: TextStyle(
              color: NotesPalette.of(context).secondaryText, fontSize: 12,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final entry in blocks) _blockCard(entry),
          const SizedBox(height: 12),
        ],
        if (items.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('SCADENZE', style: TextStyle(
              color: NotesPalette.of(context).secondaryText,
              fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        if (allDay.isNotEmpty) ...[
          Text('Senza orario', style: TextStyle(
              color: NotesPalette.of(context).secondaryText, fontSize: 12)),
          const SizedBox(height: 8),
          for (final task in allDay) _taskCard(task),
        ],
        if (scheduled.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Orari', style: TextStyle(
              color: NotesPalette.of(context).secondaryText, fontSize: 12)),
          const SizedBox(height: 8),
          for (final task in scheduled) _taskCard(task),
        ],
        if (external.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('EVENTI ESTERNI · SOLA LETTURA',
            style: TextStyle(fontSize: 12,
              color: NotesPalette.of(context).secondaryText)),
          const SizedBox(height: 8),
          for (final event in external) _icsCard(event),
        ],
        if (mode == CalendarMode.day) ...[
          const SizedBox(height: 14),
          Text('TIMELINE · trascina per spostare, '
              'usa la maniglia inferiore per ridimensionare',
            style: TextStyle(color: NotesPalette.of(context).secondaryText, fontSize: 11)),
          const SizedBox(height: 10),
          TimeBlockTimeline(
            key: Key('calendar-day-timeline-${calendarDateKey(day)}'),
            day: day, tasks: tasks, onChange: _saveBlock,
          ),
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
                style: TextStyle(fontSize: 11,
                    color: NotesPalette.of(context).secondaryText)),
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
          final blocks = calendarTimeSlotsForDay(tasks, day);
          final external = _ics.onDay(day);
          final focused = calendarDateKey(day) == calendarDateKey(selected);
          final today = calendarDateKey(day) ==
              calendarDateKey(DateTime.now());
          final inMonth = day.month == selected.month;
          return CalendarDayDropZone(
            day: day, onDrop: _moveBlockToDay,
            child: Material(
              color: focused ? NotesPalette.of(context).accent.withValues(alpha: 0.14)
                  : NotesPalette.of(context).surface,
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
                      color: !inMonth ? NotesPalette.of(context).secondaryText
                          : today ? NotesPalette.of(context).accent : null,
                      fontWeight: today || focused
                          ? FontWeight.bold : FontWeight.normal)),
                    if (items.isNotEmpty || blocks.isNotEmpty || external.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(width < 650
                          ? '${items.length} · ${blocks.length} · ${external.length}'
                          : '${items.length} scad. · ${blocks.length} blocchi · ${external.length} ICS',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10,
                            color: NotesPalette.of(context).secondaryText)),
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
          ));
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
              CalendarDayDropZone(
                day: day, onDrop: _moveBlockToDay,
                child: FButton(
                  key: Key('calendar-week-${calendarDateKey(day)}'),
                  variant: calendarDateKey(day) == calendarDateKey(selected)
                      ? FButtonVariant.primary : FButtonVariant.outline,
                  onPress: () => setState(() {
                    selected = day;
                    mode = CalendarMode.day;
                  }),
                  child: Text('${_weekdays[day.weekday - 1]} ${day.day}'),
                ),
              ),
              const SizedBox(height: 10),
              TimeBlockTimeline(
                day: day,
                tasks: tasks,
                compact: true, onChange: _saveBlock,
              ),
              const SizedBox(height: 10),
              for (final task in calendarTasksForDay(tasks, day))
                _taskCard(task, compact: true),
              for (final event in _ics.onDay(day))
                _icsCard(event, compact: true),
              if (calendarTasksForDay(tasks, day).isEmpty &&
                  calendarTimeSlotsForDay(tasks, day).isEmpty &&
                  _ics.onDay(day).isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('—', style: TextStyle(
                      color: NotesPalette.of(context).secondaryText)),
                ),
            ]),
          )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(localStoreProvider).tasks;
    final tasks = filterCalendarTasks(allTasks,
        status: statusFilter, search: searchTerm,
        importantOnly: importantOnly);
    final summary = calendarPlanSummary(tasks, selected, mode);
    final unscheduled = tasks.where((task) =>
        task.due.kind == 'none' && task.timeBlocks.isEmpty &&
        !task.completed).length;
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
          IcsCalendarControls(ownerId: widget.ownerId,
            onChanged: (lib) {
              if (mounted) setState(() => _ics = lib);
            },
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
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final option in CalendarTaskStatus.values)
              FButton(
                key: Key('calendar-filter-${option.name}'),
                variant: statusFilter == option
                    ? FButtonVariant.primary : FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                onPress: () => setState(() => statusFilter = option),
                child: Text(switch (option) {
                  CalendarTaskStatus.all => 'Tutte',
                  CalendarTaskStatus.open => 'Da fare',
                  CalendarTaskStatus.completed => 'Completate',
                }),
              ),
            FButton(
              key: const Key('calendar-filter-important'),
              variant: importantOnly
                  ? FButtonVariant.primary : FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: () => setState(() => importantOnly = !importantOnly),
              child: const Text('Priorità P1–P3'),
            ),
          ]),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FTextField(
              key: const Key('calendar-search'),
              hint: 'Cerca attività, tag o sottotask',
              control: FTextFieldControl.managed(
                controller: searchController,
                onChange: (value) => setState(() => searchTerm = value.text)),
            ),
          ),
          const SizedBox(height: 8),
          Text('${tasks.length} di ${allTasks.length} attività visibili',
            key: const Key('calendar-filter-count'),
            style: TextStyle(fontSize: 11,
                color: NotesPalette.of(context).secondaryText)),
          const SizedBox(height: 8),
          Text('${summary.slotCount} blocchi · '
              '${calendarMinutesLabel(summary.plannedMinutes)} pianificate · '
              '${calendarMinutesLabel(summary.completedMinutes)} completate',
            key: const Key('calendar-summary'),
            style: TextStyle(fontSize: 12,
                color: NotesPalette.of(context).secondaryText)),
          const SizedBox(height: 5),
          Text('Trascina i blocchi per spostare orari e date · '
              '$unscheduled attività da pianificare',
            style: TextStyle(fontSize: 11,
                color: NotesPalette.of(context).secondaryText)),
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
                style: TextStyle(fontSize: 12,
                    color: NotesPalette.of(context).secondaryText)),
              const SizedBox(height: 7),
              InlineQuickAdd(
                key: const Key('calendar-quick-add'),
                hint: 'Nuova attività per questo giorno',
                maxLength: 1024,
                onAdd: _createTask,
              ),
              if (unscheduled > 0) ...[
                const SizedBox(height: 18),
                Text('DA PIANIFICARE',
                  style: TextStyle(fontSize: 12,
                      color: NotesPalette.of(context).secondaryText)),
                Wrap(spacing: 7, runSpacing: 6, children: [
                  Text('Durata rapida:', style: TextStyle(
                    color: NotesPalette.of(context).secondaryText, fontSize: 12)),
                  for (final duration in [30, 60, 90])
                    FButton(
                      key: Key('calendar-quick-duration-$duration'),
                      variant: quickDurationMinutes == duration
                          ? FButtonVariant.primary : FButtonVariant.outline,
                      mainAxisSize: MainAxisSize.min,
                      onPress: () => setState(() =>
                          quickDurationMinutes = duration),
                      child: Text('${duration}m'),
                    ),
                ]),
                const SizedBox(height: 5),
                for (final task in tasks.where((task) =>
                    task.due.kind == 'none' &&
                    task.timeBlocks.isEmpty && !task.completed))
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(children: [
                      Expanded(child: Text(task.title, maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                      FButton(
                        key: Key('calendar-quick-plan-${task.id}'),
                        variant: FButtonVariant.outline,
                        mainAxisSize: MainAxisSize.min,
                        onPress: quickPlanning
                            ? null : () => _planQuickly(task.id),
                        child: const Text('Slot libero'),
                      ),
                      const SizedBox(width: 5),
                      FButton(
                        key: Key('calendar-plan-unscheduled-${task.id}'),
                        variant: FButtonVariant.ghost,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () => _updateBlock(task),
                        child: const Text('Pianifica'),
                      ),
                    ]),
                  ),
              ],
            ],
          ),
        ),
      )),
    ]);
  }
}
