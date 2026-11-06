import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'full_backup.dart';

/// P2.4B2S: invalidates an in-memory backup/cloud review when the installed
/// profile has changed since the initial read-only snapshot.
///
/// This is NOT a cross-store lock, a lease on the cloud or permission to
/// restore/import data. The caller must recapture SQLite and preferences
/// before accepting an asynchronous review result or displaying choices.
class BackupReviewSnapshotGuard {
  const BackupReviewSnapshotGuard();

  /// Returns false for a changed owner, any data/preferences/outbox/cursor
  /// change, or a malformed snapshot. Excludes only the capture timestamp.
  /// Never logs, persists, returns or uploads private snapshot contents.
  bool isUnchanged({
    required FullBackupSnapshot baseline,
    required FullBackupSnapshot latest,
  }) {
    try {
      baseline.validate();
      latest.validate();
      if (baseline.ownerId != latest.ownerId) return false;
      return _digest(baseline) == _digest(latest);
    } catch (_) {
      return false;
    }
  }

  String _digest(FullBackupSnapshot snapshot) {
    final data = <Object?>[
      snapshot.ownerId,
      for (final table in FullBackupSnapshot.columns.entries)
        [
          table.key,
          for (final row in ([...snapshot.tables[table.key]!]
            ..sort((a, b) =>
                _rowId(a, table.key).compareTo(_rowId(b, table.key)))))
            [for (final column in table.value) row[column]],
        ],
      for (final key in ([...FullBackupSnapshot.preferenceNames]..sort()))
        [key, snapshot.preferences[key]],
    ];
    return crypto.sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  String _rowId(Map<String, Object?> row, String table) {
    final key = switch (table) {
      'pending_mutations' => 'operation_id',
      'sync_settings' => 'key',
      _ => 'id',
    };
    return row[key] as String;
  }
}
