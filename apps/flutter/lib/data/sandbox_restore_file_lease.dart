import 'dart:io';

import 'package:path/path.dart' as path;

/// P2.4B2V: cooperative, NON-PRODUCTION lock for one disposable restore
/// rehearsal. The OS file lock serializes cooperating processes; the in-isolate
/// guard closes a platform-dependent gap for two Dart callers in one process.
///
/// Deliberately does not claim crash durability, hostile-path resistance or
/// platform-wide exclusion of SQLite/SharedPreferences writers. File locks
/// are advisory. The installed profile never uses this class.
class SandboxRestoreFileLease {
  const SandboxRestoreFileLease(this.directory);

  final Directory directory;

  static final Set<String> _heldInIsolate = <String>{};

  File get lockFile =>
      File(path.join(directory.path, 'exclusive.lock'));

  Future<T> runExclusive<T>(Future<T> Function() action) async {
    final root = path.normalize(directory.absolute.path);
    if (!path.basename(root).startsWith(
          'simple-notes-restore-rehearsal-',
        ) ||
        await FileSystemEntity.type(root, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw const FormatException('Directory sandbox non sicura.');
    }
    if (!_heldInIsolate.add(root)) {
      throw StateError('Sandbox già in uso nel processo.');
    }

    RandomAccessFile? handle;
    var locked = false;
    try {
      final before = await FileSystemEntity.type(
        lockFile.path, followLinks: false,
      );
      if (before != FileSystemEntityType.notFound &&
          before != FileSystemEntityType.file) {
        throw const FormatException('Lock sandbox non regolare.');
      }
      // Append never truncates an existing lock file. Do not remove this
      // inode on release: another process might still hold a lock on it.
      handle = await lockFile.open(mode: FileMode.append);
      try {
        // Dart's exclusive mode is non-blocking: refuse contention rather
        // than waiting indefinitely during an interrupted restore.
        await handle.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException {
        throw StateError('Lock sandbox occupato o non disponibile.');
      }
      if (await FileSystemEntity.type(
            root, followLinks: false,
          ) != FileSystemEntityType.directory ||
          await FileSystemEntity.type(
            lockFile.path, followLinks: false,
          ) != FileSystemEntityType.file ||
          await handle.length() != 0) {
        throw const FormatException('Lock sandbox alterato.');
      }
      return await action();
    } finally {
      try {
        if (locked) await handle!.unlock();
      } finally {
        try {
          await handle?.close();
        } finally {
          _heldInIsolate.remove(root);
        }
      }
    }
  }
}
