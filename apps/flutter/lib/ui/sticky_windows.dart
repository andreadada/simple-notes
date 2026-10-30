import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../data/local_store.dart';
import 'inline_editable_body.dart';
import 'inline_editable_title.dart';
import 'notes_theme.dart';
import 'theme_mode_preference.dart';

/// A detached note never opens its own SQLite/Drift engine.
/// All reads and writes go through the main window's LocalStore/outbox.
abstract final class StickyConflictGuard {
  static void ensureUnchanged(LocalNote note, String field,
      String expected) {
    if (field != 'title' && field != 'body') {
      throw StateError('Campo sticky non supportato');
    }
    final current = field == 'title' ? note.title : note.body;
    if (current != expected) {
      throw StateError('Nota modificata altrove: ricarica prima.');
    }
  }
}

abstract final class StickyDesktop {
  static bool get supported => Platform.isWindows;

  static Future<bool> launchSubwindowIfNeeded() async {
    if (!supported) return false;
    final controller = await WindowController.fromCurrentEngine();
    final sticky = parseWindowArguments(controller.arguments);
    if (sticky == null) return false;
    runApp(StickyNoteApp(
      parentId: sticky['parentId']!, noteId: sticky['noteId']!));
    return true;
  }

  static Map<String, String>? parseWindowArguments(String arguments) {
    try {
      final obj = jsonDecode(arguments);
      if (obj is! Map || obj['type'] != 'sticky' ||
          obj['parentId'] is! String || obj['noteId'] is! String ||
          (obj['parentId'] as String).isEmpty ||
          (obj['noteId'] as String).isEmpty) {
        return null;
      }
      return {
        'parentId': obj['parentId'] as String,
        'noteId': obj['noteId'] as String,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> open(WidgetRef ref, String noteId) async {
    if (!supported) throw UnsupportedError('Solo su Windows');
    // Handler lives on the SAME Flutter engine as the existing SQLite store.
    final main = await WindowController.fromCurrentEngine();
    await main.setWindowMethodHandler((call) async {
      final payload = call.arguments;
      if (payload is! Map || payload['noteId'] is! String) {
        throw StateError('Argomenti sticky non validi');
      }
      final id = payload['noteId'] as String;
      final note = ref.read(localStoreProvider).notes
          .where((item) => item.id == id).firstOrNull;
      if (note == null) throw StateError('Nota non disponibile');
      switch (call.method) {
        case 'sticky.read':
          return note.toJson();
        case 'sticky.write':
          final field = payload['field'];
          final value = payload['value'];
          final expected = payload['expected'];
          if (value is! String || expected is! String ||
              (field != 'title' && field != 'body')) {
            throw StateError('Aggiornamento non valido');
          }
          // Do not silently overwrite an update made in the main view or sync.
          StickyConflictGuard.ensureUnchanged(note, field as String, expected);
          if (field == 'title') {
            await ref.read(localStoreProvider.notifier).renameNote(id, value);
          } else {
            await ref.read(localStoreProvider.notifier).setNoteBody(id, value);
          }
          return ref.read(localStoreProvider).notes
              .firstWhere((item) => item.id == id).toJson();
        default:
          throw UnsupportedError('Comando sticky sconosciuto');
      }
    });

    final all = await WindowController.getAll();
    for (final window in all) {
      final args = parseWindowArguments(window.arguments);
      if (args?['parentId'] == main.windowId &&
          args?['noteId'] == noteId) {
        await window.show();
        return; // one detached window per note per main engine
      }
    }
    final created = await WindowController.create(WindowConfiguration(
      arguments: jsonEncode({
        'type': 'sticky',
        'parentId': main.windowId,
        'noteId': noteId,
      }),
    ));
    await created.show();
  }
}

class StickyNoteWindow extends StatefulWidget {
  const StickyNoteWindow({super.key, required this.parentId,
      required this.noteId});
  final String parentId;
  final String noteId;

  @override
  State<StickyNoteWindow> createState() => _StickyNoteWindowState();
}

class _StickyNoteWindowState extends State<StickyNoteWindow> {
  LocalNote? _note;
  bool _loading = true;
  String? _error;

  WindowController get _parent => WindowController.fromWindowId(
    widget.parentId);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final result = await _parent.invokeMethod<dynamic>(
        'sticky.read', {'noteId': widget.noteId});
      if (result is! Map) throw StateError('Nota non disponibile');
      final note = LocalNote.fromJson(Map<String, dynamic>.from(result));
      if (!mounted) return;
      setState(() {
        _note = note;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nota non disponibile o finestra principale chiusa.';
      });
    }
  }

  Future<void> _save(String field, String next) async {
    final note = _note;
    if (note == null) throw StateError('Nota non caricata');
    final current = field == 'title' ? note.title : note.body;
    try {
      final result = await _parent.invokeMethod<dynamic>('sticky.write', {
        'noteId': widget.noteId,
        'field': field,
        'value': next,
        'expected': current,
      });
      if (result is! Map) throw StateError('Salvataggio non confermato');
      final updated = LocalNote.fromJson(Map<String, dynamic>.from(result));
      if (!mounted) return;
      setState(() {
        _note = updated;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
          'La nota è cambiata o non è stato possibile salvarla. '
          'Ricaricala prima di modificare ancora.');
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Scaffold(
      backgroundColor: NotesPalette.of(context).surface,
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.sticky_note_2_outlined,
                size: 18, color: NotesPalette.of(context).accent),
              const SizedBox(width: 8),
              Expanded(child: Text('Sticky Note',
                style: TextStyle(fontSize: 12,
                  color: NotesPalette.of(context).secondaryText))),
              FButton(
                key: const Key('sticky-reload'),
                variant: FButtonVariant.ghost,
                mainAxisSize: MainAxisSize.min,
                onPress: _reload,
                child: const Text('Ricarica'),
              ),
            ]),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(
                child: CircularProgressIndicator()))
            else if (note != null) ...[
              InlineEditableTitle(
                key: Key('sticky-title-${note.id}'),
                value: note.title,
                hint: 'Senza titolo',
                semanticsLabel: 'Titolo sticky modificabile',
                style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w600),
                onSave: (text) => _save('title', text),
              ),
              const SizedBox(height: 14),
              Expanded(child: SingleChildScrollView(
                child: InlineEditableBody(
                  key: Key('sticky-body-${note.id}'),
                  value: note.body,
                  hint: 'Scrivi una nota...',
                  semanticsLabel: 'Testo sticky modificabile',
                  maxLines: 18,
                  onSave: (text) => _save('body', text),
                ),
              )),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, key: const Key('sticky-error'),
                  style: TextStyle(
                    color: NotesPalette.of(context).secondaryText, fontSize: 12)),
              ),
          ],
        ),
      )),
    );
  }
}

class StickyNoteApp extends StatefulWidget {
  const StickyNoteApp({super.key, required this.parentId, required this.noteId});

  final String parentId;
  final String noteId;

  @override
  State<StickyNoteApp> createState() => _StickyNoteAppState();
}

class _StickyNoteAppState extends State<StickyNoteApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _readAppearance();
  }

  Future<void> _readAppearance() async {
    try {
      final mode = await ThemeModePreference.load();
      if (mounted) setState(() => _mode = mode);
    } catch (_) {
      // Detached windows can continue in the existing dark theme if
      // SharedPreferences is unavailable in their secondary engine.
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Simple Notes • Sticky',
    debugShowCheckedModeBanner: false,
    themeMode: _mode,
    theme: NotesTheme.material(Brightness.light),
    darkTheme: NotesTheme.material(Brightness.dark),
    builder: (context, child) => FTheme(
      data: NotesTheme.forPlatform(
        TargetPlatform.windows,
        brightness: Theme.of(context).brightness,
      ),
      child: child ?? const SizedBox.shrink(),
    ),
    home: StickyNoteWindow(parentId: widget.parentId, noteId: widget.noteId),
  );
}
