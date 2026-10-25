import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import 'notes_theme.dart';

/// P1.6: an explicit recurrence rule on one task, without creating copies.
/// Frequency/interval are written inline via a compact Forui picker.
class TaskRecurrencePanel extends ConsumerWidget {
  const TaskRecurrencePanel({super.key, required this.task});
  final LocalTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('RIPETIZIONE', style: TextStyle(
        color: NotesPalette.secondaryText, fontSize: 11)),
      const SizedBox(height: 8),
      if (!task.due.modern)
        const Text('Imposta prima una scadenza con data per attivare la ripetizione.',
          style: TextStyle(color: NotesPalette.secondaryText, fontSize: 12))
      else
        FPopoverMenu(
          menu: [
            .group(children: [
              for (final entry in [
                ('none', 1, 'Mai'),
                ('daily', 1, 'Ogni giorno'),
                ('weekly', 1, 'Ogni settimana'),
                ('monthly', 1, 'Ogni mese'),
                ('daily', 2, 'Ogni 2 giorni'),
                ('weekly', 2, 'Ogni 2 settimane'),
                ('monthly', 2, 'Ogni 2 mesi'),
                ('monthly', 3, 'Ogni 3 mesi'),
              ])
                .item(
                  title: Text(entry.$3),
                  onPress: () => ref.read(localStoreProvider.notifier)
                    .setTaskRecurrence(task.id,
                      TaskRecurrence(entry.$1, interval: entry.$2)),
                ),
            ]),
          ],
          menuBuilder: (context, controller, menu) => menu!,
          builder: (context, controller, child) => FButton(
            key: const Key('inline-task-recurrence'),
            variant: FButtonVariant.outline,
            mainAxisSize: MainAxisSize.min,
            onPress: controller.toggle,
            prefix: const Icon(Icons.repeat, size: 17),
            child: child!,
          ),
          child: Text(task.recurrence.label),
        ),
      if (task.recurrence.enabled) ...[
        const SizedBox(height: 6),
        const Text('Completando la sessione, la scadenza avanza '
          'alla prossima occorrenza senza creare duplicati.',
          style: TextStyle(color: NotesPalette.secondaryText, fontSize: 11)),
      ],
    ],
  );
}
