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
  final TextEditingController _draftTitle = TextEditingController();
  final TextEditingController _draftDescription = TextEditingController();
  String? _editingTaskId;
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
  int _ownerEpoch = 0;
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
    // Invalidate all pending HTTP responses from the previous Google account.
    _ownerEpoch++;
    _busy = false;
    _loading = false;
    _code.clear();
    _received = const [];
    _snapshot = null;
    _editingTaskId = null;
    _draftTitle.clear();
    _draftDescription.clear();
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
    _draftTitle.dispose();
    _draftDescription.dispose();
    if (_ownsApi) _api.close();
    super.dispose();
  }

  Future<bool> _accountValid(String? owner, int epoch) async {
    if (!mounted || owner == null ||
        epoch != _ownerEpoch || widget.ownerId != owner) {
      return false;
    }
    final approved = await widget.ownerMatches(owner);
    return approved && mounted && epoch == _ownerEpoch &&
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

  Future<void> _run(
      Future<void> Function(String owner, int epoch) task) async {
    if (_busy || _loading || !mounted) return;
    // Capture the authenticated identity once. Checking widget.ownerId
    // after a network await alone would allow a delayed previous-account
    // response to be mistaken for the new session.
    final owner = widget.ownerId;
    final epoch = _ownerEpoch;
    if (!await _accountValid(owner, epoch)) return;
    setState(() { _busy = true; _error = null; });
    try {
      await task(owner!, epoch);
    } catch (error) {
      if (mounted && epoch == _ownerEpoch && widget.ownerId == owner) {
        setState(() => _error = _explain(error));
      }
    } finally {
      if (mounted && epoch == _ownerEpoch && widget.ownerId == owner) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final owner = widget.ownerId;
    final epoch = _ownerEpoch;
    if (owner == null) {
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
      if (!await _accountValid(owner, epoch)) return;
      final lists = await _api.sharedLists();
      if (!await _accountValid(owner, epoch)) return;
      setState(() => _received = lists);
    } catch (error) {
      if (mounted && epoch == _ownerEpoch && widget.ownerId == owner) {
        setState(() => _error = _explain(error));
      }
    } finally {
      if (mounted && epoch == _ownerEpoch && widget.ownerId == owner) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept() => _run((owner, epoch) async {
    final token = _code.text.trim();
    if (token.isEmpty) {
      throw const FormatException('Incolla il codice ricevuto.');
    }
    await _api.accept(token);
    if (!await _accountValid(owner, epoch)) return;
    _code.clear();
    _issued = null;
    _issuedList = null;
    setState(() => _snapshot = null);
    final lists = await _api.sharedLists();
    if (!await _accountValid(owner, epoch)) return;
    setState(() => _received = lists);
    _message('Lista collegata in sola lettura.');
  });

  Future<void> _invite(LocalTaskList list) => _run((owner, epoch) async {
    final ticket = await _api.invite(list.id);
    if (!await _accountValid(owner, epoch)) return;
    setState(() {
      _issued = ticket;
      _issuedList = list.id;
    });
    _message('Invito monouso creato: condividi il codice solo con il destinatario.');
  });

  Future<void> _copyInvite() => _run((owner, epoch) async {
    final invite = _issued;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite.token));
    if (!await _accountValid(owner, epoch)) return;
    _message('Codice copiato. Scade dopo 7 giorni e può essere usato una sola volta.');
  });

  Future<void> _open(SharedTaskList list) => _run((owner, epoch) async {
    final snapshot = await _api.snapshot(list.id);
    if (!await _accountValid(owner, epoch)) return;
    setState(() {
      _snapshot = snapshot;
      _editingTaskId = null;
    });
  });

  Future<void> _more() => _run((owner, epoch) async {
    final previous = _snapshot;
    if (previous == null || previous.nextOffset == null) return;
    final page = await _api.snapshot(previous.listId,
        offset: previous.nextOffset!);
    if (!await _accountValid(owner, epoch) || _snapshot != previous) return;
    setState(() => _snapshot = SharedSnapshot(
      listId: previous.listId, title: page.title,
      readOnly: page.readOnly,
      tasks: [...previous.tasks, ...page.tasks],
      nextOffset: page.nextOffset,
    ));
  });

  Future<void> _manage(LocalTaskList list) => _run((owner, epoch) async {
    final members = await _api.members(list.id);
    final pending = await _api.pending(list.id);
    if (!await _accountValid(owner, epoch)) return;
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
    final actor = widget.ownerId;
    final generation = _ownerEpoch;
    if (!await _accountValid(actor, generation)) return;
    if (!await _confirm('Abbandona lista',
        'Non vedrai più le attività di "${list.title}". '
        'Le attività del proprietario non saranno modificate.')) {
      return;
    }
    if (!await _accountValid(actor, generation)) return;
    await _run((owner, epoch) async {
      await _api.leave(list.id);
      if (!await _accountValid(owner, epoch)) return;
      final lists = await _api.sharedLists();
      if (!await _accountValid(owner, epoch)) return;
      setState(() {
        _received = lists;
        if (_snapshot?.listId == list.id) _snapshot = null;
      });
    });
  }

  Future<void> _removeMember(String listId, ListShareMember member) async {
    final actor = widget.ownerId;
    final generation = _ownerEpoch;
    if (!await _accountValid(actor, generation)) return;
    if (!await _confirm('Revoca accesso',
        'Rimuovere il collaboratore dalla lista?')) {
      return;
    }
    if (!await _accountValid(actor, generation)) return;
    await _run((owner, epoch) async {
      await _api.revokeMember(listId, member.id);
      if (!await _accountValid(owner, epoch)) return;
      final refreshed = await _api.members(listId);
      if (!await _accountValid(owner, epoch)) return;
      setState(() => _members = refreshed);
    });
  }

  Future<void> _changeRole(String listId, ListShareMember member) async {
    final actor = widget.ownerId;
    final generation = _ownerEpoch;
    if (!await _accountValid(actor, generation)) return;
    final promote = member.role != 'EDITOR';
    if (!await _confirm(
        promote ? 'Consenti modifiche' : 'Rendi solo lettore',
        promote
          ? 'Questa persona potrà modificare titolo, descrizione, '
            'priorità e completamento dei task nella lista condivisa.'
          : 'Questa persona non potrà più modificare i task.')) {
      return;
    }
    if (!await _accountValid(actor, generation)) return;
    await _run((owner, epoch) async {
      await _api.changeRole(listId, member.id,
          promote ? 'EDITOR' : 'VIEWER');
      if (!await _accountValid(owner, epoch)) return;
      final updated = await _api.members(listId);
      if (!await _accountValid(owner, epoch)) return;
      setState(() => _members = updated);
      _message(promote ? 'Collaboratore abilitato alle modifiche.'
          : 'Collaboratore in sola lettura.');
    });
  }

  void _beginEdit(SharedTaskPreview task) {
    if (_busy || _loading || _snapshot?.readOnly != false) return;
    setState(() {
      _editingTaskId = task.id;
      _draftTitle.text = task.title;
      _draftDescription.text = task.description ?? '';
    });
  }

  Future<void> _reloadSnapshot() => _run((owner, epoch) async {
    final current = _snapshot;
    if (current == null) return;
    final remote = await _api.snapshot(current.listId);
    if (!await _accountValid(owner, epoch) ||
        _snapshot?.listId != current.listId) return;
    setState(() {
      _snapshot = remote;
      _editingTaskId = null;
    });
  });

  Future<void> _editTask(SharedTaskPreview task, {
    String? title, String? description, bool? completed, int? priority,
  }) => _run((owner, epoch) async {
    final current = _snapshot;
    if (current == null || current.readOnly ||
        !current.tasks.any((item) => item.id == task.id &&
            item.version == task.version)) {
      throw const FormatException('Aggiorna la lista prima di modificare.');
    }
    try {
      await _api.editTask(current.listId, task.id,
        expectedVersion: task.version,
        title: title, description: description,
        completed: completed, priority: priority);
    } on ListSharingHttpException catch (error) {
      if (error.status == 409) {
        throw const FormatException('Conflitto: il task è stato modificato '
            'da un altro dispositivo. Aggiorna la lista e riprova.');
      }
      rethrow;
    }
    if (!await _accountValid(owner, epoch)) return;
    // Read back the server snapshot. Never optimistically stage a remote
    // task in Drift or mutate an owner's local /sync cursor.
    final latest = await _api.snapshot(current.listId);
    if (!await _accountValid(owner, epoch) ||
        _snapshot?.listId != current.listId) return;
    setState(() {
      _snapshot = latest;
      _editingTaskId = null;
    });
    _message('Modifica condivisa salvata sul server.');
  });

  Future<void> _revokeInvite(String listId, PendingListInvitation invite) async {
    await _run((owner, epoch) async {
      await _api.revokeInvitation(listId, invite.id);
      if (!await _accountValid(owner, epoch)) return;
      final refreshed = await _api.pending(listId);
      if (!await _accountValid(owner, epoch)) return;
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
                    Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.displayName ?? 'Collaboratore',
                            overflow: TextOverflow.ellipsis),
                          Text(member.role == 'EDITOR'
                              ? 'Può modificare' : 'Sola lettura',
                            style: TextStyle(color: secondary,fontSize: 12)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8,runSpacing: 8,children: [
                            FButton(
                              key: Key('share-role-member-${member.id}'),
                              variant: FButtonVariant.outline,
                              onPress: _busy ? null : () =>
                                  _changeRole(list.id, member),
                              child: Text(member.role == 'EDITOR'
                                  ? 'Rendi lettore' : 'Consenti modifiche')),
                            FButton(
                              key: Key('share-remove-member-${member.id}'),
                              variant: FButtonVariant.ghost,
                              onPress: _busy ? null : () =>
                                  _removeMember(list.id, member),
                              child: const Text('Rimuovi')),
                          ]),
                        ],
                      )),
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
              'Apri i task ricevuti. Se il proprietario abilita EDITOR, '
              'puoi modificarne alcuni campi online.')),
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
                  Text(list.role == 'EDITOR'
                      ? 'Puoi modificare' : 'Sola lettura',
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
          Row(children: [
            Expanded(child: _title('Anteprima · ${_snapshot!.title}',
                _snapshot!.readOnly
                    ? 'Sola lettura. Contenuto aggiornato dal server.'
                    : 'Editor online. Ogni modifica verifica la versione '
                      'del task prima del salvataggio.')),
            FButton(
              key: const Key('share-reload-snapshot'),
              variant: FButtonVariant.ghost,
              onPress: _busy ? null : _reloadSnapshot,
              child: const Text('Aggiorna')),
          ]),
          const SizedBox(height: 8),
          for (final task in _snapshot!.tasks)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: FCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
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
                  ]),
                  if (!_snapshot!.readOnly) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 8,runSpacing: 8,children: [
                      FButton(
                        key: Key('share-edit-${task.id}'),
                        variant: FButtonVariant.outline,
                        onPress: _busy ? null : () => _beginEdit(task),
                        child: const Text('Modifica testo')),
                      FButton(
                        key: Key('share-toggle-${task.id}'),
                        variant: FButtonVariant.ghost,
                        onPress: _busy ? null : () =>
                            _editTask(task, completed: !task.completed),
                        child: Text(task.completed
                            ? 'Segna da fare' : 'Completa')),
                      FButton(
                        key: Key('share-priority-${task.id}'),
                        variant: FButtonVariant.ghost,
                        onPress: _busy ? null : () => _editTask(task,
                            priority: (task.priority + 1) % 4),
                        child: Text('Priorità ${task.priority} → '
                            '${(task.priority + 1) % 4}')),
                    ]),
                  ],
                  if (!_snapshot!.readOnly &&
                      _editingTaskId == task.id) ...[
                    const SizedBox(height: 12),
                    FTextField(
                      key: const Key('share-edit-title'),
                      control: FTextFieldControl.managed(
                          controller: _draftTitle),
                      label: const Text('Titolo'),
                      hint: 'Titolo attività'),
                    const SizedBox(height: 8),
                    FTextField(
                      key: const Key('share-edit-description'),
                      control: FTextFieldControl.managed(
                          controller: _draftDescription),
                      label: const Text('Descrizione'),
                      hint: 'Descrizione (opzionale)'),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8,runSpacing: 8,children: [
                      FButton(
                        key: const Key('share-save-task'),
                        onPress: _busy ? null : () => _editTask(task,
                            title: _draftTitle.text,
                            description: _draftDescription.text),
                        child: const Text('Salva')),
                      FButton(
                        key: const Key('share-cancel-task'),
                        variant: FButtonVariant.ghost,
                        onPress: _busy ? null : () =>
                            setState(() => _editingTaskId = null),
                        child: const Text('Annulla')),
                    ]),
                  ],
                ],
              ))),
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
