import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/task_action_automations.dart';
import '../data/task_action_cloud_api.dart';
import '../data/task_action_catalog_mirror.dart';
import 'notes_dialogs.dart';
import 'notes_theme.dart';

/// Rule configuration, independent of the OS notification opt-in.
/// Only explicit local task creation/completion can evaluate these rules.
class TaskActionAutomationsPanel extends StatefulWidget {
  const TaskActionAutomationsPanel({
    super.key, required this.ownerId, required this.lists,
    this.cloudApiBaseUrl = '', this.cloudTokenProvider,
    this.cloudOwnerGuard, this.cloudApi,
    this.autoSyncLabel, this.onRuleCatalogChanged,
    this.onEditorVisibilityChanged,
  });

  final String? ownerId;
  final List<LocalTaskList> lists;
  final String cloudApiBaseUrl;
  final Future<String> Function()? cloudTokenProvider;
  final Future<bool> Function(String owner)? cloudOwnerGuard;
  /// Injectable in widget tests. The caller retains client ownership.
  final TaskActionCloudApi? cloudApi;
  final String? autoSyncLabel;
  final VoidCallback? onRuleCatalogChanged;
  final ValueChanged<bool>? onEditorVisibilityChanged;

  @override
  State<TaskActionAutomationsPanel> createState() =>
      _TaskActionAutomationsPanelState();
}

class _TaskActionAutomationsPanelState
    extends State<TaskActionAutomationsPanel> {
  TaskActionLibrary _library = TaskActionLibrary();
  SharedPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;
  bool _cloudBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onEditorVisibilityChanged?.call(true);
    });
  }

  @override
  void dispose() {
    // Riverpod listeners must not be notified during widget disposal.
    final callback = widget.onEditorVisibilityChanged;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callback?.call(false);
    });
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaskActionAutomationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId == widget.ownerId) return;
    _library = TaskActionLibrary();
    _prefs = null;
    _loading = true;
    _saving = false;
    _cloudBusy = false;
    _error = null;
    _load();
  }

  Future<void> _load() async {
    final owner = widget.ownerId;
    if (owner == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final library = await const TaskActionStore().load(prefs, owner);
      if (!mounted || owner != widget.ownerId) return;
      setState(() {
        _prefs = prefs;
        _library = library;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || owner != widget.ownerId) return;
      setState(() {
        _loading = false;
        _error = 'Le automazioni sui task non sono leggibili. '
            'Le impostazioni precedenti restano intatte.';
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)));
  }

  Future<void> _save(TaskActionLibrary next) async {
    if (_loading || _saving || _cloudBusy || _error != null || _prefs == null ||
        widget.ownerId == null) {
      return;
    }
    final owner = widget.ownerId!;
    setState(() => _saving = true);
    try {
      // A pre-existing background read must never clobber an edit made
      // after this panel loaded its original catalog.
      final stored = await const TaskActionStore().load(_prefs!, owner);
      if (stored.serialize() != _library.serialize()) {
        if (mounted && owner == widget.ownerId) {
          setState(() => _library = stored);
          _message('Le regole sono cambiate: modifica non sovrascritta.');
        }
        return;
      }
      await const TaskActionStore().save(_prefs!, owner, next);
      if (!mounted || owner != widget.ownerId) return;
      setState(() => _library = next);
      widget.onRuleCatalogChanged?.call();
    } catch (_) {
      if (mounted && owner == widget.ownerId) {
        _message('Regola non salvata: nessun dato precedente eliminato.');
      }
    } finally {
      if (mounted && owner == widget.ownerId) {
        setState(() => _saving = false);
      }
    }
  }


  bool get _cloudAvailable => widget.ownerId != null &&
      widget.cloudOwnerGuard != null &&
      (widget.cloudApi != null ||
       (widget.cloudTokenProvider != null &&
        widget.cloudApiBaseUrl.isNotEmpty));

  Future<bool> _verifiedOwner(String owner) async {
    if (!mounted || widget.ownerId != owner ||
        widget.cloudOwnerGuard == null) {
      return false;
    }
    final permitted = await widget.cloudOwnerGuard!(owner);
    return permitted && mounted && widget.ownerId == owner;
  }

  Future<bool> _confirmCloud({
    required String title, required String message,
    required String action,
  }) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: Text(title),
        body: Text(message),
        actions: [
          FButton(variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
          FButton(
            key: const Key('action-cloud-confirm'),
            onPress: () => Navigator.pop(ctx, true),
            child: Text(action)),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _exchangeCloud({required bool upload}) async {
    if (!_cloudAvailable || _cloudBusy || _saving || _loading ||
        _error != null || _prefs == null) {
      return;
    }
    final owner = widget.ownerId!;
    // Lock the editor before asynchronous owner checks. Rapid double taps
    // must never create parallel PUT/download flows.
    setState(() => _cloudBusy = true);
    final api = widget.cloudApi ?? TaskActionCloudApi(
      baseUrl: widget.cloudApiBaseUrl,
      tokenProvider: widget.cloudTokenProvider!,
    );
    try {
      if (!await _verifiedOwner(owner)) {
        _message('Account Google e archivio locale non corrispondono.');
        return;
      }
      final source = _library.serialize();
      final current = await const TaskActionStore().load(_prefs!, owner);
      if (current.serialize() != source || !await _verifiedOwner(owner)) {
        _message('Il catalogo locale è cambiato: operazione annullata.');
        return;
      }
      final remote = await api.read();
      if (!await _verifiedOwner(owner)) return;
      if (remote.library.serialize() == source) {
        await const TaskActionCatalogMirror().acknowledgeManual(
          preferences: _prefs!, owner: owner, snapshot: remote);
        if (!await _verifiedOwner(owner)) return;
        widget.onRuleCatalogChanged?.call();
        _message('Le regole sono già identiche sui due dispositivi.');
        return;
      }
      if (upload) {
        final accepted = await _confirmCloud(
          title: 'Pubblica regole sul cloud',
          message: 'Pubblicare ${_library.rules.length} regole per '
              'questo account? Sul cloud ci sono '
              '${remote.library.rules.length} regole (versione '
              '${remote.version}). Saranno sostituite solo se '
              'nessun altro dispositivo ha modificato quella versione. '
              'I task esistenti non vengono toccati.',
          action: 'Pubblica',
        );
        if (!accepted || !await _verifiedOwner(owner)) return;
        final latest = await const TaskActionStore().load(_prefs!, owner);
        if (latest.serialize() != source ||
            _library.serialize() != source) {
          _message('Le regole locali sono cambiate. Riprova.');
          return;
        }
        final saved = await api.replace(
          expectedVersion: remote.version, library: latest);
        if (!await _verifiedOwner(owner)) return;
        try {
          await const TaskActionCatalogMirror().acknowledgeManual(
            preferences: _prefs!, owner: owner, snapshot: saved);
        } catch (_) {
          _message('Regole pubblicate sul cloud, ma checkpoint locale '
              'non aggiornato. Il prossimo controllo confronterà i cataloghi.');
          return;
        }
        if (!await _verifiedOwner(owner)) return;
        widget.onRuleCatalogChanged?.call();
        _message('Pubblicate ${saved.library.rules.length} regole '
            '(versione ${saved.version}).');
      } else {
        if (remote.version == 0) {
          _message('Non ci sono regole pubblicate sul cloud.');
          return;
        }
        final accepted = await _confirmCloud(
          title: 'Scarica regole cloud',
          message: 'Sostituire le ${_library.rules.length} regole '
              'locali con le ${remote.library.rules.length} regole '
              'del cloud (versione ${remote.version})? '
              'Le attività non cambiano. I cambiamenti locali '
              'non pubblicati andranno persi.',
          action: 'Sostituisci regole',
        );
        if (!accepted || !await _verifiedOwner(owner)) return;
        final latest = await const TaskActionStore().load(_prefs!, owner);
        if (latest.serialize() != source ||
            _library.serialize() != source) {
          _message('Le regole locali sono cambiate. Riprova.');
          return;
        }
        await const TaskActionStore().save(
          _prefs!, owner, remote.library);
        if (!await _verifiedOwner(owner)) return;
        // Reflect the successful local write even if saving the secondary
        // checkpoint fails; never display a stale rule catalog afterwards.
        setState(() => _library = remote.library);
        widget.onRuleCatalogChanged?.call();
        try {
          await const TaskActionCatalogMirror().acknowledgeManual(
            preferences: _prefs!, owner: owner, snapshot: remote);
        } catch (_) {
          _message('Regole scaricate sul dispositivo, ma checkpoint '
              'non aggiornato. Il prossimo controllo confronterà i cataloghi.');
          return;
        }
        if (!await _verifiedOwner(owner)) return;
        _message('Regole cloud scaricate su questo dispositivo.');
      }
    } on TaskActionCloudConflict {
      _message('Il cloud è cambiato su un altro dispositivo. '
          'Nessuna regola è stata sovrascritta. '
          'Scarica o riprova dopo aver confrontato le regole.');
    } on TaskActionCloudUnavailable {
      _message('Il server non supporta ancora il catalogo automazioni '
          '(deploy V12 richiesto). Nessun dato modificato.');
    } on FormatException {
      _message('Catalogo cloud non compatibile: nessun dato sovrascritto.');
    } catch (_) {
      _message('Scambio cloud non riuscito. '
          'Le regole locali sono state conservate.');
    } finally {
      if (widget.cloudApi == null) api.close();
      if (mounted && owner == widget.ownerId) {
        setState(() => _cloudBusy = false);
      }
    }
  }

  Future<void> _edit([TaskActionRule? original]) async {
    if (_loading || _saving || _cloudBusy || _error != null || widget.ownerId == null) {
      return;
    }
    final owner = widget.ownerId;
    var keyword = original?.titleContains ?? '';
    var tag = original?.action == 'tag' ? original!.value : '';
    var trigger = original?.trigger ?? 'created';
    var action = original?.action ?? 'priority';
    var priority = original?.action == 'priority'
        ? original!.value : '2';
    var targetList = original?.action == 'list'
        ? original!.value : (widget.lists.firstOrNull?.id ?? '');
    final edited = await showFDialog<TaskActionRule>(
        context: context,
        builder: (ctx, style, animation) => StatefulBuilder(
          builder: (inner, refresh) => NotesDialog(
            style: style, animation: animation,
            title: Text(original == null ? 'Nuova automazione task'
                : 'Modifica automazione task'),
            body: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quando'),
                const SizedBox(height: 7),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final option in const [
                    ('created', 'Task creato'),
                    ('completed', 'Task completato'),
                  ])
                    FButton(
                      key: Key('action-trigger-${option.$1}'),
                      mainAxisSize: MainAxisSize.min,
                      variant: trigger == option.$1
                          ? FButtonVariant.ghost : FButtonVariant.outline,
                      onPress: () => refresh(() => trigger = option.$1),
                      child: Text('${trigger == option.$1 ? '✓ ' : ''}'
                          '${option.$2}'),
                    ),
                ]),
                const SizedBox(height: 14),
                const Text('Solo se il titolo contiene (facoltativo)'),
                const SizedBox(height: 7),
                Material(
                  type: MaterialType.transparency,
                  child: TextFormField(
                    key: const Key('action-keyword'),
                    initialValue: keyword,
                    onChanged: (value) => keyword = value,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      hintText: 'Es. esame',
                      filled: false,
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Azione'),
                const SizedBox(height: 7),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final option in const [
                    ('priority', 'Imposta priorità'),
                    ('tag', 'Aggiungi tag'),
                    ('list', 'Sposta in lista'),
                  ])
                    FButton(
                      key: Key('action-type-${option.$1}'),
                      mainAxisSize: MainAxisSize.min,
                      variant: action == option.$1
                          ? FButtonVariant.ghost : FButtonVariant.outline,
                      onPress: () => refresh(() => action = option.$1),
                      child: Text('${action == option.$1 ? '✓ ' : ''}'
                          '${option.$2}'),
                    ),
                ]),
                const SizedBox(height: 12),
                if (action == 'priority')
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final value in const ['0', '1', '2', '3'])
                      FButton(
                        key: Key('action-priority-$value'),
                        variant: priority == value
                            ? FButtonVariant.ghost : FButtonVariant.outline,
                        mainAxisSize: MainAxisSize.min,
                        onPress: () => refresh(() => priority = value),
                        child: Text('${priority == value ? '✓ ' : ''}P$value'),
                      ),
                  ])
                else if (action == 'tag')
                  Material(
                    type: MaterialType.transparency,
                    child: TextFormField(
                      key: const Key('action-tag'),
                      initialValue: tag,
                      onChanged: (value) => tag = value,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        hintText: 'Tag da aggiungere',
                        filled: false, border: UnderlineInputBorder(),
                      ),
                    ),
                  )
                else if (widget.lists.isEmpty)
                  const Text('Crea prima una lista per usare questa azione.')
                else
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final list in widget.lists)
                      FButton(
                        key: Key('action-list-${list.id}'),
                        mainAxisSize: MainAxisSize.min,
                        variant: targetList == list.id
                            ? FButtonVariant.ghost : FButtonVariant.outline,
                        onPress: () => refresh(() => targetList = list.id),
                        child: Text('${targetList == list.id ? '✓ ' : ''}'
                            '${list.title}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ]),
                const SizedBox(height: 10),
                const Text('Si applica soltanto al prossimo evento locale, '
                    'prima del salvataggio SQLite. '
                    'Non viene ricalcolata sui task già presenti.'),
              ],
            )),
            actions: [
              FButton(
                variant: FButtonVariant.ghost,
                onPress: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              FButton(
                key: const Key('action-rule-save'),
                onPress: () {
                  final value = switch (action) {
                    'priority' => priority,
                    'tag' => tag.trim(),
                    _ => targetList,
                  };
                  try {
                    final result = original == null
                        ? TaskActionLibrary.newRule(
                            trigger: trigger, action: action, value: value,
                            titleContains: keyword.trim())
                        : original.copyWith(
                            trigger: trigger, action: action, value: value,
                            titleContains: keyword.trim());
                    result.validate();
                    Navigator.pop(ctx, result);
                  } on FormatException {
                    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                      const SnackBar(content: Text(
                        'Compila un valore valido per questa regola.')));
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          ),
        ),
      );
    if (!mounted || owner != widget.ownerId || edited == null) return;
    try {
      await _save(_library.upsert(edited));
    } on FormatException {
      _message('Limite di 20 regole raggiunto.');
    }
  }

  Future<void> _remove(TaskActionRule rule) async {
    if (_loading || _saving || _cloudBusy || _error != null) return;
    final owner = widget.ownerId;
    final accepted = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => NotesDialog(
        style: style, animation: animation,
        title: const Text('Elimina regola'),
        body: const Text('La regola non verrà applicata ai prossimi '
            'task. Nessuna attività esistente viene modificata.'),
        actions: [
          FButton(variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: const Text('Annulla')),
          FButton(key: const Key('action-rule-confirm-delete'),
            onPress: () => Navigator.pop(ctx, true),
            child: const Text('Elimina')),
        ],
      ),
    );
    if (!mounted || owner != widget.ownerId || accepted != true) return;
    await _save(_library.remove(rule.id));
  }

  String _describe(TaskActionRule rule) {
    final condition = rule.titleContains.isEmpty
        ? 'Tutti i titoli' : 'Titolo contiene "${rule.titleContains}"';
    final action = switch (rule.action) {
      'priority' => 'Priorità P${rule.value}',
      'tag' => 'Aggiungi #${rule.value}',
      _ => 'Lista: ${widget.lists.where((x) => x.id == rule.value)
          .firstOrNull?.title ?? 'non disponibile'}',
    };
    return '${rule.trigger == 'created' ? 'Alla creazione' : 'Al completamento'}'
        ' · $condition · $action';
  }

  @override
  Widget build(BuildContext context) {
    final colors = NotesPalette.of(context);
    final editable = !_loading && !_saving && !_cloudBusy &&
        _error == null &&
        widget.ownerId != null;
    return Column(
      key: const Key('task-action-automations-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Azioni automatiche sulle attività', style: TextStyle(
          fontWeight: FontWeight.w600, fontSize: 18,
          color: colors.foreground)),
        const SizedBox(height: 8),
        Text('Se crei o completi un task, puoi assegnare una priorità, '
            'aggiungere un tag o spostarlo in una lista. '
            'Ogni effetto entra nella normale sincronizzazione del task. '
            'Le regole sono locali al dispositivo.',
          style: TextStyle(color: colors.secondaryText, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Regole sui task')),
          FButton(
            key: const Key('action-rule-add'),
            mainAxisSize: MainAxisSize.min,
            onPress: editable && _library.rules.length < 20
                ? () => _edit() : null,
            child: const Text('Nuova regola'),
          ),
        ]),
        if (_loading) const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
        if (_error != null)
          Text(_error!, key: const Key('action-rule-load-error'),
            style: const TextStyle(color: Colors.orangeAccent)),
        if (!_loading && _library.rules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nessuna azione automatica configurata.'),
          ),
        for (final rule in _library.rules)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_describe(rule),
                  style: TextStyle(color: colors.foreground)),
                const SizedBox(height: 5),
                Text(rule.enabled ? 'Attiva' : 'Disattivata',
                    style: TextStyle(color: colors.secondaryText)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FButton(
                    key: Key('action-rule-toggle-${rule.id}'),
                    mainAxisSize: MainAxisSize.min,
                    variant: FButtonVariant.outline,
                    onPress: editable ? () => _save(_library.upsert(
                      rule.copyWith(enabled: !rule.enabled))) : null,
                    child: Text(rule.enabled ? 'Disattiva' : 'Attiva'),
                  ),
                  FButton(
                    key: Key('action-rule-edit-${rule.id}'),
                    mainAxisSize: MainAxisSize.min,
                    variant: FButtonVariant.outline,
                    onPress: editable ? () => _edit(rule) : null,
                    child: const Text('Modifica'),
                  ),
                  FButton(
                    key: Key('action-rule-delete-${rule.id}'),
                    mainAxisSize: MainAxisSize.min,
                    variant: FButtonVariant.ghost,
                    onPress: editable ? () => _remove(rule) : null,
                    child: const Text('Elimina'),
                  ),
                ]),
              ],
            )),
          ),
        if (_cloudAvailable) ...[
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text('Regole cloud per questo account', style: TextStyle(
            fontWeight: FontWeight.w600, color: colors.foreground)),
          const SizedBox(height: 6),
          Text('Le regole si allineano in automatico mentre l’app è '
              'aperta e il server è disponibile. Se due dispositivi '
              'modificano le regole offline, nessuna versione viene '
              'sovrascritta: usa Pubblica o Scarica per risolvere. '
              'La modifica su questa schermata sospende '
              'temporaneamente l’auto-sync. Nessun task viene modificato.',
            style: TextStyle(color: colors.secondaryText, fontSize: 12)),
          if (widget.autoSyncLabel != null) ...[
            const SizedBox(height: 10),
            Text(widget.autoSyncLabel!,
              key: const Key('action-auto-sync-status'),
              style: TextStyle(color: colors.secondaryText, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FButton(
              key: const Key('action-cloud-upload'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: editable ? () => _exchangeCloud(upload: true) : null,
              child: const Text('Pubblica sul cloud')),
            FButton(
              key: const Key('action-cloud-download'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: editable ? () => _exchangeCloud(upload: false) : null,
              child: const Text('Scarica dal cloud')),
          ]),
          if (_cloudBusy) Text(
            'Scambio cloud in corso o in attesa di conferma…',
            key: const Key('action-cloud-busy'),
            style: TextStyle(color: colors.secondaryText, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Text('Le ricorrenze avanzano senza attivare il trigger '
            '“completato”. I task ricevuti dal cloud, importati o già '
            'presenti non attivano regole retroattive.',
          style: TextStyle(color: colors.secondaryText, fontSize: 12)),
      ],
    );
  }
}
