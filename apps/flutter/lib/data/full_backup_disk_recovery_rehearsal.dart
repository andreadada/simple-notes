import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

import 'app_database.dart';
import 'full_backup.dart';
import 'full_backup_recovery_guard.dart';

/// P2.4B2D: a *test-only* persistent cross-store recovery rehearsal.
/// All files live in a freshly-created OS temporary directory. No API to
/// choose a production profile path; no OAuth, sync, or installed preferences.
class DiskRestoreRehearsal {
  DiskRestoreRehearsal._(this.directory);

  final Directory directory;

  static Future<DiskRestoreRehearsal> create() async =>
      DiskRestoreRehearsal._(await Directory.systemTemp
          .createTemp('simple-notes-restore-rehearsal-'));

  DiskRestoreRehearsal coldStart() => DiskRestoreRehearsal._(directory);

  File get _checkpoint => File(path.join(directory.path, 'checkpoint.snb'));
  File get _target => File(path.join(directory.path, 'target.snb'));
  File get _sqlite => File(path.join(directory.path, 'sandbox.sqlite'));
  File get _prefs => File(path.join(directory.path, 'preferences.json'));
  File get _lock => File(path.join(directory.path, 'exclusive.lock'));
  FileRestoreJournal get _journal => FileRestoreJournal(
      Directory(path.join(directory.path, 'journal')));

  static String _sha(List<int> data) => hash.sha256.convert(data).toString();

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final handle = await _lock.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      try {
        return await work();
      } finally {
        await handle.unlock();
      }
    } finally {
      await handle.close();
    }
  }

  Future<void> _writeNew(File file, List<int> bytes) async {
    await file.create(exclusive: true);
    await file.writeAsBytes(bytes, flush: true);
    if (_sha(await file.readAsBytes()) != _sha(bytes)) {
      throw const FormatException('File di prova non integro.');
    }
  }

  Future<void> _replacePrefs(Map<String, String?> values) async {
    // A unique name ensures an orphan temporary file from abrupt process
    // death cannot block the next compensation attempt. Never overwrite it.
    final nonce = Random.secure().nextInt(1 << 32);
    final staged = File(path.join(
        directory.path, 'prefs-stage-$nonce.tmp'));
    await staged.create(exclusive: true);
    try {
      await staged.writeAsString(jsonEncode(values), flush: true);
      await staged.rename(_prefs.path);
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }

  Future<Map<String, String?>> _readPrefs() async {
    if (!await _prefs.exists() || await _prefs.length() > 16 * 1024 * 1024) {
      throw const FormatException('Preferenze di prova assenti.');
    }
    final parsed = jsonDecode(await _prefs.readAsString());
    if (parsed is! Map<String, dynamic> ||
        parsed.length != FullBackupSnapshot.preferenceNames.length ||
        !parsed.keys.toSet().containsAll(FullBackupSnapshot.preferenceNames)) {
      throw const FormatException('Preferenze di prova incompatibili.');
    }
    final values = <String, String?>{};
    for (final name in FullBackupSnapshot.preferenceNames) {
      final value = parsed[name];
      if (value != null && value is! String) {
        throw const FormatException('Preferenza di prova non valida.');
      }
      values[name] = value as String?;
    }
    return values;
  }

  Future<T> _database<T>(Future<T> Function(AppDatabase) action) async {
    final db = AppDatabase(NativeDatabase(_sqlite));
    try {
      await db.customSelect('SELECT * FROM sync_settings LIMIT 1').get();
      return await action(db);
    } finally {
      await db.close();
    }
  }

  Future<void> _writeRows(AppDatabase db, FullBackupSnapshot backup) async {
    await db.transaction(() async {
      for (final table in FullBackupSnapshot.columns.keys.toList().reversed) {
        await db.customStatement('DELETE FROM "$table"');
      }
      for (final entry in FullBackupSnapshot.columns.entries) {
        final table = entry.key;
        final names = entry.value;
        final quoted = names.map((name) => '"$name"').join(', ');
        final placeholders = List.filled(names.length, '?').join(', ');
        final sql = 'INSERT INTO "$table" ($quoted) VALUES ($placeholders)';
        for (final row in backup.tables[table]!) {
          await db.customStatement(sql, [
            for (final name in names) row[name],
          ]);
        }
      }
    });
  }

  String _fingerprint(Map<String, List<Map<String, Object?>>> tables) {
    final canonical = <Object?>[];
    for (final entry in FullBackupSnapshot.columns.entries) {
      final id = entry.key == 'pending_mutations'
          ? 'operation_id'
          : entry.key == 'sync_settings' ? 'key' : 'id';
      final records = [...tables[entry.key]!]
        ..sort((a, b) => (a[id] as String).compareTo(b[id] as String));
      canonical.add([
        entry.key,
        for (final record in records)
          [for (final column in entry.value) record[column]],
      ]);
    }
    return _sha(utf8.encode(jsonEncode(canonical)));
  }

  Future<void> _verify(FullBackupSnapshot expected) async {
    final rows = await _database((db) async {
      final all = await db.fullBackupRows(expected.ownerId);
      await db.snapshot();
      return all;
    });
    if (_fingerprint(rows) != _fingerprint(expected.tables)) {
      throw StateError('Rollback SQLite su disco non identico.');
    }
    final prefs = await _readPrefs();
    for (final name in FullBackupSnapshot.preferenceNames) {
      if (prefs[name] != expected.preferences[name]) {
        throw StateError('Rollback preferenze su disco non identico.');
      }
    }
  }

  Future<void> prepare({
    required List<int> checkpointBytes,
    required String checkpointPassword,
    required List<int> targetBytes,
    required String targetPassword,
    required String expectedOwnerId,
  }) async {
    if ((await directory.list().toList()).isNotEmpty) {
      throw StateError('Directory di prova non vuota.');
    }
    final codec = const FullBackupCodec();
    final current = await codec.inspect(checkpointBytes,
        password: checkpointPassword, expectedOwnerId: expectedOwnerId);
    await codec.inspect(targetBytes,
        password: targetPassword, expectedOwnerId: expectedOwnerId);
    await _exclusive(() async {
      await _writeNew(_checkpoint, checkpointBytes);
      await _writeNew(_target, targetBytes);
      await _database((db) => _writeRows(db, current));
      await _replacePrefs(current.preferences);
      await _verify(current);
      await FullBackupColdStartGuard(_journal).prepare(
        checkpointBytes: await _checkpoint.readAsBytes(),
        checkpointPassword: checkpointPassword,
        targetBytes: await _target.readAsBytes(),
        targetPassword: targetPassword,
        expectedOwnerId: expectedOwnerId,
      );
    });
  }

  /// Does not catch simulated crashes; a later fresh instance must recover.
  Future<void> applyTargetForTest({
    required String expectedOwnerId,
    required String targetPassword,
    Future<void> Function(String stage)? injectCrash,
  }) => _exclusive(() async {
    final marker = await _journal.read();
    if (marker?.phase != RestorePhase.prepared) {
      throw StateError('Operazione di staging non consentita.');
    }
    final bytes = await _target.readAsBytes();
    if (_sha(bytes) != marker!.targetHash) {
      throw const FormatException('Backup importato modificato.');
    }
    final target = await const FullBackupCodec().inspect(bytes,
        password: targetPassword, expectedOwnerId: expectedOwnerId);
    await _journal.append(marker.next(RestorePhase.staging));
    await _database((db) => _writeRows(db, target));
    if (injectCrash != null) await injectCrash('after-sqlite-commit');
    await _replacePrefs(target.preferences);
    if (injectCrash != null) await injectCrash('after-preferences-replace');
    final current = (await _journal.read())!;
    await _journal.append(current.next(RestorePhase.verifying));
    if (injectCrash != null) await injectCrash('after-verifying-marker');
    await _verify(target);
  });

  Future<DiskRestoreReceipt> recover({
    required String expectedOwnerId,
    required String checkpointPassword,
    required String targetPassword,
    Future<void> Function(String stage)? injectCrash,
  }) => _exclusive(() async {
    var marker = await _journal.read();
    if (marker == null) {
      throw const FormatException('Registro di prova mancante.');
    }
    final checkpointBytes = await _checkpoint.readAsBytes();
    final targetBytes = await _target.readAsBytes();
    if (marker.ownerHash !=
            _sha(utf8.encode('simple-notes-recovery/v1:$expectedOwnerId')) ||
        marker.checkpointHash != _sha(checkpointBytes) ||
        marker.targetHash != _sha(targetBytes)) {
      throw const FormatException('Archivio/account recovery incoerente.');
    }
    final codec = const FullBackupCodec();
    final current = await codec.inspect(checkpointBytes,
        password: checkpointPassword, expectedOwnerId: expectedOwnerId);
    await codec.inspect(targetBytes,
        password: targetPassword, expectedOwnerId: expectedOwnerId);
    if (marker.phase != RestorePhase.rollbackVerified) {
      if (marker.phase != RestorePhase.recoveryRequired) {
        await _journal.append(marker.next(RestorePhase.recoveryRequired));
        marker = (await _journal.read())!;
        if (injectCrash != null) await injectCrash('recovery-marked');
      }
      await _database((db) => _writeRows(db, current));
      if (injectCrash != null) await injectCrash('after-sqlite-rollback');
      await _replacePrefs(current.preferences);
      if (injectCrash != null) await injectCrash('after-preferences-rollback');
      await _verify(current);
      await _journal.append(marker.next(RestorePhase.rollbackVerified));
    }
    await _verify(current);
    return DiskRestoreReceipt(Map.unmodifiable({
      for (final table in current.tables.entries) table.key: table.value.length,
    }));
  });

  Future<void> disposeForTest() async {
    if (!path.basename(directory.path).startsWith(
        'simple-notes-restore-rehearsal-')) {
      throw StateError('Solo directory temporanee generate dai test.');
    }
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class DiskRestoreReceipt {
  const DiskRestoreReceipt(this.rows);

  final Map<String, int> rows;

  bool get rollbackVerifiedOnDisk => true;
  bool get liveRestoreAuthorized => false;
  bool get automaticSyncAuthorized => false;
  bool get importedOutboxQuarantined => true;
}
