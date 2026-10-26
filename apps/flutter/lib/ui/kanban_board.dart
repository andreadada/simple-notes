import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import '../data/task_due_view.dart';
import 'inline_editable_title.dart';
import 'inline_quick_add.dart';
import 'kanban_logic.dart';
import 'notes_theme.dart';

/// List-based Kanban: moving a card changes task.listId through LocalStore.
/// No separate unsynchronized board, cached statuses or destructive writes.
class KanbanBoard extends ConsumerWidget {
  const KanbanBoard({
    super.key,
    required this.onOpenTask,
    required this.onCreateList,
  });
  final void Function(LocalTask) onOpenTask;
  final VoidCallback onCreateList;

  Future<void> _move(WidgetRef ref, LocalData data,
      String taskId, String? targetId) async {
    if (!KanbanLogic.canMove(data, taskId, targetId)) return;
    await ref.read(localStoreProvider.notifier).setTaskList(taskId, targetId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(localStoreProvider);
    final columns = KanbanLogic.columns(data);
    final touch = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    return LayoutBuilder(builder: (context, bounds) {
      final columnWidth = bounds.maxWidth < 450 ? 278.0 : 300.0;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Wrap(
            spacing: 12, runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Trascina una card tra le liste o usa «Sposta in».',
                style: TextStyle(fontSize: 12,
                  color: NotesPalette.secondaryText)),
              FButton(
                key: const Key('kanban-create-list'),
                variant: FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                onPress: onCreateList,
                prefix: const Icon(Icons.add, size: 16),
                child: const Text('Nuova lista'),
              ),
            ],
          ),
        ),
        Expanded(child: SingleChildScrollView(
          key: const Key('kanban-board'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final column in columns) ...[
                SizedBox(
                  key: Key('kanban-column-${column.id ?? 'inbox'}'),
                  width: columnWidth,
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) =>
                        KanbanLogic.canMove(data, details.data, column.id),
                    onAcceptWithDetails: (details) =>
                        _move(ref, data, details.data, column.id),
                    builder: (context, candidates, rejects) =>
                      FCard(child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(children: [
                            Expanded(child: column.id == null
                              ? const Text('Inbox', style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16))
                              : InlineEditableTitle(
                                  key: Key('kanban-title-${column.id}'),
                                  value: column.title,
                                  semanticsLabel: 'Nome lista modificabile',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                                  onSave: (title) => ref.read(
                                      localStoreProvider.notifier)
                                      .renameList(column.id!, title),
                                )),
                            Text('${column.tasks.length}',
                              style: const TextStyle(
                                color: NotesPalette.secondaryText)),
                          ]),
                          const SizedBox(height: 10),
                          Expanded(child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: candidates.isNotEmpty
                                  ? NotesPalette.accent.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: candidates.isNotEmpty
                                  ? NotesPalette.accent
                                  : Colors.transparent),
                            ),
                            child: ListView(
                              key: Key('kanban-items-${column.id ?? 'inbox'}'),
                              padding: const EdgeInsets.all(4),
                              children: [
                                if (column.tasks.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('Trascina qui un’attività',
                                      style: TextStyle(fontSize: 12,
                                        color: NotesPalette.secondaryText)),
                                  ),
                                for (final task in column.tasks)
                                  Padding(
                                    key: Key('kanban-task-${task.id}'),
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Builder(builder: (context) {
                                      final card = FCard(child: Padding(
                                        padding: const EdgeInsets.all(9),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              const Icon(Icons.drag_indicator,
                                                size: 18,
                                                color: NotesPalette.secondaryText),
                                              const SizedBox(width: 6),
                                              Expanded(child: InlineEditableTitle(
                                                key: Key('kanban-edit-${task.id}'),
                                                value: task.title,
                                                semanticsLabel:
                                                    'Titolo attività modificabile',
                                                maxLength: 1024,
                                                style: const TextStyle(
                                                  fontSize: 14),
                                                onSave: (title) => ref.read(
                                                    localStoreProvider.notifier)
                                                    .renameTask(task.id, title),
                                                onTap: () => onOpenTask(task),
                                              )),
                                              FButton.icon(
                                                key: Key('kanban-open-${task.id}'),
                                                variant: FButtonVariant.ghost,
                                                onPress: () => onOpenTask(task),
                                                child: const Icon(
                                                  Icons.chevron_right, size: 16),
                                              ),
                                            ]),
                                            Row(children: [
                                              FCheckbox(
                                                value: task.completed,
                                                onChange: (_) => ref.read(
                                                    localStoreProvider.notifier)
                                                    .toggleTask(task.id),
                                              ),
                                              const SizedBox(width: 6),
                                              if (task.priority > 0)
                                                Text('P${task.priority}  ',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: NotesPalette.secondaryText)),
                                              Expanded(child: Text(
                                                task.due.kind == 'none'
                                                  ? 'Senza scadenza'
                                                  : taskDueLabel(task.due),
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: NotesPalette.secondaryText)),
                                              ),
                                              FPopoverMenu(
                                                menu: [
                                                  .group(children: [
                                                    .item(
                                                      title: const Text('Inbox'),
                                                      enabled: task.listId != null,
                                                      onPress: () =>
                                                        _move(ref, data,
                                                          task.id, null)),
                                                    for (final item in data.lists)
                                                      .item(
                                                        title: Text(item.title),
                                                        enabled: task.listId != item.id,
                                                        onPress: () =>
                                                          _move(ref, data,
                                                            task.id, item.id)),
                                                  ]),
                                                ],
                                                menuBuilder: (context,
                                                    controller, menu) => menu!,
                                                builder: (context, controller,
                                                    child) => FButton.icon(
                                                  key: Key('kanban-move-${task.id}'),
                                                  variant: FButtonVariant.ghost,
                                                  onPress: controller.toggle,
                                                  child: const Icon(Icons.more_horiz,
                                                    size: 18),
                                                ),
                                                child: const Text('Sposta in'),
                                              ),
                                            ]),
                                          ],
                                        ),
                                      ));
                                      return touch
                                        ? LongPressDraggable<String>(
                                            data: task.id,
                                            feedback: Material(
                                              color: Colors.transparent,
                                              child: SizedBox(width: columnWidth - 36,
                                                child: FCard(child: Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Text(task.title)))),
                                            ),
                                            childWhenDragging:
                                                Opacity(opacity: 0.3, child: card),
                                            child: card,
                                          )
                                        : Draggable<String>(
                                            data: task.id,
                                            feedback: Material(
                                              color: Colors.transparent,
                                              child: SizedBox(width: columnWidth - 36,
                                                child: FCard(child: Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Text(task.title)))),
                                            ),
                                            childWhenDragging:
                                                Opacity(opacity: 0.3, child: card),
                                            child: card,
                                          );
                                    }),
                                  ),
                              ],
                            ),
                          )),
                          const SizedBox(height: 8),
                          InlineQuickAdd(
                            key: Key('kanban-add-${column.id ?? 'inbox'}'),
                            hint: 'Aggiungi attività',
                            maxLength: 255,
                            onAdd: (title) => ref.read(localStoreProvider.notifier)
                                .addTask(title, listId: column.id),
                          ),
                        ]),
                      )),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        )),
      ]);
    });
  }
}
