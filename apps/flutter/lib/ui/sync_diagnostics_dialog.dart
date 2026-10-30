import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../sync/cloud_sync.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Non-destructive T4 acceptance surface.
/// Opens a single authenticated capabilities GET and reads local SQLite only.
Future<void> showNotesSyncDiagnostics(BuildContext context, WidgetRef ref) {
  final check = ref.read(cloudSyncProvider.notifier).inspectSync();
  return showFDialog<void>(
    context: context,
    builder: (dialogContext, style, animation) => NotesDialog(
      key: const Key('sync-diagnostics-dialog'),
      style: style,
      animation: animation,
      maxWidth: 500,
      title: const Text('Verifica sincronizzazione'),
      body: FutureBuilder<SyncDiagnostics>(
        future: check,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Impossibile leggere lo stato locale. '
                'Nessun dato è stato modificato.',
              style: TextStyle(color: Colors.orangeAccent));
          }
          final info = snapshot.data;
          if (info == null) {
            return const Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Controllo dello stato in corso...'),
            ]);
          }
          final last = info.lastSuccessUtc?.toLocal();
          final lastLabel = last == null
              ? 'Mai completata su questo dispositivo'
              : last.toString().split('.').first;
          final statusColor = info.backendStatus == 'compatible'
              ? NotesPalette.of(context).accent : Colors.orangeAccent;
          Widget detail(String label, String value, {Color? color}) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label,
                      style: TextStyle(fontSize: 12,
                          color: NotesPalette.of(context).secondaryText))),
                    const SizedBox(width: 8),
                    Flexible(child: Text(value,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 12, color: color))),
                  ],
                ),
              );
          final safeReport = [
            'Simple Notes · Diagnostica sincronizzazione',
            'API: ${info.backendLabel}',
            'Google: ${info.authenticated ? "connesso" : "non connesso"}',
            'Archivio/account: ${info.accountMatchesLocal ? "coerente" : "non coerente"}',
            'Modifiche in attesa: ${info.pending}',
            'Task locali: ${info.localTasks}',
            'Note locali: ${info.localNotes}',
            'Note nel cestino: ${info.trashedNotes}',
            'Liste locali: ${info.localLists}',
            'Cursor sync: ${info.cursor}',
            'Ultima sync riuscita (locale): $lastLabel',
          ].join('\n');
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Backend scadenze e blocchi', info.backendLabel,
                  color: statusColor),
              detail('Account Google',
                  info.authenticated ? 'Connesso' : 'Non connesso'),
              detail('Archivio/account',
                  info.accountMatchesLocal ? 'Coerente' : 'Verificare'),
              const Divider(height: 20),
              detail('Modifiche in attesa', '${info.pending}'),
              detail('Attività sul dispositivo', '${info.localTasks}'),
              detail('Note sul dispositivo', '${info.localNotes}'),
              detail('Note nel cestino', '${info.trashedNotes}'),
              detail('Liste sul dispositivo', '${info.localLists}'),
              detail('Cursor di sincronizzazione', '${info.cursor}'),
              detail('Ultima sincronizzazione', lastLabel),
              const SizedBox(height: 12),
              Text(
                'Controllo in sola lettura. Non invia attività o note, '
                'non svuota la coda e non garantisce che l’altro '
                'dispositivo sia già sincronizzato.',
                style: TextStyle(fontSize: 12,
                    color: NotesPalette.of(context).secondaryText),
              ),
              const SizedBox(height: 12),
              FButton(
                key: const Key('sync-diagnostics-copy'),
                variant: FButtonVariant.outline,
                onPress: () => Clipboard.setData(
                    ClipboardData(text: safeReport)),
                prefix: const Icon(Icons.copy_outlined, size: 16),
                child: const Text('Copia report'),
              ),
            ],
          );
        },
      ),
      actions: [
        FButton(
          key: const Key('sync-diagnostics-close'),
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(dialogContext),
          child: const Text('Chiudi'),
        ),
      ],
    ),
  );
}
