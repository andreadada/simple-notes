import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import '../data/task_due_view.dart';
import 'eisenhower_logic.dart';
import 'inline_editable_title.dart';
import 'notes_theme.dart';
import 'task_due_editor.dart';

/// Four responsive quadrants over existing tasks; no new entity or schema.
class EisenhowerBoard extends ConsumerWidget {
  const EisenhowerBoard({super.key, required this.onOpenTask});
  final void Function(LocalTask task) onOpenTask;

  Future<void> _editDue(BuildContext context, WidgetRef ref,
      LocalTask task) async {
    final due = await showTaskDueEditor(context, initial: task.due);
    if (due == null || !context.mounted) return;
    await ref.read(localStoreProvider.notifier)
        .setTaskDueSemantics(task.id, due);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(localStoreProvider).tasks;
    final groups = EisenhowerLogic.group(tasks, DateTime.now());
    return LayoutBuilder(builder: (context, limits) {
      final columns = limits.maxWidth >= 780 ? 2 : 1;
      final width = (limits.maxWidth - 32 - (columns - 1) * 12) / columns;
      return SingleChildScrollView(
        key: const Key('eisenhower-board'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La matrice si aggiorna automaticamente da priorità e scadenze.',
              style: TextStyle(color: NotesPalette.of(context).secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'P2/P3 = importante · Scadenza entro 48 ore = urgente; '
              'le date senza orario usano oggi/domani.',
              style: TextStyle(color: NotesPalette.of(context).secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final quadrant in EisenhowerQuadrant.values)
                  SizedBox(
                    key: Key('eisenhower-${quadrant.name}'),
                    width: width,
                    child: FCard(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(quadrant.label,
                                style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700))),
                              Text('${groups[quadrant]!.length}',
                                style: TextStyle(
                                  color: NotesPalette.of(context).secondaryText)),
                            ]),
                            const SizedBox(height: 4),
                            Text(quadrant.description, style: TextStyle(
                              color: NotesPalette.of(context).secondaryText, fontSize: 12)),
                            const SizedBox(height: 12),
                            if (groups[quadrant]!.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Nessuna attività',
                                  style: TextStyle(
                                    color: NotesPalette.of(context).secondaryText)),
                              ),
                            for (final task in groups[quadrant]!)
                              Padding(
                                key: Key('eisenhower-task-${task.id}'),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FCheckbox(
                                          value: task.completed,
                                          onChange: (_) => ref.read(
                                            localStoreProvider.notifier)
                                            .toggleTask(task.id),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: InlineEditableTitle(
                                          key: Key('eisenhower-title-${task.id}'),
                                          value: task.title,
                                          maxLength: 1024,
                                          semanticsLabel: 'Titolo attività modificabile',
                                          style: const TextStyle(fontSize: 14),
                                          onSave: (value) => ref.read(
                                            localStoreProvider.notifier)
                                            .renameTask(task.id, value),
                                          onTap: () => onOpenTask(task),
                                        )),
                                        FButton.icon(
                                          key: Key('eisenhower-open-${task.id}'),
                                          variant: FButtonVariant.ghost,
                                          onPress: () => onOpenTask(task),
                                          child: const Icon(Icons.chevron_right,
                                            size: 17),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32),
                                      child: Wrap(spacing: 6, runSpacing: 6,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          FPopoverMenu(
                                            menu: [
                                              .group(children: [
                                                for (var p = 0; p <= 3; p++)
                                                  .item(
                                                    title: Text(p == 0
                                                      ? 'Normale' : 'P$p'),
                                                    onPress: () => ref.read(
                                                      localStoreProvider.notifier)
                                                      .setTaskPriority(task.id, p),
                                                  ),
                                              ]),
                                            ],
                                            menuBuilder: (context, controller,
                                                menu) => menu!,
                                            builder: (context, controller,
                                                child) => FButton(
                                              key: Key('eisenhower-priority-${task.id}'),
                                              variant: FButtonVariant.outline,
                                              mainAxisSize: MainAxisSize.min,
                                              size: FButtonSizeVariant.sm,
                                              onPress: controller.toggle,
                                              child: child!,
                                            ),
                                            child: Text(task.priority == 0
                                              ? 'Normale' : 'P${task.priority}'),
                                          ),
                                          FButton(
                                            key: Key('eisenhower-due-${task.id}'),
                                            variant: FButtonVariant.outline,
                                            mainAxisSize: MainAxisSize.min,
                                            size: FButtonSizeVariant.sm,
                                            onPress: () => _editDue(
                                              context, ref, task),
                                            prefix: const Icon(
                                              Icons.event_outlined, size: 14),
                                            child: Text(task.due.kind == 'none'
                                              ? 'Scadenza'
                                              : taskDueLabel(task.due)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
