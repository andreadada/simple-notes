import 'package:flutter/foundation.dart';

import '../sync/restore_sync_gate.dart';

/// Web has no native SQLite restore workflow. No filesystem-based recovery
/// is supported on web; never invoke NativeDatabase/IO recovery code here.
Future<RestoreSyncGate> probeRestoreStartup() async {
  assert(kIsWeb);
  return const RestoreSyncGate.ready();
}
