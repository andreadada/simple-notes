import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../data/models.dart';
import '../data/task_insights.dart';
import '../data/task_templates.dart';
import 'notes_theme.dart';

/// Existing-data-only analytics. No telemetry, no historical claims, no API.
class TaskAnalyticsBoard extends StatelessWidget {
  const TaskAnalyticsBoard({super.key, required this.tasks, required this.lists});

  final List<LocalTask> tasks;
  final List<LocalTaskList> lists;

  @override
  Widget build(BuildContext context) {
    final colors = NotesPalette.of(context);
    final snapshot = TaskAnalyticsSnapshot.fromTasks(tasks);
    Widget indicator(String label, String value, IconData icon) => FCard(
      child: SizedBox(width: 145, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.accent),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(
            fontSize: 27, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 12, color: colors.secondaryText,
          )),
        ],
      )),
    );

    return ListView(
      key: const Key('task-analytics-board'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Panoramica locale', style: TextStyle(
          color: colors.foreground, fontWeight: FontWeight.w600,
          fontSize: 18,
        )),
        const SizedBox(height: 5),
        Text('Statistiche dello stato attuale, non della cronologia. '
            'Nessun dato viene inviato all’esterno.',
          style: TextStyle(fontSize: 12, color: colors.secondaryText)),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          indicator('Attività totali', '${snapshot.total}',
              Icons.list_alt_outlined),
          indicator('Completate', '${snapshot.completed}',
              Icons.check_circle_outline),
          indicator('In ritardo', '${snapshot.overdue}',
              Icons.warning_amber_outlined),
          indicator('Prossimi 7 giorni', '${snapshot.upcoming}',
              Icons.event_outlined),
          indicator('Priorità alta P2–P3', '${snapshot.highPriority}',
              Icons.flag_outlined),
          indicator('Tempo pianificato', '${snapshot.plannedMinutes ~/ 60}h '
              '${snapshot.plannedMinutes % 60}m',
              Icons.timer_outlined),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Text('Completamento', style: TextStyle(
            color: colors.foreground, fontWeight: FontWeight.w600,
          )),
          const Spacer(),
          Text('${(snapshot.completionRatio * 100).round()}%',
            style: TextStyle(color: colors.secondaryText)),
        ]),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          value: snapshot.completionRatio,
          backgroundColor: colors.muted,
          valueColor: AlwaysStoppedAnimation(colors.accent),
        ),
        const SizedBox(height: 24),
        Text('Per lista', style: TextStyle(
          color: colors.foreground, fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 8),
        if (snapshot.byList.isEmpty)
          Text('Nessuna attività', style: TextStyle(
            color: colors.secondaryText,
          )),
        for (final entry in snapshot.byList.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(entry.key == null
                ? 'Inbox'
                : lists.where((value) => value.id == entry.key)
                    .firstOrNull?.title ?? 'Lista non disponibile',
                overflow: TextOverflow.ellipsis)),
              Text('${entry.value}', style: TextStyle(
                color: colors.secondaryText,
              )),
            ]),
          ),
      ],
    );
  }
}

class TaskTemplatesBoard extends StatelessWidget {
  const TaskTemplatesBoard({
    super.key,
    required this.onCreate,
    this.busy = false,
  });

  final Future<void> Function(TaskTemplate) onCreate;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = NotesPalette.of(context);
    return ListView(
      key: const Key('task-templates-board'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Modelli pronti da usare', style: TextStyle(
          fontSize: 18, color: colors.foreground,
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 6),
        Text('Un modello crea una nuova attività con sottotask. '
            'È modificabile subito e si sincronizza come tutte le altre.',
          style: TextStyle(fontSize: 12, color: colors.secondaryText)),
        const SizedBox(height: 14),
        for (final template in TaskTemplateCatalog.templates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(template.description, style: TextStyle(
                  fontSize: 12, color: colors.secondaryText,
                )),
                const SizedBox(height: 9),
                for (final text in template.subtasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.check_box_outline_blank, size: 15,
                        color: colors.secondaryText),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text, style: const TextStyle(
                        fontSize: 12,
                      ))),
                    ]),
                  ),
                const SizedBox(height: 10),
                FButton(
                  key: Key('create-template-${template.id}'),
                  mainAxisSize: MainAxisSize.min,
                  onPress: busy ? null : () => onCreate(template),
                  child: const Text('Crea attività'),
                ),
              ],
            )),
          ),
      ],
    );
  }
}
