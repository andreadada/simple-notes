import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/cloud_auth.dart';
import '../data/task_action_catalog_mirror.dart';
import '../data/task_action_cloud_api.dart';
import '../data/user_template_catalog_mirror.dart';
import '../data/user_template_cloud_api.dart';
import '../data/local_store.dart';
import '../ui/reminder_controller.dart';
import 'cloud_sync.dart';
import 'restore_sync_gate.dart';
import 'task_action_rule_auto_sync.dart';
import 'user_template_auto_sync.dart';

/// Foreground-only auto-sync: offline edits remain in the persistent SQLite
/// outbox. This widget never claims to sync while Android has closed the app.
class AutoSyncHost extends ConsumerStatefulWidget {
  const AutoSyncHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AutoSyncHost> createState() => _AutoSyncHostState();
}

class _AutoSyncHostState extends ConsumerState<AutoSyncHost>
    with WidgetsBindingObserver {
  static const _pullInterval = Duration(seconds: 60);
  static const _editDebounce = Duration(milliseconds: 900);
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _debounce;
  Timer? _periodic;
  Timer? _retry;
  bool _active = true;
  bool _inFlight = false;
  bool _queued = false;
  int _failures = 0;
  bool _restoringSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _periodic = Timer.periodic(_pullInterval, (_) => _schedule());
    _connectivity = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (results.any((value) => value != ConnectivityResult.none)) {
          _retryOfflineSession();
          _schedule(delay: const Duration(seconds: 1));
        }
      },
      onError: (_) {}, // Connectivity is a hint, not proof of API reachability.
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule(delay: Duration.zero);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _retryOfflineSession();
      _schedule(delay: const Duration(seconds: 1));
      ref.read(reminderControllerProvider.notifier).reconcile();
    }
  }

  // If the app was launched without network, CloudAuth.restore() preserves
  // the refresh token but initially fails. Recover without requiring the user
  // to press Google Login again after the connection comes back.
  void _retryOfflineSession() {
    if (!mounted || !_active || _restoringSession ||
        !ref.read(restoreSyncGateProvider).canSync) { return; }
    final session = ref.read(cloudAuthProvider);
    if (session.authenticated ||
        !(session.error?.startsWith('Offline:') == true ||
          session.error?.startsWith('Server non disponibile') == true)) {
      return;
    }
    _restoringSession = true;
    unawaited(ref.read(cloudAuthProvider.notifier).restore().whenComplete(() {
      _restoringSession = false;
    }));
  }

  void _schedule({Duration delay = _editDebounce}) {
    if (!mounted || !_active ||
        !ref.read(restoreSyncGateProvider).canSync) { return; }
    final auth = ref.read(cloudAuthProvider);
    if (!auth.authenticated || auth.userId == null) return;
    if (ref.read(cloudSyncProvider).conflict ||
        ref.read(cloudSyncProvider).upgradeRequired) {
      return;
    }
    if (_inFlight || ref.read(cloudSyncProvider).running) {
      _queued = true;
      return;
    }
    if (_retry?.isActive ?? false) return; // Preserve network backoff.
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      if (mounted) unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (!mounted || !_active ||
        !ref.read(restoreSyncGateProvider).canSync) { return; }
    if (_inFlight) {
      _queued = true;
      return;
    }
    final cloud = ref.read(cloudAuthProvider);
    if (!cloud.authenticated || cloud.userId == null ||
        (ref.read(cloudSyncProvider).conflict ||
          ref.read(cloudSyncProvider).upgradeRequired)) {
      return;
    }
    _inFlight = true;
    try {
      await ref.read(cloudSyncProvider.notifier).synchronize();
      if (!mounted) return;
      final result = ref.read(cloudSyncProvider);
      if (result.conflict || result.upgradeRequired) {
        _retry?.cancel();
        _failures = 0;
        return;
      }
      if (result.message?.startsWith('Sync non riuscita') ?? false) {
        if (_failures < 5) {
          _failures++;
        }
        final seconds = 5 * (1 << (_failures - 1)); // 5, 10, 20, 40, 80.
        _retry?.cancel();
        _retry = Timer(Duration(seconds: seconds), () {
          _retry = null;
          _schedule(delay: Duration.zero);
        });
      } else {
        _failures = 0;
        // Catalog definitions are a separate CAS channel. A missing V12
        // endpoint or failed rule sync must never block normal task sync.
        await _reconcileTaskActionRules(cloud.userId!);
        await _reconcileUserTemplates(cloud.userId!);
      }
    } finally {
      _inFlight = false;
      if (_queued && mounted && !(_retry?.isActive ?? false)) {
        _queued = false;
        _schedule(delay: const Duration(milliseconds: 400));
      }
    }
  }


  Future<void> _reconcileTaskActionRules(String owner) async {
    if (!mounted || !_active ||
        ref.read(taskActionEditorVisibleProvider) ||
        !ref.read(restoreSyncGateProvider).canSync ||
        !CloudConfig.enabled) {
      return;
    }

    Future<bool> ownerGuard(String candidate) async {
      if (!mounted || !_active || candidate != owner ||
          !ref.read(restoreSyncGateProvider).canSync ||
          ref.read(taskActionEditorVisibleProvider)) {
        return false;
      }
      final session = ref.read(cloudAuthProvider);
      if (!session.authenticated || session.userId != candidate) return false;
      return await ref.read(databaseProvider).setting('boundOwnerId') ==
          candidate;
    }

    if (!await ownerGuard(owner)) return;
    final api = TaskActionCloudApi(
      baseUrl: CloudConfig.apiBaseUrl,
      tokenProvider: () =>
          ref.read(cloudAuthProvider.notifier).validAccessToken(),
    );
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await ownerGuard(owner)) return;
      final result = await const TaskActionCatalogMirror().synchronize(
        preferences: preferences,
        owner: owner,
        api: api,
        ownerMatches: ownerGuard,
      );
      if (!mounted || ref.read(cloudAuthProvider).userId != owner) return;
      final phase = switch (result) {
        TaskActionMirrorResult.unchanged ||
        TaskActionMirrorResult.initialized =>
          TaskActionAutoSyncPhase.aligned,
        TaskActionMirrorResult.uploaded => TaskActionAutoSyncPhase.uploaded,
        TaskActionMirrorResult.downloaded => TaskActionAutoSyncPhase.downloaded,
        TaskActionMirrorResult.conflict => TaskActionAutoSyncPhase.conflict,
        TaskActionMirrorResult.skipped => TaskActionAutoSyncPhase.paused,
      };
      ref.read(taskActionAutoSyncStateProvider.notifier).state =
          TaskActionAutoSyncState(ownerId: owner, phase: phase);
    } on TaskActionCloudConflict {
      _setRuleStatus(owner, TaskActionAutoSyncPhase.conflict);
    } on TaskActionCloudUnavailable {
      _setRuleStatus(owner, TaskActionAutoSyncPhase.unavailable);
    } on FormatException {
      _setRuleStatus(owner, TaskActionAutoSyncPhase.invalid);
    } catch (_) {
      _setRuleStatus(owner, TaskActionAutoSyncPhase.offline);
    } finally {
      api.close();
    }
  }


  Future<void> _reconcileUserTemplates(String owner) async {
    if (!mounted || !_active ||
        !ref.read(restoreSyncGateProvider).canSync ||
        !CloudConfig.enabled) {
      return;
    }
    if (ref.read(userTemplatesEditorVisibleProvider)) {
      _setTemplateStatus(owner, UserTemplateAutoSyncPhase.paused);
      return;
    }

    Future<bool> ownerGuard(String candidate) async {
      if (!mounted || !_active || candidate != owner ||
          ref.read(userTemplatesEditorVisibleProvider) ||
          !ref.read(restoreSyncGateProvider).canSync) return false;
      final session = ref.read(cloudAuthProvider);
      if (!session.authenticated || session.userId != candidate) return false;
      return await ref.read(databaseProvider).setting('boundOwnerId') ==
          candidate;
    }

    if (!await ownerGuard(owner)) return;
    final api = UserTemplateCloudApi(
      baseUrl: CloudConfig.apiBaseUrl,
      tokenProvider: () =>
          ref.read(cloudAuthProvider.notifier).validAccessToken(),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await ownerGuard(owner)) return;
      final result = await const UserTemplateCatalogMirror().synchronize(
        preferences: prefs,
        owner: owner,
        api: api,
        ownerMatches: ownerGuard,
      );
      if (!mounted || ref.read(cloudAuthProvider).userId != owner) return;
      final phase = switch (result) {
        UserTemplateMirrorResult.unchanged => UserTemplateAutoSyncPhase.aligned,
        UserTemplateMirrorResult.uploaded => UserTemplateAutoSyncPhase.uploaded,
        UserTemplateMirrorResult.downloaded => UserTemplateAutoSyncPhase.downloaded,
        UserTemplateMirrorResult.conflict => UserTemplateAutoSyncPhase.conflict,
        UserTemplateMirrorResult.skipped => UserTemplateAutoSyncPhase.paused,
      };
      _setTemplateStatus(owner, phase);
    } on UserTemplateCloudConflict {
      _setTemplateStatus(owner, UserTemplateAutoSyncPhase.conflict);
    } on UserTemplateCloudUnavailable {
      _setTemplateStatus(owner, UserTemplateAutoSyncPhase.unavailable);
    } on FormatException {
      _setTemplateStatus(owner, UserTemplateAutoSyncPhase.invalid);
    } catch (_) {
      _setTemplateStatus(owner, UserTemplateAutoSyncPhase.offline);
    } finally {
      api.close();
    }
  }

  void _setTemplateStatus(String owner, UserTemplateAutoSyncPhase phase) {
    if (!mounted || ref.read(cloudAuthProvider).userId != owner) return;
    ref.read(userTemplateAutoSyncStateProvider.notifier).state =
        UserTemplateAutoSyncState(ownerId: owner, phase: phase);
  }

  void _setRuleStatus(String owner, TaskActionAutoSyncPhase phase) {
    if (!mounted || ref.read(cloudAuthProvider).userId != owner) return;
    ref.read(taskActionAutoSyncStateProvider.notifier).state =
        TaskActionAutoSyncState(ownerId: owner, phase: phase);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CloudSession>(cloudAuthProvider, (previous, next) {
      if (next.authenticated &&
          (!(previous?.authenticated ?? false) ||
           previous?.userId != next.userId)) {
        _failures = 0;
        _retry?.cancel();
        _retry = null;
        _schedule(delay: Duration.zero);
        ref.read(reminderControllerProvider.notifier).reconcile();
      } else if (!next.authenticated) {
        ref.read(taskActionAutoSyncStateProvider.notifier).state =
            const TaskActionAutoSyncState();
        ref.read(userTemplateAutoSyncStateProvider.notifier).state =
            const UserTemplateAutoSyncState();
        _debounce?.cancel();
        _retry?.cancel();
        _retry = null;
        _failures = 0;
        _queued = false;
      }
    });
    ref.listen<int>(userTemplatesEditRevisionProvider, (previous, next) {
      _schedule();
    });
    ref.listen<bool>(userTemplatesEditorVisibleProvider, (previous, next) {
      if (next) {
        final owner = ref.read(cloudAuthProvider).userId;
        if (owner != null) {
          _setTemplateStatus(owner, UserTemplateAutoSyncPhase.paused);
        }
      } else {
        _schedule(delay: const Duration(milliseconds: 400));
      }
    });
    ref.listen<int>(taskActionRulesEditRevisionProvider, (previous, next) {
      _schedule();
    });
    ref.listen<bool>(taskActionEditorVisibleProvider, (previous, next) {
      if (!next) _schedule(delay: const Duration(milliseconds: 400));
    });
    ref.listen<int>(localMutationRevisionProvider, (previous, next) {
      _schedule();
      ref.read(reminderControllerProvider.notifier).reconcile();
    });
    // Remote pulls update the local snapshot without increasing the local
    // mutation revision. Reconcile native reminders after either source.
    ref.listen<LocalData>(localStoreProvider, (previous, next) {
      ref.read(reminderControllerProvider.notifier).reconcile();
    });
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _periodic?.cancel();
    _retry?.cancel();
    unawaited(_connectivity?.cancel());
    super.dispose();
  }
}
