import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/cloud_auth.dart';
import '../data/local_store.dart';
import 'cloud_sync.dart';

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
    }
  }

  // If the app was launched without network, CloudAuth.restore() preserves
  // the refresh token but initially fails. Recover without requiring the user
  // to press Google Login again after the connection comes back.
  void _retryOfflineSession() {
    if (!mounted || !_active || _restoringSession) return;
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
    if (!mounted || !_active) return;
    final auth = ref.read(cloudAuthProvider);
    if (!auth.authenticated || auth.userId == null) return;
    if (ref.read(cloudSyncProvider).conflict ||
        ref.read(cloudSyncProvider).upgradeRequired) return;
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
    if (!mounted || !_active) return;
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
      }
    } finally {
      _inFlight = false;
      if (_queued && mounted && !(_retry?.isActive ?? false)) {
        _queued = false;
        _schedule(delay: const Duration(milliseconds: 400));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CloudSession>(cloudAuthProvider, (previous, next) {
      if (next.authenticated && !(previous?.authenticated ?? false)) {
        _failures = 0;
        _retry?.cancel();
        _retry = null;
        _schedule(delay: Duration.zero);
      } else if (!next.authenticated) {
        _debounce?.cancel();
        _retry?.cancel();
        _retry = null;
        _failures = 0;
        _queued = false;
      }
    });
    ref.listen<int>(localMutationRevisionProvider, (previous, next) {
      _schedule();
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
