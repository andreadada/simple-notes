import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import 'notes_theme.dart';
import 'time_block_editor.dart';
import 'time_block_view.dart';

/// One task can contain multiple independently editable blocks.
/// The title remains directly editable in the parent task editor.
class TaskBlocksPanel extends ConsumerWidget {
  const TaskBlocksPanel({super.key, required this.task});
  final LocalTask task;

  Future<void> _edit(
      BuildContext context, WidgetRef ref, TimeSlot? slot) async {
    final result = await showTimeBlockEditor(context, initial: slot?.block);
    if (result == null || !context.mounted) return;
    final store = ref.read(localStoreProvider.notifier);
    if (slot == null) {
      if (result.block != null) {
        await store.addTaskTimeSlot(task.id, result.block!);
      }
    } else if (result.block == null) {
      await store.removeTaskTimeSlot(task.id, slot.id);
    } else {
      await store.updateTaskTimeSlot(task.id, slot.id, result.block!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('BLOCCHI ORARI',
          style: TextStyle(color: NotesPalette.of(context).secondaryText, fontSize: 11))),
        Text('${task.timeBlocks.length}/12',
          style: TextStyle(fontSize: 11,
              color: NotesPalette.of(context).secondaryText)),
      ]),
      const SizedBox(height: 8),
      for (final slot in task.timeBlocks)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: FCard(child: Row(children: [
            Icon(Icons.timelapse_outlined, size: 17,
                color: NotesPalette.of(context).accent),
            const SizedBox(width: 8),
            Expanded(child: Text(timeBlockLabel(slot.block),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            FButton.icon(
              key: Key('slot-edit-${slot.id}'),
              variant: FButtonVariant.ghost,
              onPress: () => _edit(context, ref, slot),
              child: const Icon(Icons.edit_outlined, size: 18),
            ),
            FButton.icon(
              key: Key('slot-duplicate-${slot.id}'),
              variant: FButtonVariant.ghost,
              onPress: () => ref.read(localStoreProvider.notifier)
                  .duplicateTaskTimeSlot(task.id, slot.id),
              child: const Icon(Icons.content_copy_outlined, size: 18),
            ),
          ])),
        ),
      FButton(
        key: const Key('inline-task-time-block'),
        variant: FButtonVariant.outline,
        mainAxisSize: MainAxisSize.min,
        onPress: task.timeBlocks.length >= 12
            ? null : () => _edit(context, ref, null),
        prefix: const Icon(Icons.add_circle_outline, size: 17),
        child: const Text('Aggiungi blocco'),
      ),
    ],
  );
}
