import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'recovery_directory_barrier.dart';

/// POSIX directory fsync via libc, available to *Linux sandbox tests only*.
/// Android/macOS/Windows intentionally fail closed until their native storage,
/// package update and power-loss behavior have been verified independently.
///
/// This is an OS sync request, not a guarantee that a VM, storage controller,
/// SQLite database, preferences, and cloud reconcile atomically.
class PosixSandboxDirectorySync implements RecoveryDirectoryBarrier {
  const PosixSandboxDirectorySync();

  @override
  bool get supportedHere => Platform.isLinux;

  @override
  Future<void> syncDirectory(Directory directory) async {
    if (!supportedHere) {
      throw UnsupportedError('Directory fsync non attestato su questa OS.');
    }
    if (await FileSystemEntity.type(
          directory.path, followLinks: false,
        ) != FileSystemEntityType.directory) {
      throw const FormatException('Directory fsync non regolare.');
    }

    final libc = DynamicLibrary.open('libc.so.6');
    final malloc = libc.lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)>('malloc');
    final free = libc.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('free');
    final opendir = libc.lookupFunction<
        Pointer<Void> Function(Pointer<Int8>),
        Pointer<Void> Function(Pointer<Int8>)>('opendir');
    final dirfd = libc.lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('dirfd');
    final fsync = libc.lookupFunction<
        Int32 Function(Int32),
        int Function(int)>('fsync');
    final closedir = libc.lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('closedir');

    final bytes = utf8.encode(directory.absolute.path);
    if (bytes.contains(0)) {
      throw const FormatException('Directory fsync con NUL.');
    }
    final raw = malloc(bytes.length + 1);
    if (raw.address == 0) {
      throw const FileSystemException('Allocazione path fsync fallita.');
    }
    final pathBytes = raw.cast<Uint8>();
    Pointer<Void> dir = Pointer<Void>.fromAddress(0);
    try {
      for (var i = 0; i < bytes.length; i++) {
        pathBytes[i] = bytes[i];
      }
      pathBytes[bytes.length] = 0;
      dir = opendir(pathBytes.cast<Int8>());
      if (dir.address == 0) {
        throw FileSystemException(
          'Impossibile aprire directory per fsync.', directory.path,
        );
      }
      final fd = dirfd(dir);
      if (fd < 0 || fsync(fd) != 0) {
        throw FileSystemException(
          'Fsync directory non riuscito.', directory.path,
        );
      }
    } finally {
      try {
        if (dir.address != 0 && closedir(dir) != 0) {
          throw FileSystemException(
            'Chiusura directory dopo fsync non riuscita.', directory.path,
          );
        }
      } finally {
        free(raw);
      }
    }
  }
}
