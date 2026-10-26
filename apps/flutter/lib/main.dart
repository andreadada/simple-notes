import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:forui/forui.dart';
import 'ui/notes_theme.dart';
import 'ui/inline_editable_title.dart';
import 'ui/inline_editable_body.dart';
import 'ui/inline_quick_add.dart';
import 'ui/notes_dialogs.dart';
import 'ui/task_due_editor.dart';
import 'ui/calendar_board.dart';
import 'ui/eisenhower_board.dart';
import 'ui/kanban_board.dart';
import 'ui/pomodoro_board.dart';
import 'ui/habits_board.dart';
import 'ui/countdowns_board.dart';
import 'ui/sticky_windows.dart';
import 'ui/task_blocks_panel.dart';
import 'ui/task_recurrence_panel.dart';
import 'ui/reminder_controller.dart';
import 'data/task_due_view.dart';
import 'ui/sync_conflict_dialog.dart';
import 'ui/sync_diagnostics_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'data/local_store.dart';
import 'data/app_database.dart';
import 'auth/cloud_auth.dart';
import 'sync/cloud_sync.dart';
import 'sync/auto_sync.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Detached engines MUST NOT initialize SQLite, OAuth or sync.
  if (Platform.isWindows) {
    final controller = await WindowController.fromCurrentEngine();
    final sticky = StickyDesktop.parseWindowArguments(controller.arguments);
    if (sticky != null) {
      runApp(StickyNoteApp(
        parentId: sticky['parentId']!, noteId: sticky['noteId']!));
      return;
    }
  }
  final preferences = await SharedPreferences.getInstance();
  final database = AppDatabase();
  await database.migrateLegacy(preferences);
  final snapshot = await database.snapshot();
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      initialDataProvider.overrideWithValue(snapshot),
    ],
    child: const SimpleNotesApp(),
  ));
}

class SimpleNotesApp extends StatelessWidget {
  const SimpleNotesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Simple Notes',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff547aff), brightness: Brightness.dark,
            surface: const Color(0xff181818),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xff181818),
          cardColor: const Color(0xff252525),
          // The Material bridge must not put grey backgrounds behind
          // editable text. Forui controls keep their own distinct styling.
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
            border: NotesTheme.inlineBorder,
            enabledBorder: NotesTheme.inlineBorder,
            focusedBorder: NotesTheme.inlineFocusedBorder,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        // Forui is our primary widget system. Material remains only as a
        // compatibility bridge for date pickers, dialogs and the editor.
        builder: (context, child) => FTheme(
          data: NotesTheme.forPlatform(Theme.of(context).platform),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AutoSyncHost(child: NotesHome()),
      );
}

enum Section { today, next7, inbox, everything, completed, calendar, eisenhower, kanban, pomodoro, habits, countdowns, notes, trash }

extension SectionLabel on Section {
  String get label => switch (this) {
        Section.today => 'Oggi',
        Section.next7 => 'Prossimi 7 giorni',
        Section.inbox => 'Inbox',
        Section.everything => 'Tutto',
        Section.completed => 'Completati',
        Section.calendar => 'Calendario',
        Section.eisenhower => 'Matrice Eisenhower',
        Section.kanban => 'Kanban',
        Section.pomodoro => 'Pomodoro',
        Section.habits => 'Abitudini',
        Section.countdowns => 'Countdown',
        Section.notes => 'Note',
        Section.trash => 'Cestino',
      };
  IconData get icon => switch (this) {
        Section.today => Icons.today_outlined,
        Section.next7 => Icons.date_range_outlined,
        Section.inbox => Icons.inbox_outlined,
        Section.everything => Icons.list_alt,
        Section.completed => Icons.check_circle_outline,
        Section.calendar => Icons.calendar_month_outlined,
        Section.eisenhower => Icons.grid_view_outlined,
        Section.kanban => Icons.view_kanban_outlined,
        Section.pomodoro => Icons.timer_outlined,
        Section.habits => Icons.local_fire_department_outlined,
        Section.countdowns => Icons.hourglass_bottom_outlined,
        Section.notes => Icons.sticky_note_2_outlined,
        Section.trash => Icons.restore_from_trash_outlined,
      };
}

class NotesHome extends ConsumerStatefulWidget {
  const NotesHome({super.key});
  @override
  ConsumerState<NotesHome> createState() => _NotesHomeState();
}

class _NotesHomeState extends ConsumerState<NotesHome> {
  Section section = Section.inbox;
  String? selectedId;
  String? activeListId;
  int? priorityFilter;
  String searchQuery = '';
  final newTask = TextEditingController();
  final newTaskFocus = FocusNode();
  TaskDue quickDue = TaskDue.none;

  @override
  void dispose() {
    newTaskFocus.dispose();
    newTask.dispose();
    super.dispose();
  }

  Future<void> submitTask() async {
    final text = newTask.text.trim();
    if (text.isEmpty) return;
    await ref.read(localStoreProvider.notifier)
        .addTask(text, due: quickDue, listId: activeListId);
    newTask.clear();
    setState(() => quickDue = TaskDue.none);
  }

  List<LocalTask> visibleTasks(List<LocalTask> tasks) {
    final now = DateTime.now();
    return tasks.where((t) => (activeListId == null ||
        t.listId == activeListId) && switch (section) {
          Section.today => taskInToday(t, now),
          Section.next7 => taskInNextSevenDays(t, now),
          Section.completed => t.completed,
          Section.inbox => !t.completed && t.listId == null,
          Section.everything => !t.completed,
          Section.calendar || Section.eisenhower || Section.kanban || Section.pomodoro || Section.habits || Section.countdowns || Section.notes || Section.trash => false,
        }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> selectDue() async {
    final selected = await showTaskDueEditor(context, initial: quickDue);
    if (selected != null && mounted) setState(() => quickDue = selected);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStoreProvider);
    final cloud = ref.watch(cloudAuthProvider);
    final sync = ref.watch(cloudSyncProvider);
    final reminders = ref.watch(reminderControllerProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 950;
    final wideDetails = MediaQuery.sizeOf(context).width >= 1200;
    final query = searchQuery.trim().toLowerCase();
    final list = visibleTasks(data.tasks)
        .where((task) => (priorityFilter == null ||
                task.priority == priorityFilter) &&
            (query.isEmpty ||
              task.title.toLowerCase().contains(query) ||
              task.description.toLowerCase().contains(query) ||
              task.tags.any((tag) => tag.toLowerCase().contains(query)) ||
              task.subtasks.any((sub) =>
                  sub.title.toLowerCase().contains(query))))
        .toList()
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        return priority != 0 ? priority : a.createdAt.compareTo(b.createdAt);
      });
    final activeList = data.lists.where((item) => item.id == activeListId)
        .firstOrNull;
    final pageTitle = activeList?.title ?? section.label;
    Widget avatar() {
      final url = cloud.photoUrl;
      final validPhoto = url != null &&
          Uri.tryParse(url)?.scheme == 'https';
      return Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xff303545),
        child: ClipOval(child: validPhoto
            ? Image.network(url, width: 38, height: 38, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, color: Colors.white70))
            : const Icon(Icons.person, color: Colors.white70)),
          ),
          if (sync.conflict || sync.upgradeRequired ||
              sync.message?.startsWith('Sync non riuscita') == true)
            const Positioned(
              right: -2, bottom: -2,
              child: Icon(Icons.error, color: Colors.orangeAccent, size: 15),
            ),
        ],
      );
    }

    Future<void> accountAction(String value) async {
      if (value == 'sync') {
        await ref.read(cloudSyncProvider.notifier).synchronize();
      } else if (value == 'diagnostics') {
        await showNotesSyncDiagnostics(context, ref);
      } else if (value == 'resolve') {
        final details = ref.read(cloudSyncProvider).details;
        if (details != null && context.mounted) {
          await showNotesSyncConflictDialog(context, ref, details);
        }
      } else if (value == 'reminders') {
        await ref.read(reminderControllerProvider.notifier)
            .setEnabled(!ref.read(reminderControllerProvider).enabled);
      } else if (value == 'logout') {
        if (!await ref.read(reminderControllerProvider.notifier)
            .cancelBeforeLogout()) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Prima di uscire, riprova ad annullare i promemoria.'),
            ));
          }
          return;
        }
        await ref.read(cloudAuthProvider.notifier).logout();
      } else if (value == 'login') {
        if (!CloudConfig.enabled) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Configura API_BASE_URL e Google OAuth.'),
            ));
          }
          return;
        }
        await ref.read(cloudAuthProvider.notifier).loginGoogle();
      }
    }

    Widget accountControl({bool compact = false}) => FPopoverMenu(
      key: Key(compact ? 'account-menu-mobile' : 'account-menu'),
      menu: [
        .group(children: [
          .item(
            enabled: false,
            title: Text(cloud.authenticated
              ? cloud.displayName ?? 'Account Google'
              : 'Non hai effettuato l’accesso'),
          ),
          if (cloud.authenticated)
            .item(
              enabled: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sync.running ? 'Sincronizzazione in corso...'
                    : sync.conflict ? 'Conflitto: modifica non inviata'
                    : sync.message ?? 'Sincronizzazione automatica attiva',
                    style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: ref.read(databaseProvider).pendingCount(),
                    builder: (context, snapshot) => Text(
                      'Modifiche in attesa: ${snapshot.data ?? '...'}',
                      style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ]),
        .group(children: [
          if (cloud.authenticated && sync.conflict && sync.details != null)
            .item(
              title: const Text('Risolvi conflitto'),
              prefix: const Icon(Icons.compare_arrows, size: 18),
              onPress: () => accountAction('resolve'),
            ),
          if (cloud.authenticated) ...[
            if (ReminderController.supported) ...[
              .item(
                title: Text(reminders.busy ? 'Aggiornamento promemoria...' :
                  reminders.enabled
                    ? 'Disattiva promemoria (${reminders.pending})'
                    : 'Attiva promemoria ${ReminderController.platformLabel}'),
                prefix: const Icon(Icons.notifications_outlined, size: 18),
                enabled: !reminders.busy,
                onPress: () => accountAction('reminders'),
              ),
              if (reminders.error != null)
                .item(enabled: false, title: Text(reminders.error!,
                  style: const TextStyle(fontSize: 12))),
            ],
            .item(
              title: const Text('Verifica sincronizzazione'),
              prefix: const Icon(Icons.fact_check_outlined, size: 18),
              onPress: () => accountAction('diagnostics'),
            ),
            .item(
              title: const Text('Sincronizza ora'),
              prefix: const Icon(Icons.sync, size: 18),
              enabled: !sync.running,
              onPress: () => accountAction('sync'),
            ),
            .item(
              title: const Text('Esci da Google'),
              prefix: const Icon(Icons.logout, size: 18),
              onPress: () => accountAction('logout'),
            ),
          ] else
            .item(
              title: const Text('Accedi con Google'),
              prefix: const Icon(Icons.login, size: 18),
              onPress: () => accountAction('login'),
            ),
        ]),
      ],
      menuBuilder: (context, controller, menu) => menu!,
      builder: (context, controller, child) => FButton(
        variant: FButtonVariant.ghost,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        onPress: cloud.busy ? null : () { controller.toggle(); },
        child: child!,
      ),
      // Forui buttons measure their children unconstrained. Give the
      // profile row a finite width before placing Expanded inside it.
      child: SizedBox(
          width: compact ? 42 : 190,
          child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 6, vertical: 5),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              avatar(),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cloud.authenticated
                      ? cloud.displayName ?? 'Account Google'
                      : 'Accedi con Google',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600)),
                    Text(cloud.authenticated
                      ? 'Sincronizzazione automatica'
                      : 'Collega il tuo account',
                      style: const TextStyle(fontSize: 11,
                        color: NotesPalette.secondaryText)),
                  ],
                )),
                const Icon(Icons.keyboard_arrow_down,
                  color: NotesPalette.secondaryText, size: 17),
              ],
            ],
          ),
          ),
        ),
    );

    // One responsive Forui navigation component for Windows and Android.
    Widget navigation() => FSidebar(
      header: const Padding(
        padding: EdgeInsets.fromLTRB(18, 24, 18, 16),
        child: Row(children: [
          Icon(Icons.check_circle, color: NotesPalette.accent, size: 22),
          SizedBox(width: 12),
          Expanded(child: Text('Simple Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        ]),
      ),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (desktop) accountControl(),
        if (sync.running)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Sincronizzazione...',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        if (sync.message != null &&
            (sync.conflict || sync.upgradeRequired ||
                sync.message!.startsWith('Sync non riuscita')))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(sync.message!, maxLines: 3,
              style: TextStyle(fontSize: 12,
                color: sync.conflict || sync.upgradeRequired
                    ? Colors.orangeAccent : Colors.grey)),
          ),
        if (cloud.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(cloud.error!, maxLines: 3,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Offline-first · Sync automatica',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      ]),
      children: [
        FSidebarGroup(
          label: const Text('ORGANIZZA'),
          children: [
            for (final s in Section.values.where((s) =>
                s != Section.pomodoro && s != Section.habits &&
                s != Section.countdowns))
              FSidebarItem(
                key: Key('nav-${s.name}'),
                selected: section == s,
                icon: Icon(s.icon, size: 20),
                label: Text(s.label),
                onPress: () {
                  setState(() {
                    section = s;
                    activeListId = null;
                    selectedId = null;
                  });
                  if (!desktop) Navigator.maybePop(context);
                },
              ),
          ],
        ),
        FSidebarGroup(
          label: const Text('LISTE'),
          children: [
            for (final item in data.lists)
              FSidebarItem(
                key: Key('list-${item.id}'),
                selected: activeListId == item.id,
                icon: const Icon(Icons.folder_outlined, size: 20),
                label: Text(item.title, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
                onPress: () {
                  setState(() {
                    section = Section.everything;
                    activeListId = item.id;
                    selectedId = null;
                  });
                  if (!desktop) Navigator.maybePop(context);
                },
              ),
            FSidebarItem(
              key: const Key('create-list'),
              selected: false,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nuova lista'),
              onPress: () {
                if (!desktop) Navigator.maybePop(context);
                showListEditor();
              },
            ),
          ],
        ),
        // Keep the frequent task/list actions in view on short desktops.
        // Pomodoro remains accessible in the scrollable sidebar below lists.
        FSidebarGroup(
          label: const Text('FOCUS'),
          children: [
            FSidebarItem(
              key: const Key('nav-pomodoro'),
              selected: section == Section.pomodoro,
              icon: const Icon(Icons.timer_outlined, size: 20),
              label: const Text('Pomodoro'),
              onPress: () {
                setState(() {
                  section = Section.pomodoro;
                  activeListId = null;
                  selectedId = null;
                });
                if (!desktop) Navigator.maybePop(context);
              },
            ),
            FSidebarItem(
              key: const Key('nav-habits'),
              selected: section == Section.habits,
              icon: const Icon(Icons.local_fire_department_outlined, size: 20),
              label: const Text('Abitudini'),
              onPress: () {
                setState(() {
                  section = Section.habits;
                  activeListId = null;
                  selectedId = null;
                });
                if (!desktop) Navigator.maybePop(context);
              },
            ),
            FSidebarItem(
              key: const Key('nav-countdowns'),
              selected: section == Section.countdowns,
              icon: const Icon(Icons.hourglass_bottom_outlined, size: 20),
              label: const Text('Countdown'),
              onPress: () {
                setState(() {
                  section = Section.countdowns;
                  activeListId = null;
                  selectedId = null;
                });
                if (!desktop) Navigator.maybePop(context);
              },
            ),
          ],
        ),
      ],
    );
    return Scaffold(
      appBar: desktop ? null : AppBar(
        title: activeList == null
          ? Text(pageTitle)
          : InlineEditableTitle(
              key: ValueKey('inline-list-title-${activeList.id}'),
              value: activeList.title,
              semanticsLabel: 'Titolo lista modificabile',
              style: const TextStyle(fontSize: 20,
                fontWeight: FontWeight.w600),
              onSave: (title) => ref.read(localStoreProvider.notifier)
                  .renameList(activeList.id, title),
            ),
        actions: [Center(child: accountControl(compact: true))],
      ),
      drawer: desktop ? null : Drawer(child: SafeArea(child: navigation())),
      body: Row(children: [
        if (desktop)
          SizedBox(width: 246, child: ColoredBox(
            color: NotesPalette.sidebar, child: SafeArea(child: navigation()),
          )),
        Expanded(child: Column(children: [
          if (desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 26, 25, 12),
              child: Align(alignment: Alignment.centerLeft,
                child: activeList == null
                  ? Text(pageTitle, style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.bold))
                  : InlineEditableTitle(
                      key: ValueKey('inline-list-title-${activeList.id}'),
                      value: activeList.title,
                      semanticsLabel: 'Titolo lista modificabile',
                      style: const TextStyle(fontSize: 23,
                        fontWeight: FontWeight.bold),
                      onSave: (title) => ref.read(localStoreProvider.notifier)
                          .renameList(activeList.id, title),
                    )),
            ),
          if (section != Section.calendar && section != Section.eisenhower && section != Section.kanban && section != Section.pomodoro && section != Section.habits && section != Section.countdowns && section != Section.notes && section != Section.trash)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: FTextField(
                key: const Key('task-search'),
                control: FTextFieldControl.managed(
                  onChange: (value) =>
                    setState(() => searchQuery = value.text),
                ),
                hint: 'Cerca attività...',
                prefixBuilder: (context, style, variants) =>
                  const Icon(Icons.search, size: 18),

              ),
            ),
          if (section != Section.calendar && section != Section.eisenhower && section != Section.kanban && section != Section.pomodoro && section != Section.habits && section != Section.countdowns && section != Section.notes && section != Section.trash)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Row(children: [
                FButton(
                  key: const Key('priority-filter'),
                  variant: FButtonVariant.outline,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => setState(() =>
                    priorityFilter = priorityFilter == null ? 3 :
                      priorityFilter == 1 ? null : priorityFilter! - 1),
                  prefix: const Icon(Icons.flag_outlined, size: 16),
                  child: Text(priorityFilter == null
                    ? 'Tutte le priorità' : 'Priorità P${priorityFilter!}'),
                ),
                if (activeListId != null) ...[
                  const SizedBox(width: 8),
                  FButton(
                    key: const Key('delete-list'),
                    variant: FButtonVariant.ghost,
                    mainAxisSize: MainAxisSize.min,
                    onPress: activeList == null
                      ? null : () => confirmListDeletion(activeList),
                    child: const Icon(Icons.delete_outline, size: 17),
                  ),
                ],
              ]),
            ),
          if (section != Section.calendar && section != Section.eisenhower && section != Section.kanban && section != Section.pomodoro && section != Section.habits && section != Section.countdowns && section != Section.notes && section != Section.trash)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(child: LayoutBuilder(
                  builder: (context, bounds) =>
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: newTask,
                      builder: (context, draft, _) {
                        const style = TextStyle(fontSize: 14);
                        final glyphWidth = InlineTextMetrics.fieldWidth(
                          context,
                          text: draft.text.isEmpty
                              ? 'Aggiungi attività' : draft.text,
                          style: style,
                          maxWidth: bounds.maxWidth - 32,
                        );
                        final fieldWidth = InlineTextMetrics.inputWidth(
                          glyphWidth: glyphWidth,
                          maxWidth: bounds.maxWidth - 32);
                        return Row(children: [
                          const Icon(Icons.add, size: 20,
                            color: NotesPalette.secondaryText),
                          const SizedBox(width: 8),
                          SizedBox(width: fieldWidth, child: InlineGlyphUnderline(
                            glyphWidth: glyphWidth,
                            focusNode: newTaskFocus,
                            child: TextField(
                            key: const Key('task-input'),
                            controller: newTask,
                            focusNode: newTaskFocus,
                            style: style,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submitTask(),
                            decoration: const InputDecoration(
                              hintText: 'Aggiungi attività',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: NotesPalette.placeholder),
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.symmetric(vertical: 9),
                              border: NotesTheme.invisibleInlineBorder,
                              enabledBorder: NotesTheme.invisibleInlineBorder,
                              focusedBorder: NotesTheme.invisibleInlineBorder,
                            ),
                          ))),
                          const Spacer(),
                        ]);
                      },
                    ),
                )),
                IconButton(
                  key: const Key('quick-due-editor'),
                  tooltip: quickDue.kind == 'none'
                      ? 'Imposta data' : taskDueLabel(quickDue),
                  onPressed: selectDue,
                  icon: Icon(quickDue.kind == 'none'
                      ? Icons.event_outlined : Icons.event_available,
                    color: quickDue.kind == 'none'
                      ? null : NotesPalette.accent)),
              ]),
            ),
          if (section == Section.calendar)
            const Expanded(child: CalendarBoard())
          else if (section == Section.eisenhower)
            Expanded(child: EisenhowerBoard(onOpenTask: (task) {
              setState(() => selectedId = task.id);
              if (!wideDetails) showTaskDetails(task);
            }))
          else if (section == Section.kanban)
            Expanded(child: KanbanBoard(
              onCreateList: showListEditor,
              onOpenTask: (task) {
                setState(() => selectedId = task.id);
                if (!wideDetails) showTaskDetails(task);
              },
            ))
          else if (section == Section.pomodoro)
            Expanded(child: PomodoroBoard(
              key: ValueKey('pomodoro-${cloud.userId ?? 'guest'}'),
              ownerId: cloud.userId,
            ))
          else if (section == Section.habits)
            Expanded(child: HabitsBoard(
              key: ValueKey('habits-${cloud.userId ?? 'guest'}'),
              ownerId: cloud.userId,
            ))
          else if (section == Section.countdowns)
            Expanded(child: CountdownsBoard(
              key: ValueKey('countdowns-${cloud.userId ?? 'guest'}'),
              ownerId: cloud.userId,
            ))
          else if (section == Section.trash)
            Expanded(child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Note eliminate · ripristinabili sullo stesso account',
                    style: TextStyle(color: NotesPalette.secondaryText)),
                ),
                if (data.trashedNotes.isEmpty)
                  const Center(child: Text('Cestino vuoto',
                    style: TextStyle(color: NotesPalette.secondaryText))),
                for (final note in data.trashedNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(note.title.isEmpty
                              ? 'Senza titolo' : note.title,
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                          FButton(
                            key: Key('restore-note-${note.id}'),
                            variant: FButtonVariant.outline,
                            mainAxisSize: MainAxisSize.min,
                            onPress: () async {
                              await ref.read(localStoreProvider.notifier)
                                  .restoreNote(note.id);
                            },
                            child: const Text('Ripristina'),
                          ),
                        ]),
                        if (note.body.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(note.body),
                          ),
                      ],
                    )),
                  ),
              ],
            ))
          else if (section == Section.notes)
            Expanded(child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(alignment: Alignment.centerLeft, child: FButton(
                  key: const Key('new-note'),
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => ref.read(localStoreProvider.notifier).addNote(),
                  prefix: const Icon(Icons.add, size: 18),
                  child: const Text('Nuova nota'),
                )),
                const SizedBox(height: 12),
                for (final note in data.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: InlineEditableTitle(
                            key: Key('inline-note-title-${note.id}'),
                            value: note.title,
                            hint: 'Senza titolo',
                            semanticsLabel: 'Titolo nota modificabile',
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                            onSave: (text) => ref.read(localStoreProvider.notifier)
                                .renameNote(note.id, text),
                          )),
                          if (StickyDesktop.supported)
                            FButton.icon(
                              key: Key('detach-note-${note.id}'),
                              variant: FButtonVariant.ghost,
                              onPress: () async {
                                try {
                                  await StickyDesktop.open(ref, note.id);
                                } catch (_) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                    const SnackBar(content: Text(
                                      'Impossibile aprire la finestra Sticky Note.')));
                                }
                              },
                              child: const Icon(Icons.open_in_new, size: 18),
                            ),
                          FButton.icon(
                            key: Key('delete-note-${note.id}'),
                            variant: FButtonVariant.ghost,
                            onPress: () => confirmNoteDeletion(note),
                            child: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        InlineEditableBody(
                          key: Key('inline-note-body-${note.id}'),
                          value: note.body,
                          semanticsLabel: 'Contenuto nota modificabile',
                          hint: 'Scrivi una nota...',
                          onSave: (text) => ref.read(localStoreProvider.notifier)
                              .setNoteBody(note.id, text),
                        ),
                      ],
                    )),
                  ),
              ],
            ))
          else
            Expanded(child: list.isEmpty
                ? const Center(child: Text('Nessuna attività in questa sezione',
                    style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final task = list[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                        child: ListTile(
                          selected: selectedId == task.id,
                          leading: FCheckbox(
                             value: task.completed,
                             onChange: (_) => ref.read(localStoreProvider.notifier)
                                 .toggleTask(task.id),
                           ),
                           title: InlineEditableTitle(
                             key: Key('inline-task-row-${task.id}'),
                             value: task.title,
                             semanticsLabel: 'Titolo attività modificabile',
                             maxLength: 1024,
                             style: TextStyle(fontSize: 14,
                               decoration: task.completed ? TextDecoration.lineThrough : null),
                             onSave: (text) => ref.read(localStoreProvider.notifier)
                                 .renameTask(task.id, text),
                             onTap: () => setState(() => selectedId = task.id),
                           ),
                           trailing: wideDetails ? null : FButton.icon(
                             key: Key('open-task-details-${task.id}'),
                             variant: FButtonVariant.ghost,
                             onPress: () {
                               setState(() => selectedId = task.id);
                               showTaskDetails(task);
                             },
                             child: const Icon(Icons.chevron_right, size: 18),
                           ),
                           subtitle: task.due.kind == 'none'
                              ? null : Text('Scadenza: ${taskDueLabel(task.due)}'),
                          onTap: () {
                            setState(() => selectedId = task.id);
                            if (!wideDetails) showTaskDetails(task);
                          },
                        ),
                      );
                    },
                  )),
        ])),
        if (wideDetails && selectedId != null && section != Section.notes)
          SizedBox(width: 350, child: ColoredBox(
            color: NotesPalette.sidebar,
            child: Builder(builder: (_) {
              final task = data.tasks.where((t) => t.id == selectedId).firstOrNull;
              return task == null ? const SizedBox() : taskDetails(task);
            }),
          )),
      ]),
    );
  }

  Widget taskDetails(LocalTask task) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DETTAGLI', style: TextStyle(
        color: NotesPalette.secondaryText, fontSize: 11,
        fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      Expanded(child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InlineEditableTitle(
            key: Key('inline-task-title-${task.id}'),
            value: task.title,
            maxLength: 1024,
            semanticsLabel: 'Titolo attività modificabile',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            onSave: (text) => ref.read(localStoreProvider.notifier)
                .renameTask(task.id, text),
          ),
          const SizedBox(height: 20),
          const Text('SCADENZA', style: TextStyle(
            color: NotesPalette.secondaryText, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FButton(
              key: const Key('inline-task-due'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: () async {
                final chosen = await showTaskDueEditor(context,
                    initial: task.due);
                if (chosen != null) {
                  await ref.read(localStoreProvider.notifier)
                      .setTaskDueSemantics(task.id, chosen);
                }
              },
              prefix: const Icon(Icons.calendar_today_outlined, size: 16),
              child: Text(taskDueLabel(task.due)),
            ),
            if (task.due.kind != 'none')
              FButton.icon(
                key: const Key('inline-clear-due'),
                variant: FButtonVariant.ghost,
                onPress: () => ref.read(localStoreProvider.notifier)
                    .setTaskDueSemantics(task.id, TaskDue.none),
                child: const Icon(Icons.close, size: 17),
              ),
          ]),
          const SizedBox(height: 18),
          TaskRecurrencePanel(task: task),
          const SizedBox(height: 18),
          TaskBlocksPanel(task: task),
          const SizedBox(height: 18),
          const Text('PRIORITÀ', style: TextStyle(
            color: NotesPalette.secondaryText, fontSize: 11)),
          const SizedBox(height: 8),
          FPopoverMenu(
            menu: [
              .group(children: [
                for (var priority = 0; priority <= 3; priority++)
                  .item(
                    title: Text(priority == 0 ? 'Normale' : 'P$priority'),
                    onPress: () => ref.read(localStoreProvider.notifier)
                        .setTaskPriority(task.id, priority),
                  ),
              ]),
            ],
            menuBuilder: (context, controller, menu) => menu!,
            builder: (context, controller, child) => FButton(
              key: const Key('inline-task-priority'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: () { controller.toggle(); },
              prefix: const Icon(Icons.flag_outlined, size: 16),
              child: child!,
            ),
            child: Text(task.priority == 0 ? 'Normale' : 'P${task.priority}'),
          ),
          const SizedBox(height: 18),
          const Text('LISTA', style: TextStyle(
            color: NotesPalette.secondaryText, fontSize: 11)),
          const SizedBox(height: 8),
          FPopoverMenu(
            menu: [
              .group(children: [
                .item(
                  title: const Text('Inbox'),
                  onPress: () => ref.read(localStoreProvider.notifier)
                      .setTaskList(task.id, null),
                ),
                for (final list in ref.read(localStoreProvider).lists)
                  .item(
                    title: Text(list.title),
                    onPress: () => ref.read(localStoreProvider.notifier)
                        .setTaskList(task.id, list.id),
                  ),
              ]),
            ],
            menuBuilder: (context, controller, menu) => menu!,
            builder: (context, controller, child) => FButton(
              key: const Key('inline-task-list'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: () { controller.toggle(); },
              prefix: const Icon(Icons.folder_outlined, size: 16),
              child: child!,
            ),
            child: Text(ref.read(localStoreProvider).lists
                .where((list) => list.id == task.listId)
                .firstOrNull?.title ?? 'Inbox'),
          ),
          const SizedBox(height: 18),
          const Text('TAG', style: TextStyle(
            color: NotesPalette.secondaryText, fontSize: 11)),
          const SizedBox(height: 6),
          InlineEditableTitle(
            key: Key('inline-task-tags-${task.id}'),
            value: task.tags.join(', '),
            hint: 'Aggiungi tag...',
            allowEmpty: true,
            maxLength: 700,
            semanticsLabel: 'Modifica tag separati da virgola',
            style: const TextStyle(fontSize: 13),
            onSave: (text) => ref.read(localStoreProvider.notifier)
                .setTaskTags(task.id, text),
          ),
          const SizedBox(height: 18),
          const Text('DESCRIZIONE', style: TextStyle(
            color: NotesPalette.secondaryText, fontSize: 11)),
          const SizedBox(height: 6),
          InlineEditableBody(
            key: Key('inline-task-description-${task.id}'),
            value: task.description,
            semanticsLabel: 'Descrizione attività modificabile',
            hint: 'Aggiungi una descrizione...',
            onSave: (text) => ref.read(localStoreProvider.notifier)
                .setTaskDescription(task.id, text),
          ),
          const SizedBox(height: 18),
          Text('SOTTOTASK · '
            '${task.subtasks.where((item) => item.completed).length}/'
            '${task.subtasks.length}',
            style: const TextStyle(color: NotesPalette.secondaryText,
              fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in task.subtasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                FCheckbox(
                  key: Key('subtask-${item.id}'),
                  value: item.completed,
                  onChange: (_) => ref.read(localStoreProvider.notifier)
                      .toggleSubtask(task.id, item.id),
                ),
                const SizedBox(width: 8),
                Expanded(child: InlineEditableTitle(
                  key: Key('inline-subtask-${item.id}'),
                  value: item.title,
                  maxLength: 255,
                  semanticsLabel: 'Titolo sottotask modificabile',
                  style: TextStyle(fontSize: 13,
                    decoration: item.completed ? TextDecoration.lineThrough : null),
                  onSave: (text) => ref.read(localStoreProvider.notifier)
                      .renameSubtask(task.id, item.id, text),
                )),
                FButton.icon(
                  key: Key('remove-subtask-${item.id}'),
                  variant: FButtonVariant.ghost,
                  onPress: () => confirmSubtaskDeletion(task, item),
                  child: const Icon(Icons.close, size: 16),
                ),
              ]),
            ),
          InlineQuickAdd(
            key: Key('inline-add-subtask-${task.id}'),
            hint: 'Aggiungi sottotask...',
            onAdd: (text) => ref.read(localStoreProvider.notifier)
                .addSubtask(task.id, text),
          ),
        ]),
      )),
      const SizedBox(height: 10),
      Row(children: [
        FButton(
          key: const Key('advanced-task-editor'),
          variant: FButtonVariant.ghost,
          mainAxisSize: MainAxisSize.min,
          onPress: () => showTaskEditor(task),
          child: const Text('Altre opzioni'),
        ),
        const Spacer(),
        FButton.icon(
          key: const Key('delete-task'),
          variant: FButtonVariant.ghost,
          onPress: () => confirmTaskDeletion(task),
          child: const Icon(Icons.delete_outline, size: 18),
        ),
      ]),
    ]),
  );

  void showTaskDetails(LocalTask task) => showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: 0.85,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.75,
      child: Consumer(builder: (context, watcher, _) {
        final current = watcher.watch(localStoreProvider).tasks
            .where((item) => item.id == task.id).firstOrNull;
        return current == null ? const SizedBox.shrink()
          : taskDetails(current);
      }),
    ),
  );

  void showListEditor() {
    final title = TextEditingController();
    showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => NotesEditorControllerScope(
        controllers: [title],
        child: NotesDialog(
          style: style, animation: animation,
          title: const Text('Nuova lista'),
          body: FTextField(
            key: const Key('list-title'),
            control: FTextFieldControl.managed(controller: title),
            autofocus: true,
            label: const Text('Nome della lista'),
            hint: 'Es. Università, Lavoro...',
          ),
          actions: [
            FButton(
              variant: FButtonVariant.ghost, mainAxisSize: MainAxisSize.min,
              onPress: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FButton(
              key: const Key('save-list'),
              mainAxisSize: MainAxisSize.min,
              onPress: () async {
                final value = title.text.trim();
                if (value.isEmpty || value.length > 255) return;
                await ref.read(localStoreProvider.notifier).addList(value);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void confirmListDeletion(LocalTaskList list) {
    showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Eliminare la lista?'),
        body: Text('La lista "${list.title}" verrà eliminata. '
          'Le sue attività non saranno cancellate: verranno spostate in '
          'Tutto/Inbox. La modifica verrà sincronizzata.'),
        actions: [
          FButton(
            variant: FButtonVariant.ghost, mainAxisSize: MainAxisSize.min,
            onPress: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FButton(
            key: const Key('confirm-delete-list'),
            mainAxisSize: MainAxisSize.min,
            onPress: () async {
              await ref.read(localStoreProvider.notifier).deleteList(list.id);
              if (!mounted) return;
              setState(() { activeListId = null; selectedId = null; });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Elimina lista'),
          ),
        ],
      ),
    );
  }

  void confirmSubtaskDeletion(LocalTask task, LocalSubtask subtask) {
    showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Eliminare sottotask?'),
        body: Text('Vuoi eliminare "${subtask.title}"?'),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FButton(
            key: const Key('confirm-delete-subtask'),
            onPress: () async {
              await ref.read(localStoreProvider.notifier)
                  .removeSubtask(task.id, subtask.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void confirmTaskDeletion(LocalTask task) {
    showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Eliminare attività?'),
        body: Text('Eliminare "${task.title}"? La modifica sarà sincronizzata.'),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FButton(
            key: const Key('confirm-delete-task'),
            onPress: () async {
              await ref.read(localStoreProvider.notifier).deleteTask(task.id);
              if (mounted) setState(() => selectedId = null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void confirmNoteDeletion(LocalNote note) {
    showFDialog<void>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Eliminare nota?'),
        body: Text('Spostare "${note.title.isEmpty ? 'Senza titolo' : note.title}" nel cestino? Potrai ripristinarla.'),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FButton(
            key: const Key('confirm-delete-note'),
            onPress: () async {
              await ref.read(localStoreProvider.notifier).deleteNote(note.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sposta nel cestino'),
          ),
        ],
      ),
    );
  }

  void showTaskEditor(LocalTask task) {
    final title = TextEditingController(text: task.title);
    final description = TextEditingController(text: task.description);
    final tags = TextEditingController(text: task.tags.join(', '));
    final subtaskInput = TextEditingController();
    var selectedList = task.listId;
    var selectedPriority = task.priority;
    var editedSubtasks = [...task.subtasks];
    TaskDue selectedDue = task.due;
    showFDialog<void>(
      context: context,
      builder: (dialogContext, style, animation) => NotesEditorControllerScope(
        controllers: [title, description, tags, subtaskInput],
        child: StatefulBuilder(
          builder: (dialogContext, updateDialog) => NotesDialog(
          style: style,
          animation: animation,
          maxWidth: 560,
          title: const Text('Modifica attività'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FTextField(
                key: const Key('edit-task-title'),
                control: FTextFieldControl.managed(controller: title),
                label: const Text('Titolo'),
                hint: 'Cosa devi fare?',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              FTextField.multiline(
                key: const Key('edit-task-description'),
                control: FTextFieldControl.managed(controller: description),
                label: const Text('Descrizione'),
                hint: 'Dettagli, link o appunti...',
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              const Text('LISTA', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: NotesPalette.secondaryText)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final item in <LocalTaskList?>[
                    null, ...ref.read(localStoreProvider).lists])
                  FButton(
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => updateDialog(() => selectedList = item?.id),
                    prefix: selectedList == item?.id
                      ? const Icon(Icons.check, size: 14) : null,
                    child: Text(item?.title ?? 'Nessuna lista',
                        overflow: TextOverflow.ellipsis),
                  ),
              ]),
              const SizedBox(height: 18),
              const Text('PRIORITÀ', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: NotesPalette.secondaryText)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (var value = 0; value <= 3; value++)
                  FButton(
                    key: Key('edit-priority-$value'),
                    variant: FButtonVariant.outline,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => updateDialog(() => selectedPriority = value),
                    prefix: selectedPriority == value
                      ? const Icon(Icons.check, size: 14) : null,
                    child: Text(value == 0 ? 'Normale' : 'P$value'),
                  ),
              ]),
              const SizedBox(height: 16),
              FTextField(
                key: const Key('edit-task-tags'),
                control: FTextFieldControl.managed(controller: tags),
                label: const Text('Tag'),
                hint: 'università, lavoro, urgente',
              ),
              const SizedBox(height: 18),
              Text('SOTTOTASK (${editedSubtasks.where((s) => s.completed).length}/'
                  '${editedSubtasks.length})',
                style: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: NotesPalette.secondaryText)),
              for (final sub in editedSubtasks)
                Row(children: [
                  Checkbox(
                    key: Key('edit-subtask-${sub.id}'),
                    value: sub.completed,
                    onChanged: (checked) => updateDialog(() {
                      editedSubtasks = [
                        for (final item in editedSubtasks)
                          item.id == sub.id
                            ? item.copyWith(completed: checked ?? false)
                            : item,
                      ];
                    }),
                  ),
                  Expanded(child: InlineEditableTitle(
                    key: Key('advanced-inline-subtask-${sub.id}'),
                    value: sub.title,
                    semanticsLabel: 'Titolo sottotask modificabile',
                    maxLength: 255,
                    style: const TextStyle(fontSize: 13),
                    onSave: (text) async {
                      updateDialog(() {
                        editedSubtasks = [
                          for (final item in editedSubtasks)
                            item.id == sub.id ? item.copyWith(title: text.trim()) : item,
                        ];
                      });
                    },
                  )),
                  FButton.icon(
                    variant: FButtonVariant.ghost,
                    onPress: () => updateDialog(() {
                      editedSubtasks.removeWhere((item) => item.id == sub.id);
                    }),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FTextField(
                  key: const Key('new-subtask-input'),
                  control: FTextFieldControl.managed(controller: subtaskInput),
                  hint: 'Aggiungi sottotask...',
                )),
                const SizedBox(width: 8),
                FButton(
                  key: const Key('add-subtask'),
                  mainAxisSize: MainAxisSize.min,
                  onPress: () {
                    final text = subtaskInput.text.trim();
                    if (text.isEmpty || text.length > 255 ||
                        editedSubtasks.length >= 50) {
                      return;
                    }
                    updateDialog(() {
                      editedSubtasks = [
                        ...editedSubtasks,
                        LocalSubtask(id: const Uuid().v4(), title: text),
                      ];
                    });
                    subtaskInput.clear();
                  },
                  child: const Icon(Icons.add, size: 19),
                ),
              ]),
              const SizedBox(height: 20),
              const Text('SCADENZA', style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: NotesPalette.secondaryText,
                letterSpacing: 0.6,
              )),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FButton(
                  key: const Key('edit-task-due'),
                  variant: FButtonVariant.outline,
                  onPress: () async {
                    final chosen = await showTaskDueEditor(dialogContext,
                        initial: selectedDue);
                    if (chosen != null && dialogContext.mounted) {
                      updateDialog(() => selectedDue = chosen);
                    }
                  },
                  prefix: const Icon(Icons.calendar_today_outlined, size: 17),
                  child: Text(taskDueLabel(selectedDue)),
                )),
                if (selectedDue.kind != 'none') ...[
                  const SizedBox(width: 8),
                  FButton.icon(
                    key: const Key('clear-task-due'),
                    variant: FButtonVariant.outline,
                    onPress: () => updateDialog(
                        () => selectedDue = TaskDue.none),
                    child: const Icon(Icons.close, size: 17),
                  ),
                ],
              ]),
            ],
          ),
          actions: [
            FButton(
              variant: FButtonVariant.ghost,
              mainAxisSize: MainAxisSize.min,
              onPress: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FButton(
              key: const Key('save-task'),
              mainAxisSize: MainAxisSize.min,
              onPress: () async {
                if (title.text.trim().isEmpty) return;
                final parsedTags = tags.text.split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty).toSet().toList();
                if (parsedTags.length > 16 ||
                    parsedTags.any((tag) => tag.length > 40)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Massimo 16 tag, 40 caratteri ciascuno.')));
                  return;
                }
                await ref.read(localStoreProvider.notifier).editTask(
                  task.id,
                  title: title.text,
                  description: description.text,
                  due: selectedDue,
                  changeDue: true, // Preserve typed due even on title-only edits.
                  listId: selectedList,
                  changeListId: true,
                  priority: selectedPriority,
                  tags: parsedTags,
                  subtasks: editedSubtasks,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Salva'),
            ),
          ],
          ),
        ),
      ),
    );
  }

}
