import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/note_attachment_api.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Explicit online attachments for one synced note. Never writes SQLite,
/// note bodies, sync outbox or the encrypted .snb preference backup.
class NoteAttachmentsPanel extends StatefulWidget {
  const NoteAttachmentsPanel({
    super.key,
    required this.ownerId,
    required this.noteId,
    required this.api,
    required this.ownerMatches,
  });

  final String ownerId;
  final String noteId;
  final NoteAttachmentApi api;
  final Future<bool> Function(String) ownerMatches;

  @override
  State<NoteAttachmentsPanel> createState() => _NoteAttachmentsPanelState();
}

class _NoteAttachmentsPanelState extends State<NoteAttachmentsPanel> {
  List<NoteAttachment> _files = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<bool> _owned() async {
    if (!mounted) return false;
    final allowed = await widget.ownerMatches(widget.ownerId);
    return allowed && mounted;
  }

  String _errorMessage(Object error) {
    if (error is NoteAttachmentException) {
      switch (error.status) {
        case 404:
          return 'Nota non ancora disponibile sul server oppure non accessibile. '
            'Sincronizza prima la nota e riprova.';
        case 503:
          return 'Allegati cloud non ancora configurati sul server.';
        case 409:
          return 'File in conflitto, limite raggiunto o caricamento scaduto.';
        case 413:
          return 'File troppo grande.';
        default:
          return 'Operazione allegati non riuscita (HTTP ${error.status}).';
      }
    }
    if (error is FormatException) return error.message;
    return 'Rete o sessione non disponibili. Nessun dato locale modificato.';
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await _owned()) throw StateError('Account non valido');
      final files = await widget.api.list(widget.noteId);
      if (!await _owned()) return;
      setState(() => _files = files);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)));
  }

  String? _typeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.txt')) return 'text/plain';
    return null;
  }

  Future<void> _upload() async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      if (!await _owned()) throw StateError('Account cambiato');
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
          label: 'PDF, immagini, testo',
          extensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
        ),
      ]);
      if (file == null || !await _owned()) return;
      final type = _typeFor(file.name);
      if (type == null) {
        throw const FormatException('Seleziona PDF, PNG, JPEG o TXT.');
      }
      final length = await file.length();
      if (length < 1 || length > NoteAttachmentApi.maxBytes) {
        throw const FormatException('File vuoto o superiore a 10 MiB.');
      }
      final bytes = Uint8List.fromList(await file.readAsBytes());
      if (bytes.length != length || !await _owned()) return;
      final ticket = await widget.api.begin(
          widget.noteId, file.name, type, length);
      if (!await _owned()) return;
      await widget.api.upload(ticket, bytes);
      if (!await _owned()) return;
      await widget.api.complete(widget.noteId, ticket.id);
      if (!await _owned()) return;
      _message('Allegato caricato sul cloud.');
      await _refresh();
    } catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(NoteAttachment file) async {
    if (_busy || !await _owned()) return;
    setState(() => _busy = true);
    try {
      final uri = await widget.api.download(widget.noteId, file.id);
      if (!await _owned()) return;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Impossibile aprire il link');
      }
    } catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(NoteAttachment file) async {
    if (_busy || !await _owned()) return;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style,
        animation: animation,
        title: const Text('Elimina allegato'),
        body: Text('Eliminare "${file.name}" dal cloud? '
            'Non sarà possibile recuperare il file dalla nota.'),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
          FButton(
            key: const Key('confirm-delete-attachment'),
            onPress: () => Navigator.pop(ctx, true),
            child: const Text('Elimina')),
        ],
      ),
    );
    if (confirmed != true || !await _owned()) return;
    setState(() => _busy = true);
    try {
      await widget.api.delete(widget.noteId, file.id);
      if (!await _owned()) return;
      _message('Allegato eliminato dal cloud.');
      await _refresh();
    } catch (error) {
      _message(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NotesPalette.of(context);
    return SizedBox(
      width: 490,
      height: 350,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allegati online · massimo 10 MiB ciascuno',
            style: TextStyle(color: palette.secondaryText, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            FButton(
              key: const Key('add-note-attachment'),
              onPress: _busy || _loading ? null : _upload,
              prefix: const Icon(Icons.attach_file, size: 16),
              child: const Text('Aggiungi file')),
            const SizedBox(width: 8),
            FButton(
              key: const Key('refresh-note-attachments'),
              variant: FButtonVariant.outline,
              onPress: _busy || _loading ? null : _refresh,
              child: const Text('Aggiorna')),
          ]),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                key: const Key('note-attachment-error'),
                style: TextStyle(color: palette.secondaryText)),
            ),
          Expanded(child: _files.isEmpty
              ? Center(child: Text(
                  _loading ? 'Caricamento...' : 'Nessun allegato disponibile.',
                  style: TextStyle(color: palette.secondaryText)))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (ctx, index) {
                    final file = _files[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 19),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name, overflow: TextOverflow.ellipsis),
                            Text('${(file.sizeBytes / 1024).ceil()} KiB',
                              style: TextStyle(
                                  color: palette.secondaryText, fontSize: 11)),
                          ],
                        )),
                        IconButton(
                          key: Key('open-note-attachment-${file.id}'),
                          tooltip: 'Apri allegato',
                          onPressed: _busy ? null : () => _open(file),
                          icon: const Icon(Icons.open_in_new, size: 18)),
                        IconButton(
                          key: Key('delete-note-attachment-${file.id}'),
                          tooltip: 'Elimina allegato',
                          onPressed: _busy ? null : () => _delete(file),
                          icon: const Icon(Icons.delete_outline, size: 18)),
                      ]),
                    );
                  },
                )),
          const SizedBox(height: 6),
          Text('I file sono nel bucket privato, non nel backup .snb. '
              'Per caricarli la nota deve essere già sincronizzata.',
            style: TextStyle(color: palette.secondaryText, fontSize: 11)),
        ],
      ),
    );
  }
}
