import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:drift/native.dart';

import 'app_database.dart';
import 'full_backup.dart';

/// An intentionally injected interruption in the disposable rehearsal only.
class FullBackupSandboxInterruption implements Exception {
  const FullBackupSandboxInterruption(this.stage);
  final String stage;
}

/// P2.4B2B2: verify a cross-store rollback without opening a real profile.
///
/// Both encrypted .snb files are authenticated for the same owner before
/// creating a fresh SQLite memory database. Preferences are a private Map,
/// never SharedPreferences. Nothing is connected to OAuth, sync or filesystem.
class FullBackupRollbackRehearsal {
  const FullBackupRollbackRehearsal();

  Future<FullBackupRollbackReport> verify({
    required List<int> currentCheckpointBytes,
    required String currentCheckpointPassword,
    required List<int> targetBackupBytes,
    required String targetBackupPassword,
    required String expectedOwnerId,
    Future<void> Function(String stage)? injectFault,
  }) async {
    final codec = const FullBackupCodec();
    final current = await codec.inspect(
      currentCheckpointBytes,
      password: currentCheckpointPassword,
      expectedOwnerId: expectedOwnerId,
    );
    final target = await codec.inspect(
      targetBackupBytes,
      password: targetBackupPassword,
      expectedOwnerId: expectedOwnerId,
    );
    final database = AppDatabase(NativeDatabase.memory());
    final stagedPreferences = Map<String, String?>.from(current.preferences);

    try {
      // The sandbox begins with an exact reconstruction of the checkpoint.
      // Its contents simulate the profile we would need to preserve.
      await database.customSelect('SELECT * FROM sync_settings LIMIT 1').get();
      await database.transaction(() => _replaceRows(database, current));
      await _verify(database, stagedPreferences, current);

      String? interruptedAt;
      try {
        // One SQLite transaction spans all five tables. The separate
        // preference map deliberately models a non-transactional store.
        await database.transaction(() async {
          await _replaceRows(database, target, injectFault: injectFault);
          for (final name in FullBackupSnapshot.preferenceNames) {
            stagedPreferences[name] = target.preferences[name];
            if (injectFault != null) {
              await injectFault('preferences:$name');
            }
          }
        });
        if (injectFault != null) await injectFault('after-commit');
        await _verify(database, stagedPreferences, target);
      } on FullBackupSandboxInterruption catch (error) {
        interruptedAt = error.stage;
      } catch (_) {
        // Roll back before propagating unexpected SQLite/validation errors.
        await _rollback(database, stagedPreferences, current);
        await _verify(database, stagedPreferences, current);
        rethrow;
      }

      // Even a successful rehearsal always returns to the checkpoint.
      // This is a dry run: target rows are never retained or synced.
      await _rollback(database, stagedPreferences, current);
      await _verify(database, stagedPreferences, current);
      return FullBackupRollbackReport(
        interruptedAt: interruptedAt,
        currentRows: Map.unmodifiable({
          for (final entry in current.tables.entries)
            entry.key: entry.value.length,
        }),
        targetRows: Map.unmodifiable({
          for (final entry in target.tables.entries)
            entry.key: entry.value.length,
        }),
        currentPreferenceCount: current.preferences.values
            .where((value) => value != null).length,
        targetPreferenceCount: target.preferences.values
            .where((value) => value != null).length,
      );
    } finally {
      await database.close();
    }
  }

  Future<void> _replaceRows(
    AppDatabase database,
    FullBackupSnapshot snapshot, {
    Future<void> Function(String stage)? injectFault,
  }) async {
    // No user-supplied identifiers: every identifier is from the immutable
    // FullBackupSnapshot allowlist. This is called inside a transaction.
    for (final table in FullBackupSnapshot.columns.keys.toList().reversed) {
      await database.customStatement('DELETE FROM "$table"');
    }
    for (final entry in FullBackupSnapshot.columns.entries) {
      final table = entry.key;
      final names = entry.value;
      final quoted = names.map((name) => '"$name"').join(', ');
      final placeholders = List.filled(names.length, '?').join(', ');
      final sql = 'INSERT INTO "$table" ($quoted) VALUES ($placeholders)';
      for (final row in snapshot.tables[table]!) {
        await database.customStatement(sql, [
          for (final name in names) row[name],
        ]);
      }
      if (injectFault != null) {
        await injectFault('sqlite:$table');
      }
    }
  }

  Future<void> _rollback(
    AppDatabase database,
    Map<String, String?> stagedPreferences,
    FullBackupSnapshot checkpoint,
  ) async {
    await database.transaction(() => _replaceRows(database, checkpoint));
    stagedPreferences
      ..clear()
      ..addAll(checkpoint.preferences);
  }

  Future<void> _verify(
    AppDatabase database,
    Map<String, String?> stagedPreferences,
    FullBackupSnapshot expected,
  ) async {
    final tables = await database.fullBackupRows(expected.ownerId);
    if (_checksum(tables, stagedPreferences) !=
        _checksum(expected.tables, expected.preferences)) {
      throw StateError('Rollback isolato: dati non corrispondenti.');
    }
    // Decode user-visible task, list and note rows as well as raw metadata.
    await database.snapshot();
  }

  String _checksum(
    Map<String, List<Map<String, Object?>>> tables,
    Map<String, String?> preferences,
  ) {
    final canonical = <Object?>[];
    for (final entry in FullBackupSnapshot.columns.entries) {
      final rows = tables[entry.key];
      if (rows == null) throw StateError('Tabella SQLite mancante.');
      final id = entry.key == 'pending_mutations'
          ? 'operation_id'
          : entry.key == 'sync_settings' ? 'key' : 'id';
      final sorted = [...rows]
        ..sort((a, b) => (a[id] as String).compareTo(b[id] as String));
      canonical.add([
        entry.key,
        for (final row in sorted)
          [for (final column in entry.value) row[column]],
      ]);
    }
    canonical.add([
      for (final name in FullBackupSnapshot.preferenceNames)
        [name, preferences[name]],
    ]);
    return hash.sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }
}

class FullBackupRollbackReport {
  const FullBackupRollbackReport({
    required this.interruptedAt,
    required this.currentRows,
    required this.targetRows,
    required this.currentPreferenceCount,
    required this.targetPreferenceCount,
  });

  /// Null means candidate staging was tested, followed by forced rollback.
  final String? interruptedAt;
  final Map<String, int> currentRows;
  final Map<String, int> targetRows;
  final int currentPreferenceCount;
  final int targetPreferenceCount;

  /// The original sandbox contents were compared after rollback.
  bool get rollbackVerified => true;

  /// No rehearsal is evidence that a persistent, crash-safe restore works.
  bool get liveRestoreAuthorized => false;
  bool get automaticSyncAuthorized => false;
}
