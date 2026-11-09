import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forui/forui.dart';

import '../data/models.dart';
import '../data/task_insights.dart';
import '../data/task_templates.dart';
import '../data/user_task_templates.dart';
import 'notes_dialogs.dart';
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

class TaskTemplatesBoard extends StatefulWidget {
  const TaskTemplatesBoard({
    super.key,
    required this.onCreate,
    required this.ownerId,
    this.busy = false,
  });

  final Future<void> Function(TaskTemplate) onCreate;
  final String? ownerId;
  final bool busy;

  @override
  State<TaskTemplatesBoard> createState() => _TaskTemplatesBoardState();
}

class _TaskTemplatesBoardState extends State<TaskTemplatesBoard> {
  UserTaskTemplateLibrary _library = UserTaskTemplateLibrary();
  SharedPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TaskTemplatesBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      setState(() {
        _library = UserTaskTemplateLibrary();
        _prefs = null;
        _loading = true;
        _loadError = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final owner = widget.ownerId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = await const UserTaskTemplateStore().load(prefs, owner);
      if (!mounted || widget.ownerId != owner) return;
      setState(() {
        _library = loaded;
        _prefs = prefs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || widget.ownerId != owner) return;
      setState(() {
        _loading = false;
        _loadError = 'Impossibile leggere i modelli locali. '
            'Nessun archivio è stato sovrascritto.';
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)));
  }

  Future<void> _persist(UserTaskTemplateLibrary next) async {
    if (_saving || _prefs == null || _loadError != null) return;
    final owner = widget.ownerId;
    setState(() => _saving = true);
    try {
      await const UserTaskTemplateStore().save(_prefs!, owner, next);
      if (!mounted || widget.ownerId != owner) return;
      setState(() => _library = next);
    } catch (_) {
      _showError('Modello non salvato. I dati precedenti sono invariati.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([TaskTemplate? old]) async {
    if (_saving || _loading || _loadError != null) return;
    final owner = widget.ownerId;
    final title = TextEditingController(text: old?.title ?? '');
    final description = TextEditingController(text: old?.description ?? '');
    final subtasks = TextEditingController(text: old?.subtasks.join('\n') ?? '');
    final tags = TextEditingController(text: old?.tags.join(', ') ?? '');
    try {
      final result = await showFDialog<TaskTemplate>(
        context: context,
        builder: (ctx, style, animation) => NotesDialog(
          style: style, animation: animation,
          title: Text(old == null ? 'Nuovo modello' : 'Modifica modello'),
          body: SizedBox(
            width: 440,
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('custom-template-title'),
                  controller: title, maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Titolo'),
                ),
                TextField(
                  key: const Key('custom-template-description'),
                  controller: description,
                  maxLines: 2, maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                TextField(
                  key: const Key('custom-template-subtasks'),
                  controller: subtasks,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Sottotask (uno per riga)',
                  ),
                ),
                TextField(
                  key: const Key('custom-template-tags'),
                  controller: tags,
                  decoration: const InputDecoration(
                    labelText: 'Tag separati da virgola',
                  ),
                ),
              ],
            )),
          ),
          actions: [
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FButton(
              key: const Key('custom-template-save'),
              onPress: () => Navigator.pop(ctx, TaskTemplate(
                id: old?.id ??
                    UserTaskTemplateLibrary.newTemplate(
                      title: title.text, description: description.text,
                      subtasks: const [],
                    ).id,
                title: title.text.trim(),
                description: description.text.trim(),
                priority: old?.priority ?? 0,
                tags: tags.text.split(',').map((x) => x.trim())
                    .where((x) => x.isNotEmpty).toSet().toList(),
                subtasks: subtasks.text.split('\n').map((x) => x.trim())
                    .where((x) => x.isNotEmpty).toSet().toList(),
              )),
              child: const Text('Salva modello'),
            ),
          ],
        ),
      );
      if (!mounted || owner != widget.ownerId || result == null) return;
      try {
        final next = _library.upsert(result);
        await _persist(next);
      } on FormatException catch (error) {
        _showError(error.message);
      }
    } finally {
      title.dispose();
      description.dispose();
      subtasks.dispose();
      tags.dispose();
    }
  }

  Future<void> _remove(TaskTemplate template) async {
    if (_saving || _loading || _loadError != null) return;
    final owner = widget.ownerId;
    final approved = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Elimina modello'),
        body: const Text('Il modello locale sarà eliminato. '
            'Le attività già create non verranno modificate.'),
        actions: [
          FButton(variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
          FButton(onPress: () => Navigator.pop(ctx, true),
            child: const Text('Elimina modello')),
        ],
      ),
    );
    if (!mounted || widget.ownerId != owner || approved != true) return;
    await _persist(_library.remove(template.id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = NotesPalette.of(context);
    final all = <TaskTemplate>[
      ...TaskTemplateCatalog.templates,
      ..._library.templates,
    ];
    return ListView(
      key: const Key('task-templates-board'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Modelli pronti da usare', style: TextStyle(
          fontSize: 18, color: colors.foreground,
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 6),
        Text('Ogni modello crea una nuova attività sincronizzabile. '
            'I modelli personali restano su questo dispositivo e sono '
            'inclusi nel backup cifrato del profilo.',
          style: TextStyle(fontSize: 12, color: colors.secondaryText)),
        const SizedBox(height: 14),
        Row(children: [
          FButton(
            key: const Key('add-custom-template'),
            mainAxisSize: MainAxisSize.min,
            onPress: _loading || _saving || _loadError != null
                ? null : () => _edit(),
            child: const Text('Nuovo modello'),
          ),
          if (_loading) ...[
            const SizedBox(width: 10),
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ]),
        if (_loadError != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_loadError!,
              key: const Key('custom-template-load-error'),
              style: const TextStyle(color: Colors.orangeAccent))),
        const SizedBox(height: 14),
        for (final template in all)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(template.title, style:
                    const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w600))),
                  if (template.id.startsWith('custom-')) ...[
                    IconButton(
                      key: Key('edit-template-${template.id}'),
                      tooltip: 'Modifica modello',
                      onPressed: _saving ? null : () => _edit(template),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      key: Key('delete-template-${template.id}'),
                      tooltip: 'Elimina modello',
                      onPressed: _saving ? null : () => _remove(template),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ]),
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
                  onPress: widget.busy || _saving || _loading
                      ? null : () => widget.onCreate(template),
                  child: const Text('Crea attività'),
                ),
              ],
            )),
          ),
      ],
    );
  }
}
