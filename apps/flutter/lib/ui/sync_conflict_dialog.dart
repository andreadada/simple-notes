import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../sync/cloud_sync.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// A conflict is never auto-resolved: the original outbox stays intact until
/// a user makes a conscious choice and the server version is rechecked.
Future<void> showNotesSyncConflictDialog(
    BuildContext context, WidgetRef ref, ConflictDetails conflict) async {
  var confirmDiscard = false;
  var busy = false;
  Widget preview(String caption, String title, String content) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: NotesPalette.of(context).border),
      color: NotesPalette.of(context).surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(caption, style: TextStyle(
        fontSize: 11, color: NotesPalette.of(context).secondaryText,
        fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(title.isEmpty ? 'Senza titolo' : title,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600)),
      if (content.isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(content, maxLines: 4, overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: NotesPalette.of(context).secondaryText, fontSize: 12)),
      ],
    ]),
  );

  await showFDialog<void>(
    context: context,
    builder: (dialogContext, style, animation) => StatefulBuilder(
      builder: (dialogContext, update) {
        final remote = conflict.remotePayload;
        final remoteTitle = conflict.remoteDeleted
            ? 'Eliminato sul server'
            : remote?['title'] as String? ?? 'Senza titolo';
        final remoteBody = remote?['body'] as String?
            ?? remote?['description'] as String? ?? '';
        return NotesDialog(
          style: style, animation: animation, maxWidth: 550,
          title: const Text('Conflitto di sincronizzazione'),
          body: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'La stessa voce è stata modificata su due dispositivi. '
              'Nessun dato viene sovrascritto senza una tua scelta.',
              style: TextStyle(color: NotesPalette.of(context).secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 14),
            preview('QUESTO DISPOSITIVO',
              conflict.localDeleted ? 'Eliminazione locale' : conflict.localTitle,
              conflict.localBody),
            const SizedBox(height: 10),
            preview('SERVER', remoteTitle, remoteBody),
            if (conflict.remoteVersion == null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Impossibile leggere la versione server: '
                    'controlla la connessione e riprova la sincronizzazione.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              ),
            if (confirmDiscard)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Conferma lo scarto delle modifiche locali di '
                  'questa voce. Le altre note e attività non saranno toccate.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              ),
            if (ref.read(cloudSyncProvider).conflict &&
                ref.read(cloudSyncProvider).message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(ref.read(cloudSyncProvider).message!,
                    style: TextStyle(fontSize: 11,
                        color: NotesPalette.of(context).secondaryText)),
              ),
          ]),
          actions: [
            FButton(
              variant: FButtonVariant.ghost, mainAxisSize: MainAxisSize.min,
              onPress: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            if (!conflict.remoteDeleted)
              FButton(
                key: const Key('conflict-keep-local'),
                variant: FButtonVariant.outline, mainAxisSize: MainAxisSize.min,
                onPress: busy || conflict.remoteVersion == null ? null : () async {
                  update(() => busy = true);
                  await ref.read(cloudSyncProvider.notifier)
                      .resolveConflict(keepLocal: true);
                  if (!dialogContext.mounted) return;
                  if (!ref.read(cloudSyncProvider).conflict) {
                    Navigator.pop(dialogContext);
                  } else {
                    update(() => busy = false);
                  }
                },
                child: const Text('Tieni locale'),
              ),
            FButton(
              key: const Key('conflict-use-server'),
              mainAxisSize: MainAxisSize.min,
              onPress: busy || conflict.remoteVersion == null ? null : () async {
                if (!confirmDiscard) {
                  update(() => confirmDiscard = true);
                  return;
                }
                update(() => busy = true);
                await ref.read(cloudSyncProvider.notifier)
                    .resolveConflict(keepLocal: false);
                if (!dialogContext.mounted) return;
                if (!ref.read(cloudSyncProvider).conflict) {
                  Navigator.pop(dialogContext);
                } else {
                  update(() => busy = false);
                }
              },
              child: Text(confirmDiscard ? 'Conferma' : 'Usa server'),
            ),
          ],
        );
      },
    ),
  );
}
