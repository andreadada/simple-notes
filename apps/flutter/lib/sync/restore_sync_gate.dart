import 'package:flutter_riverpod/flutter_riverpod.dart';

/// P2.4B2C2: immutable, non-bypassable-by-UI startup sync embargo.
/// Production main overrides this provider BEFORE constructing app providers.
/// No code in the restore prototype can grant permission to resume sync.
class RestoreSyncGate {
  const RestoreSyncGate.ready() : blocked = false;
  const RestoreSyncGate.blocked() : blocked = true;

  final bool blocked;

  bool get canSync => !blocked;
  bool get canRestoreLive => false;
  bool get canReplayImportedOutbox => false;
}

/// Unoverridden containers are used in existing in-memory sync tests.
/// The production bootstrap MUST override with the result of its native
/// probe before any CloudSync/AutoSyncHost is created.
final restoreSyncGateProvider = Provider<RestoreSyncGate>(
    (ref) => const RestoreSyncGate.ready());
