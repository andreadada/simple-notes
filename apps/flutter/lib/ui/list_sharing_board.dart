import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../data/list_sharing_api.dart';
import '../data/models.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Explicit, online-only collaboration UI. Received tasks are deliberately
/// never inserted in Drift, personal /sync cursors or the local task editor.
class ListSharingBoard extends StatefulWidget {
  const ListSharingBoard({
    super.key,
    required this.ownerId,
    required this.ownedLists,
    required this.baseUrl,
    required this.tokenProvider,
    required this.ownerMatches,
    this.api,
  });

  final String? ownerId;
  final List<LocalTaskList> ownedLists;
  final String baseUrl;
  final Future<String> Function() tokenProvider;
  final ListSharingApi? api;
  final Future<bool> Function(String) ownerMatches;

  @override
  State<ListSharingBoard> createState() => _ListSharingBoardState();
}

class _ListSharingBoardState extends State<ListSharingBoard> {
  final TextEditingController _code = TextEditingController();
  late final ListSharingApi _api;
  late final bool _ownsApi;
  List<SharedTaskList> _received = const [];
  SharedSnapshot? _snapshot;
  ListShareInvitation? _issued;
  String? _issuedList;
  String? _managedList;
  List<ListShareMember> _members = const [];
  List<PendingListInvitation> _pending = const [];
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? ListSharingApi(
      baseUrl: widget.baseUrl, tokenProvider: widget.tokenProvider);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ListSharingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId == widget.ownerId) return;
    _code.clear();
    _received = const [];
    _snapshot = null;
    _issued = null;
    _issuedList = null;
    _managedList = null;
    _members = const [];
    _pending = const [];
    _error = null;
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    if (_ownsApi) _api.close();
    super.dispose();
  }

  Future<bool> _accountValid() async {
    final owner = widget.ownerId;
    return mounted && owner != null &&
        await widget.ownerMatches(owner) && mounted &&
        widget.ownerId == owner;
  }

  String _explain(Object error) {
    if (error is ListSharingHttpException) {
      switch (error.status) {
        case 404:
          return 'Condivisione non disponibile sul server, lista non '
              'sincronizzata o permesso revocato.';
        case 409:
          return 'Invito scaduto, già utilizzato oppure limite raggiunto.';
        case 400:
          return 'Codice invito non valido.';
        case 401:
        case 403:
          return 'Sessione scaduta: accedi nuovamente a Google.';
        default:
          return 'Operazione cloud non riuscita (HTTP ${error.status}).';
      }
    }
    if (error is FormatException) return error.message;
    return 'Rete o account non disponibili. Nessun dato locale modificato.';
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy || _loading || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (!await _accountValid()) throw StateError('Account non coerente');
      await task();
    } catch (error) {
      if (mounted) setState(() => _error = _explain(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    if (widget.ownerId == null) {
      setState(() {
        _loading = false;
        _received = const [];
        _snapshot = null;
        _issued = null;
        _managedList = null;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (!await _accountValid()) return;
      final lists = await _api.sharedLists();
      if (!await _accountValid()) return;
      setState(() => _received = lists);
    } catch (error) {
      if (mounted) setState(() => _error = _explain(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() => _run(() async {
    final token = _code.text.trim();
    if (token.isEmpty) {
      throw const FormatException('Incolla il codice ricevuto.');
    }
    await _api.accept(token);
    if (!await _accountValid()) return;
    _code.clear();
    _issued = null;
    _issuedList = null;
    setState(() => _snapshot = null);
    final lists = await _api.sharedLists();
    if (!await _accountValid()) return;
    setState(() => _received = lists);
    _message('Lista collegata in sola lettura.');
  });

  Future<void> _invite(LocalTaskList list) => _run(() async {
    final ticket = await _api.invite(list.id);
    if (!await _accountValid()) return;
    setState(() {
      _issued = ticket;
      _issuedList = list.id;
    });
    _message('Invito monouso creato: condividi il codice solo con il destinatario.');
  });

  Future<void> _copyInvite() => _run(() async {
    final invite = _issued;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite.token));
    if (!await _accountValid()) return;
    _message('Codice copiato. Scade dopo 7 giorni e può essere usato una sola volta.');
  });

  Future<void> _open(SharedTaskList list) => _run(() async {
    final snapshot = await _api.snapshot(list.id);
    if (!await _accountValid()) return;
    setState(() => _snapshot = snapshot);
  });

  Future<void> _more() => _run(() async {
    final previous = _snapshot;
    if (previous == null || previous.nextOffset == null) return;
    final page = await _api.snapshot(previous.listId,
        offset: previous.nextOffset!);
    if (!await _accountValid() || _snapshot != previous) return;
    setState(() => _snapshot = SharedSnapshot(
      listId: previous.listId, title: page.title,
      tasks: [...previous.tasks, ...page.tasks],
      nextOffset: page.nextOffset,
    ));
  });

  Future<void> _manage(LocalTaskList list) => _run(() async {
    final members = await _api.members(list.id);
    final pending = await _api.pending(list.id);
    if (!await _accountValid()) return;
    setState(() {
      _managedList = list.id;
      _members = members;
      _pending = pending;
    });
  });

  Future<bool> _confirm(String title, String text) async {
    if (!mounted) return false;
    return await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style,
        animation: animation,
        title: Text(title),
        body: Text(text),
        actions: [
          FButton(variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
          FButton(onPress: () => Navigator.pop(ctx, true),
            child: const Text('Conferma')),
        ],
      ),
    ) == true;
  }

  Future<void> _leave(SharedTaskList list) async {
    if (!await _confirm('Abbandona lista',
        'Non vedrai più le attività di "${list.title}". '
        'Le attività del proprietario non saranno modificate.')) {
      return;
    }
    await _run(() async {
      await _api.leave(list.id);
      if (!await _accountValid()) return;
      final lists = await _api.sharedLists();
      if (!await _accountValid()) return;
      setState(() {
        _received = lists;
        if (_snapshot?.listId == list.id) _snapshot = null;
      });
    });
  }

  Future<void> _removeMember(String listId, ListShareMember member) async {
    if (!await _confirm('Revoca accesso',
        'Rimuovere il collaboratore dalla lista?')) {
      return;
    }
    await _run(() async {
      await _api.revokeMember(listId, member.id);
      if (!await _accountValid()) return;
      final refreshed = await _api.members(listId);
      if (!await _accountValid()) return;
      setState(() => _members = refreshed);
    });
  }

  Future<void> _revokeInvite(String listId, PendingListInvitation invite) async {
    await _run(() async {
      await _api.revokeInvitation(listId, invite.id);
      if (!await _accountValid()) return;
      final refreshed = await _api.pending(listId);
      if (!await _accountValid()) return;
      setState(() => _pending = refreshed);
    });
  }

  Widget _title(String value, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value,style: const TextStyle(fontSize: 16,
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(description, style: TextStyle(fontSize: 12,
          color: NotesPalette.of(context).secondaryText)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final secondary = NotesPalette.of(context).secondaryText;
    if (widget.ownerId == null) {
      return const Center(child: Text(
        'Accedi con Google per condividere o consultare liste.'));
    }
    return ListView(
      key: const Key('list-sharing-board'),
      padding: const EdgeInsets.all(18),
      children: [
        _title('Liste condivise',
          'La condivisione funziona online. Le attività ricevute sono '
          'di sola lettura e non modificano i dati locali.'),
        const SizedBox(height: 14),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) ...[
          Text(_error!, key: const Key('list-share-error'),
            style: TextStyle(color: secondary)),
          const SizedBox(height: 10),
        ],
        FCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Accetta un invito',
                'Incolla il codice monouso fornito dal proprietario.'),
            const SizedBox(height: 12),
            FTextField(
              key: const Key('share-token-input'),
              control: FTextFieldControl.managed(controller: _code),
              label: const Text('Codice invito'),
              hint: 'Codice privato di 43 caratteri',
            ),
            const SizedBox(height: 10),
            FButton(key: const Key('share-accept'),
              onPress: _busy || _loading ? null : _accept,
              prefix: const Icon(Icons.link, size: 17),
              child: const Text('Collega lista')),
          ],
        )),
        const SizedBox(height: 16),
        _title('Le mie liste', 'Crea un invito temporaneo per una lista '
            'che hai già sincronizzato. Massimo 5 inviti attivi per lista.'),
        const SizedBox(height: 10),
        if (widget.ownedLists.isEmpty)
          Text('Non hai ancora liste personali.',
            style: TextStyle(color: secondary)),
        for (final list in widget.ownedLists)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: FCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(list.title, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8,runSpacing: 8,children: [
                  FButton(
                    key: Key('share-issue-${list.id}'),
                    variant: FButtonVariant.outline,
                    onPress: _busy || _loading ? null : () => _invite(list),
                    child: const Text('Crea invito')),
                  FButton(
                    key: Key('share-manage-${list.id}'),
                    variant: FButtonVariant.ghost,
                    onPress: _busy || _loading ? null : () => _manage(list),
                    child: const Text('Gestisci accessi')),
                ]),
                if (_issued != null && _issuedList == list.id) ...[
                  const SizedBox(height: 12),
                  Text('Codice monouso — mostrato solo adesso',
                    style: TextStyle(color: secondary,fontSize: 12)),
                  const SizedBox(height: 4),
                  SelectableText(_issued!.token,
                    key: const Key('share-issued-token'),
                    style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  FButton(
                    key: const Key('share-copy-token'),
                    variant: FButtonVariant.outline,
                    onPress: _busy ? null : _copyInvite,
                    prefix: const Icon(Icons.copy_outlined,size: 16),
                    child: const Text('Copia codice')),
                ],
                if (_managedList == list.id) ...[
                  const SizedBox(height: 12),
                  Text('Collaboratori ${_members.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  for (final member in _members)
                    Row(children: [
                      Expanded(child: Text(member.displayName ?? 'Collaboratore',
                        overflow: TextOverflow.ellipsis)),
                      FButton(
                        key: Key('share-remove-member-${member.id}'),
                        variant: FButtonVariant.ghost,
                        onPress: _busy ? null : () =>
                            _removeMember(list.id, member),
                        child: const Text('Rimuovi')),
                    ]),
                  const SizedBox(height: 6),
                  Text('Inviti disponibili ${_pending.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  for (final pending in _pending)
                    Row(children: [
                      Expanded(child: Text('Scade il '
                          '${pending.expiresAt.toLocal().day}/'
                          '${pending.expiresAt.toLocal().month}/'
                          '${pending.expiresAt.toLocal().year}',
                        style: TextStyle(color: secondary))),
                      FButton(
                        key: Key('share-revoke-invite-${pending.id}'),
                        variant: FButtonVariant.ghost,
                        onPress: _busy ? null : () =>
                            _revokeInvite(list.id,pending),
                        child: const Text('Revoca')),
                    ]),
                ],
              ],
            )),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _title('Liste ricevute',
              'Apri per consultare i task condivisi, senza modificarli.')),
          FButton(
            key: const Key('share-refresh'),
            variant: FButtonVariant.ghost,
            onPress: _busy || _loading ? null : _refresh,
            prefix: const Icon(Icons.refresh,size: 16),
            child: const Text('Aggiorna')),
        ]),
        const SizedBox(height: 10),
        if (!_loading && _received.isEmpty)
          Text('Nessuna lista ricevuta.', style: TextStyle(color: secondary)),
        for (final list in _received)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: FCard(child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list.title, maxLines:1,overflow:TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight:FontWeight.w600)),
                  Text('Sola lettura',
                    style: TextStyle(color: secondary,fontSize:12)),
                ],
              )),
              const SizedBox(width: 8),
              FButton(
                key: Key('share-open-${list.id}'),
                variant: FButtonVariant.outline,
                onPress: _busy ? null : () => _open(list),
                child: const Text('Apri')),
              const SizedBox(width: 6),
              FButton(
                key: Key('share-leave-${list.id}'),
                variant: FButtonVariant.ghost,
                onPress: _busy ? null : () => _leave(list),
                child: const Text('Esci')),
            ]))),
        if (_snapshot != null) ...[
          const SizedBox(height: 16),
          _title('Anteprima · ${_snapshot!.title}',
              'Contenuto aggiornato dal server. Nessuna modifica consentita.'),
          const SizedBox(height: 8),
          for (final task in _snapshot!.tasks)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: FCard(child: Row(children: [
                Icon(task.completed ? Icons.check_circle_outline :
                    Icons.radio_button_unchecked, size: 19,
                  color: task.completed ? Colors.green : secondary),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title),
                    if (task.description?.isNotEmpty == true)
                      Text(task.description!,style:TextStyle(
                        color:secondary,fontSize:12)),
                  ],
                )),
              ]))),
          if (_snapshot!.nextOffset != null)
            Align(alignment: Alignment.centerLeft,
              child: FButton(
                key: const Key('share-load-more'),
                variant: FButtonVariant.outline,
                onPress: _busy ? null : _more,
                child: const Text('Carica altre attività'))),
        ],
        const SizedBox(height: 16),
        Text('La condivisione non invia notifiche e non sincronizza '
            'le liste ricevute nel database locale.',
          style: TextStyle(color: secondary,fontSize: 11)),
      ],
    );
  }
}
