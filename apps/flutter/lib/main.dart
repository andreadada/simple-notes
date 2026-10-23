import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/local_store.dart';
import 'data/app_database.dart';
import 'auth/cloud_auth.dart';
import 'sync/cloud_sync.dart';
import 'sync/auto_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(borderSide: BorderSide.none),
            filled: true, fillColor: Color(0xff242424),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
        home: const AutoSyncHost(child: NotesHome()),
      );
}

enum Section { today, next7, inbox, everything, completed, notes }

extension SectionLabel on Section {
  String get label => switch (this) {
        Section.today => 'Oggi',
        Section.next7 => 'Prossimi 7 giorni',
        Section.inbox => 'Inbox',
        Section.everything => 'Tutto',
        Section.completed => 'Completati',
        Section.notes => 'Note',
      };
  IconData get icon => switch (this) {
        Section.today => Icons.today_outlined,
        Section.next7 => Icons.date_range_outlined,
        Section.inbox => Icons.inbox_outlined,
        Section.everything => Icons.list_alt,
        Section.completed => Icons.check_circle_outline,
        Section.notes => Icons.sticky_note_2_outlined,
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
  String searchQuery = '';
  final newTask = TextEditingController();
  DateTime? dueAt;

  @override
  void dispose() {
    newTask.dispose();
    super.dispose();
  }

  Future<void> submitTask() async {
    final text = newTask.text.trim();
    if (text.isEmpty) return;
    await ref.read(localStoreProvider.notifier).addTask(text, dueAt: dueAt);
    newTask.clear();
    setState(() => dueAt = null);
  }

  List<LocalTask> visibleTasks(List<LocalTask> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = today.add(const Duration(days: 7));
    return tasks.where((t) => switch (section) {
          Section.today => !t.completed && t.dueAt != null && t.dueAt!.isBefore(today.add(const Duration(days: 1))),
          Section.next7 => !t.completed && t.dueAt != null && t.dueAt!.isBefore(next),
          Section.completed => t.completed,
          Section.inbox => !t.completed && t.dueAt == null,
          Section.everything => !t.completed,
          Section.notes => false,
        }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> selectDue() async {
    final date = await showDatePicker(
      context: context, initialDate: dueAt ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => dueAt = date);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStoreProvider);
    final cloud = ref.watch(cloudAuthProvider);
    final sync = ref.watch(cloudSyncProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 850;
    final list = visibleTasks(data.tasks)
        .where((task) => task.title.toLowerCase().contains(searchQuery.trim().toLowerCase()))
        .toList();
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
          if (sync.conflict ||
              sync.message?.startsWith('Sync non riuscita') == true)
            const Positioned(
              right: -2, bottom: -2,
              child: Icon(Icons.error, color: Colors.orangeAccent, size: 15),
            ),
        ],
      );
    }

    Widget accountControl({bool compact = false}) => PopupMenuButton<String>(
      key: Key(compact ? 'account-menu-mobile' : 'account-menu'),
      tooltip: cloud.authenticated ? 'Profilo Google' : 'Accedi con Google',
      enabled: !cloud.busy,
      onSelected: (value) async {
        if (value == 'sync') {
          await ref.read(cloudSyncProvider.notifier).synchronize();
        } else if (value == 'logout') {
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
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(cloud.authenticated
            ? (cloud.displayName ?? 'Account Google')
            : 'Non hai effettuato l’accesso',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const PopupMenuDivider(),
        if (cloud.authenticated) ...[
          // Synchronization results were previously invisible on Android.
          // Always expose failures and pending data inside the account menu.
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sync.running ? 'Sincronizzazione in corso...'
                    : sync.conflict ? 'Conflitto: modifica non inviata'
                    : sync.message?.startsWith('Sync non riuscita') == true
                        ? 'Sincronizzazione non riuscita'
                        : sync.message ?? 'Sincronizzazione automatica attiva',
                  style: TextStyle(fontSize: 12,
                    color: sync.conflict ||
                        sync.message?.startsWith('Sync non riuscita') == true
                      ? Colors.orangeAccent : Colors.grey)),
                const SizedBox(height: 4),
                FutureBuilder<int>(
                  future: ref.read(databaseProvider).pendingCount(),
                  builder: (context, snapshot) => Text(
                    'Modifiche in attesa: ${snapshot.data ?? '...'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (cloud.authenticated) ...[
          PopupMenuItem<String>(
            value: 'sync',
            enabled: !sync.running,
            child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.sync),
              title: Text('Sincronizza ora'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout),
              title: Text('Esci da Google'),
            ),
          ),
        ] else
          const PopupMenuItem<String>(
            value: 'login',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.login),
              title: Text('Accedi con Google'),
            ),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16, vertical: 8),
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
                    ? (cloud.displayName ?? 'Account Google')
                    : 'Accedi con Google',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600)),
                  Text(cloud.authenticated
                    ? 'Sincronizzazione automatica'
                    : 'Collega il tuo account',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            ],
          ],
        ),
      ),
    );

    Widget navigation() => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 26, 16, 24),
              child: Row(children: [
                Icon(Icons.check_circle, color: Color(0xff547aff)),
                SizedBox(width: 12),
                Text('Simple Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
            for (final s in Section.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  dense: true, selected: section == s, leading: Icon(s.icon, size: 20),
                  title: Text(s.label),
                  onTap: () {
                    setState(() { section = s; selectedId = null; });
                    if (!desktop) Navigator.maybePop(context);
                  },
                ),
              ),
            const Spacer(),
            if (desktop) accountControl(),
            if (sync.running)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Sincronizzazione...', style: TextStyle(
                    fontSize: 12, color: Colors.grey)),
                ]),
              ),
            if (sync.message != null &&
                (sync.conflict || sync.message!.startsWith('Sync non riuscita')))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(sync.message!, maxLines: 3,
                  style: TextStyle(fontSize: 12,
                    color: sync.conflict ? Colors.orangeAccent : Colors.grey)),
              ),
            if (cloud.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(cloud.error!, maxLines: 3,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Offline-first · Sync automatica',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        );
    return Scaffold(
      appBar: desktop ? null : AppBar(
        title: Text(section.label),
        actions: [Center(child: accountControl(compact: true))],
      ),
      drawer: desktop ? null : Drawer(child: SafeArea(child: navigation())),
      body: Row(children: [
        if (desktop)
          SizedBox(width: 246, child: ColoredBox(
            color: const Color(0xff202020), child: SafeArea(child: navigation()),
          )),
        Expanded(child: Column(children: [
          if (desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 26, 25, 12),
              child: Align(alignment: Alignment.centerLeft,
                child: Text(section.label, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold))),
            ),
          if (section != Section.notes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: TextField(
                key: const Key('task-search'),
                decoration: const InputDecoration(
                  hintText: 'Cerca attività...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ),
          if (section != Section.notes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(child: TextField(
                  key: const Key('task-input'),
                  controller: newTask,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submitTask(),
                  decoration: const InputDecoration(
                    hintText: '+ Aggiungi attività', prefixIcon: Icon(Icons.add, size: 20),
                  ),
                )),
                IconButton(tooltip: 'Imposta data', onPressed: selectDue,
                  icon: Icon(dueAt == null ? Icons.event_outlined : Icons.event_available,
                    color: dueAt == null ? null : const Color(0xff547aff))),
              ]),
            ),
          if (section == Section.notes)
            Expanded(child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: () => ref.read(localStoreProvider.notifier).addNote(),
                  icon: const Icon(Icons.add), label: const Text('Nuova nota'),
                ),
                const SizedBox(height: 12),
                for (final note in data.notes)
                  Card(child: ListTile(
                    title: Text(note.title.isEmpty ? 'Senza titolo' : note.title),
                    subtitle: Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => showNoteEditor(note),
                    trailing: IconButton(tooltip: 'Elimina', icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref.read(localStoreProvider.notifier).deleteNote(note.id)),
                  )),
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
                          leading: Checkbox(
                            value: task.completed,
                            onChanged: (_) => ref.read(localStoreProvider.notifier).toggleTask(task.id),
                          ),
                          title: Text(task.title, style: TextStyle(
                            decoration: task.completed ? TextDecoration.lineThrough : null)),
                          subtitle: task.dueAt == null ? null : Text(
                            'Scadenza: ${task.dueAt!.day}/${task.dueAt!.month}/${task.dueAt!.year}'),
                          onTap: () {
                            setState(() => selectedId = task.id);
                            if (!desktop) showTaskDetails(task);
                          },
                        ),
                      );
                    },
                  )),
        ])),
        if (desktop && selectedId != null && section != Section.notes)
          SizedBox(width: 320, child: ColoredBox(
            color: const Color(0xff202020),
            child: Builder(builder: (_) {
              final task = data.tasks.where((t) => t.id == selectedId).firstOrNull;
              return task == null ? const SizedBox() : taskDetails(task);
            }),
          )),
      ]),
    );
  }

  Widget taskDetails(LocalTask task) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DETTAGLI', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 22),
          Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(task.dueAt == null ? 'Nessuna scadenza' : 'Scadenza: ${task.dueAt!.toLocal()}'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => showTaskEditor(task),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifica'),
          ),
          TextButton.icon(
            onPressed: () {
              ref.read(localStoreProvider.notifier).deleteTask(task.id);
              setState(() => selectedId = null);
              Navigator.maybePop(context);
            },
            icon: const Icon(Icons.delete_outline), label: const Text('Elimina attività'),
          ),
        ]),
      );

  void showTaskDetails(LocalTask task) => showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        builder: (ctx) => SizedBox(height: 300, child: taskDetails(task)),
      );

  void showTaskEditor(LocalTask task) {
    final controller = TextEditingController(text: task.title);
    DateTime? selectedDue = task.dueAt;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Modifica attività'),
          content: SizedBox(width: 420, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('edit-task-title'),
                controller: controller,
                decoration: const InputDecoration(labelText: 'Titolo'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(selectedDue == null
                    ? 'Nessuna scadenza'
                    : 'Scadenza: ${selectedDue!.day}/${selectedDue!.month}/${selectedDue!.year}')),
                IconButton(
                  tooltip: 'Scegli data',
                  icon: const Icon(Icons.event_outlined),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDue ?? DateTime.now(),
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (picked != null && dialogContext.mounted) {
                      updateDialog(() => selectedDue = picked);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Rimuovi data',
                  icon: const Icon(Icons.event_busy),
                  onPressed: () => updateDialog(() => selectedDue = null),
                ),
              ]),
            ],
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(localStoreProvider.notifier).editTask(
                  task.id, title: controller.text, dueAt: selectedDue,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void showNoteEditor(LocalNote note) {
    final title = TextEditingController(text: note.title);
    final body = TextEditingController(text: note.body);
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Modifica nota'),
      content: SizedBox(width: 490, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Titolo')),
        const SizedBox(height: 12),
        TextField(controller: body, minLines: 4, maxLines: 10,
          decoration: const InputDecoration(labelText: 'Testo')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
        FilledButton(onPressed: () async {
          await ref.read(localStoreProvider.notifier).editNote(
            note.id, title: title.text, body: body.text,
          );
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }, child: const Text('Salva')),
      ],
    )).whenComplete(() { title.dispose(); body.dispose(); });
  }
}
