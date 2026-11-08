import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:simple_notes/data/full_backup_recovery_guard.dart';
import 'package:simple_notes/data/posix_sandbox_directory_sync.dart';
import 'package:simple_notes/data/recovery_directory_barrier.dart';

class _RecordingBarrier implements RecoveryDirectoryBarrier {
  _RecordingBarrier({this.failOnCall});

  final int? failOnCall;
  final List<String> visited = <String>[];

  @override
  bool get supportedHere => true;

  @override
  Future<void> syncDirectory(Directory directory) async {
    visited.add(path.normalize(directory.path));
    if (visited.length == failOnCall) {
      throw StateError('simulated disk sync failure');
    }
  }
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('simple-notes-fsync-test-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  final a = List.filled(64, 'a').join();
  final b = List.filled(64, 'b').join();
  final c = List.filled(64, 'c').join();
  RestoreMarker initial() =>
      RestoreMarker(0, RestorePhase.prepared, a, b, c);

  test('unsupported directory fsync rejects strict append before writing',
      () async {
    final journal = Directory(path.join(root.path, 'journal'));
    final guard = FileRestoreJournal(
      journal,
      directoryBarrier: const UnavailableRecoveryDirectoryBarrier(),
    );
    await expectLater(guard.append(initial()), throwsUnsupportedError);
    expect(await journal.exists(), isFalse);
    expect(await root.list().toList(), isEmpty);
  });

  test('first strict append syncs parent directory and renamed marker',
      () async {
    final journal = Directory(path.join(root.path, 'journal'));
    final recorder = _RecordingBarrier();
    final guard = FileRestoreJournal(
      journal, directoryBarrier: recorder,
    );
    await guard.append(initial());
    expect(recorder.visited, [root.path, journal.path]);
    final saved = await guard.read();
    expect(saved!.phase, RestorePhase.prepared);

    await guard.append(saved.next(RestorePhase.staging));
    expect(recorder.visited, [root.path, journal.path, journal.path]);
    expect((await guard.read())!.phase, RestorePhase.staging);
  });

  test('parent sync failure rejects append with no recovery marker',
      () async {
    final journal = Directory(path.join(root.path, 'journal'));
    final guard = FileRestoreJournal(
      journal,
      directoryBarrier: _RecordingBarrier(failOnCall: 1),
    );
    await expectLater(guard.append(initial()), throwsStateError);
    expect(await journal.exists(), isTrue);
    expect(await journal.list().toList(), isEmpty);
    expect(await guard.read(), isNull);
  });

  test('marker sync failure never reports success or discards journal',
      () async {
    final journal = Directory(path.join(root.path, 'journal'));
    final guard = FileRestoreJournal(
      journal,
      directoryBarrier: _RecordingBarrier(failOnCall: 2),
    );
    await expectLater(guard.append(initial()), throwsStateError);
    final persisted = await guard.read();
    // The rename may have reached disk but was NOT fsync-confirmed.
    // The caller must treat the attempt as interrupted, never as success.
    expect(persisted?.phase, RestorePhase.prepared);
    expect(
      await File(path.join(journal.path, 'recovery-000.json')).exists(),
      isTrue,
    );
  });

  test('real POSIX directory fsync works only on supported sandbox OS',
      () async {
    const sync = PosixSandboxDirectorySync();
    if (!Platform.isLinux) {
      expect(sync.supportedHere, isFalse);
      await expectLater(sync.syncDirectory(root), throwsUnsupportedError);
      return;
    }
    expect(sync.supportedHere, isTrue);
    final file = File(path.join(root.path, 'marker.json'));
    await file.writeAsString('TEST-ONLY', flush: true);
    await sync.syncDirectory(root);
    expect(await file.readAsString(), 'TEST-ONLY');

    final journal = Directory(path.join(root.path, 'journal'));
    final guard = FileRestoreJournal(
      journal, directoryBarrier: sync,
    );
    await guard.append(initial());
    expect((await guard.read())?.phase, RestorePhase.prepared);
    expect(await journal.list().length, 1);
  });

  test('invalid directory refuses native fsync', () async {
    if (!Platform.isLinux) return;
    final missing = Directory(path.join(root.path, 'absent'));
    await expectLater(
      const PosixSandboxDirectorySync().syncDirectory(missing),
      throwsFormatException,
    );
  });
}
