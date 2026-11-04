import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../sync/restore_sync_gate.dart';
import 'full_backup_recovery_guard.dart';

/// Fail-closed *read-only* check, before opening SQLite, auth or AutoSync.
/// A future restore writer must use this reserved directory, but there is no
/// production restore writer today. Existing profiles have no such directory.
Future<RestoreSyncGate> probeRestoreStartup({Directory? supportDirectory}) async {
  try {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final reserved = path.join(support.path, 'simple-notes-recovery-v1');
    final type = await FileSystemEntity.type(reserved, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return const RestoreSyncGate.ready();
    }
    // Any marker, directory, symlink, invalid journal or partial write must
    // prevent the application from opening its database or starting OAuth.
    if (type == FileSystemEntityType.directory) {
      await FileRestoreJournal(Directory(reserved)).read();
    }
    return const RestoreSyncGate.blocked();
  } catch (_) {
    return const RestoreSyncGate.blocked();
  }
}
