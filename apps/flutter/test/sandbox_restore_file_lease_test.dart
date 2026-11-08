import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:simple_notes/data/sandbox_restore_file_lease.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'simple-notes-restore-rehearsal-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('second instance fails closed while the first holds the lease',
      () async {
    final firstEntered = Completer<void>();
    final firstMayFinish = Completer<void>();
    final first = SandboxRestoreFileLease(directory).runExclusive(() async {
      firstEntered.complete();
      await firstMayFinish.future;
      return 42;
    });
    await firstEntered.future;
    var secondRan = false;
    try {
      await expectLater(
        SandboxRestoreFileLease(directory).runExclusive(() async {
          secondRan = true;
          return 0;
        }),
        throwsStateError,
      );
    } finally {
      firstMayFinish.complete();
    }
    expect(await first, 42);
    expect(secondRan, isFalse);
    expect(await File(path.join(directory.path, 'exclusive.lock')).length(), 0);
  });

  test('separate Dart process holding OS lock excludes recovery', () async {
    final holder = await Process.start(
      'dart',
      ['test/support/hold_sandbox_lease.dart', directory.path],
      workingDirectory: Directory.current.path,
    );
    addTearDown(() async {
      if (holder.kill()) {
        await holder.exitCode;
      }
    });
    try {
      final ready = await holder.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 30));
      expect(ready, 'LOCKED');
      var entered = false;
      await expectLater(
        SandboxRestoreFileLease(directory).runExclusive(() async {
          entered = true;
          return 1;
        }),
        throwsStateError,
      );
      expect(entered, isFalse);
      holder.stdin.writeln('release');
      await holder.stdin.flush();
      expect(
        await holder.exitCode.timeout(const Duration(seconds: 15)),
        0,
      );
      // The same OS lock inode is reusable after a real process exit.
      expect(
        await SandboxRestoreFileLease(directory)
            .runExclusive(() async => 10),
        10,
      );
    } finally {
      holder.kill();
    }
  });

  test('after failure the lease releases and a new instance can recover',
      () async {
    final first = SandboxRestoreFileLease(directory);
    await expectLater(
      first.runExclusive<void>(() async {
        throw StateError('simulated process interruption');
      }),
      throwsStateError,
    );
    final next = SandboxRestoreFileLease(directory);
    expect(await next.runExclusive(() async => 'recovered'), 'recovered');
    // The lock inode is retained, not removed/recreated between processes.
    expect(
      await FileSystemEntity.type(
        next.lockFile.path, followLinks: false,
      ),
      FileSystemEntityType.file,
    );
  });

  test('nonempty lock file blocks without truncating or executing work',
      () async {
    final lease = SandboxRestoreFileLease(directory);
    await lease.lockFile.writeAsString('unexpected data', flush: true);
    var called = false;
    await expectLater(
      lease.runExclusive(() async {
        called = true;
      }),
      throwsFormatException,
    );
    expect(called, isFalse);
    expect(await lease.lockFile.readAsString(), 'unexpected data');
  });

  test('unexpected directory name is rejected without creating a lock',
      () async {
    final unsafe = await Directory.systemTemp.createTemp(
      'other-application-',
    );
    addTearDown(() async {
      if (await unsafe.exists()) await unsafe.delete(recursive: true);
    });
    final lease = SandboxRestoreFileLease(unsafe);
    await expectLater(
      lease.runExclusive(() async => 1),
      throwsFormatException,
    );
    expect(await unsafe.list().toList(), isEmpty);
  });

  test('replaced sandbox directory and lock symlink are refused',
      () async {
    if (Platform.isWindows) return; // Symlink creation needs privileges.
    final lease = SandboxRestoreFileLease(directory);
    final sentinel = File(path.join(directory.parent.path,
        'simple-notes-sentinel-${path.basename(directory.path)}.txt'));
    addTearDown(() async {
      if (await sentinel.exists()) await sentinel.delete();
    });
    await sentinel.writeAsString('MUST NOT CHANGE', flush: true);
    await Link(lease.lockFile.path).create(sentinel.path);
    await expectLater(
      lease.runExclusive(() async => 1),
      throwsFormatException,
    );
    expect(await sentinel.readAsString(), 'MUST NOT CHANGE');
  });
}
