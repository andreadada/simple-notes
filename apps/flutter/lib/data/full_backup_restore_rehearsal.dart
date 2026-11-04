import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:drift/native.dart';

import 'app_database.dart';
import 'full_backup.dart';

/// P2.4B2A: a restore rehearsal, never a live profile restore.
///
/// The only database opened here is a new in-memory SQLite instance. No
/// production path, SharedPreferences instance, OAuth credentials or network
/// client is accepted. Restored outbox/cursor never connect to AutoSyncHost.
class FullBackupRestoreRehearsal {
  const FullBackupRestoreRehearsal();

  Future<FullBackupRehearsalReport> verify({
    required List<int> encryptedBytes,
    required String password,
    required String expectedOwnerId,
    Future<void> Function(String table)? faultAfterTable,
  }) async {
    // Authenticate before allocating the sandbox or attempting any writes.
    final archive = await const FullBackupCodec().inspect(
      encryptedBytes,
      password: password,
      expectedOwnerId: expectedOwnerId,
    );
    archive.validate();

    final sandbox = AppDatabase(NativeDatabase.memory());
    try {
      await _verifyEmptySchema(sandbox);
      try {
        // All five tables are staged as one atomic transaction. The hook is
        // solely for deterministic crash/fault-injection tests.
        await sandbox.transaction(() async {
          for (final entry in FullBackupSnapshot.columns.entries) {
            final table = entry.key;
            final names = entry.value;
            final quoted = names.map((name) => '"' + name + '"').join(', ');
            final placeholders = List.filled(names.length, '?').join(', ');
            final insert = 'INSERT INTO "' + table + '" (' +
                quoted + ') VALUES (' + placeholders + ')';
            for (final row in archive.tables[table]!) {
              await sandbox.customStatement(insert, [
                for (final column in names) row[column],
              ]);
            }
            if (faultAfterTable != null) {
              await faultAfterTable(table);
            }
          }
        });
      } catch (_) {
        // SQLite transaction rollback is checked before propagating failure.
        await _verifyEmptyTables(sandbox);
        rethrow;
      }

      // Compare raw storage, not just visible records: tombstones, versions,
      // operation IDs, pending payloads and cursor must survive unchanged.
      final restored = await sandbox.fullBackupRows(expectedOwnerId);
      if (_fingerprint(restored) != _fingerprint(archive.tables)) {
        throw StateError('Il ripristino isolato non è identico al backup.');
      }
      // Decode task, note and list rows via Drift, including due and recurrence.
      await sandbox.snapshot();

      return FullBackupRehearsalReport(
        createdAtUtc: archive.createdAtUtc,
        rowsByTable: Map.unmodifiable({
          for (final entry in archive.tables.entries)
            entry.key: entry.value.length,
        }),
        outboxCount: archive.count('pending_mutations'),
        preferenceCount: archive.preferences.values
            .where((value) => value != null).length,
      );
    } finally {
      await sandbox.close();
    }
  }

  Future<void> _verifyEmptySchema(AppDatabase sandbox) async {
    // Accessing Drift first creates the expected schema in the disposable DB.
    await sandbox.customSelect('SELECT * FROM sync_settings LIMIT 1').get();
    for (final entry in FullBackupSnapshot.columns.entries) {
      final info = await sandbox.customSelect(
        'PRAGMA table_info("' + entry.key + '")',
      ).get();
      final names = info.map((row) => row.data['name'] as String).toList();
      if (names.length != entry.value.length ||
          !names.toSet().containsAll(entry.value)) {
        throw const FormatException('Schema SQLite isolato non compatibile.');
      }
    }
    await _verifyEmptyTables(sandbox);
  }

  Future<void> _verifyEmptyTables(AppDatabase sandbox) async {
    for (final table in FullBackupSnapshot.columns.keys) {
      final count = await sandbox.customSelect(
        'SELECT COUNT(*) AS total FROM "' + table + '"',
      ).getSingle();
      if (count.read<int>('total') != 0) {
        throw StateError('Rollback del ripristino isolato non riuscito.');
      }
    }
  }

  String _fingerprint(Map<String, List<Map<String, Object?>>> data) {
    final canonical = <Object?>[];
    for (final entry in FullBackupSnapshot.columns.entries) {
      final rows = data[entry.key];
      if (rows == null) throw StateError('Tabella backup mancante.');
      final key = entry.key == 'pending_mutations' ? 'operation_id' :
          entry.key == 'sync_settings' ? 'key' : 'id';
      final sorted = [...rows]..sort(
          (a, b) => (a[key] as String).compareTo(b[key] as String));
      canonical.add([
        entry.key,
        for (final row in sorted)
          [for (final column in entry.value) row[column]],
      ]);
    }
    return hash.sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }
}

class FullBackupRehearsalReport {
  const FullBackupRehearsalReport({
    required this.createdAtUtc,
    required this.rowsByTable,
    required this.outboxCount,
    required this.preferenceCount,
  });

  final DateTime createdAtUtc;
  final Map<String, int> rowsByTable;
  final int outboxCount;
  final int preferenceCount;

  /// A rehearsal never authorizes restoring a real profile or resuming sync:
  /// remote cloud state and stale operation IDs have not been reconciled.
  bool get automaticSyncAuthorized => false;
}
