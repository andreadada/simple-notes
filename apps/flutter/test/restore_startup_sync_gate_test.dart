import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:simple_notes/data/restore_startup_probe_io.dart';
import 'package:simple_notes/sync/cloud_sync.dart';
import 'package:simple_notes/sync/restore_sync_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sn-restore-probe-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('normal installation without restore marker remains usable', () async {
    final gate = await probeRestoreStartup(supportDirectory: root);
    expect(gate.canSync, isTrue);
    expect(gate.canRestoreLive, isFalse);
  });

  test('empty recovery directory blocks before installed SQLite is opened',
      () async {
    await Directory(path.join(root.path, 'simple-notes-recovery-v1'))
        .create();
    final gate = await probeRestoreStartup(supportDirectory: root);
    expect(gate.blocked, isTrue);
    expect(gate.canSync, isFalse);
  });

  test('corrupt marker file and path obstruction both fail closed', () async {
    final reserved = path.join(root.path, 'simple-notes-recovery-v1');
    await File(reserved).writeAsString('interrupted');
    expect((await probeRestoreStartup(supportDirectory: root)).blocked,
        isTrue);
    await File(reserved).delete();
    final folder = await Directory(reserved).create();
    await File(path.join(folder.path, 'recovery-000.json'))
        .writeAsString('{corrupt-json');
    expect((await probeRestoreStartup(supportDirectory: root)).blocked,
        isTrue);
  });

  test('manual CloudSync is blocked before credentials or database access',
      () async {
    final container = ProviderContainer(overrides: [
      restoreSyncGateProvider.overrideWithValue(
          const RestoreSyncGate.blocked()),
    ]);
    addTearDown(container.dispose);
    await container.read(cloudSyncProvider.notifier).synchronize();
    final state = container.read(cloudSyncProvider);
    expect(state.running, isFalse);
    expect(state.message, contains('bloccata'));
  });

  test('provider guard cannot authorize live restore or import replay',
      () async {
    const ready = RestoreSyncGate.ready();
    const blocked = RestoreSyncGate.blocked();
    expect(ready.canSync, isTrue);
    expect(ready.canRestoreLive, isFalse);
    expect(ready.canReplayImportedOutbox, isFalse);
    expect(blocked.canSync, isFalse);
    expect(blocked.canRestoreLive, isFalse);
    expect(blocked.canReplayImportedOutbox, isFalse);
  });
}
