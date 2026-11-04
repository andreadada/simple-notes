import 'full_backup.dart';
import 'full_backup_compare.dart';
import 'restore_cloud_inventory.dart';

/// Three-way, metadata-only review: current device / authenticated .snb /
/// owner-scoped read-only server inventory. This cannot authorize a restore.
/// A server ledger snapshot is not a write lock and may omit entities that
/// have never emitted sync events.
class BackupCloudSafetyReport {
  const BackupCloudSafetyReport({
    required this.local,
    required this.remoteCursor,
    required this.entitiesInBackup,
    required this.entitiesNotObservedRemotely,
    required this.remoteVersionsNewerThanBackup,
    required this.remoteVersionsUnverifiable,
    required this.remoteDeletionMismatches,
    required this.remoteOnlyEntities,
    required this.outboxVersionConflicts,
    required this.unobservedOutboxOperations,
    required this.cloudCursorAheadOfBackup,
  });

  final FullBackupComparison local;
  final int remoteCursor;
  final int entitiesInBackup;
  final int entitiesNotObservedRemotely;
  final int remoteVersionsNewerThanBackup;
  final int remoteVersionsUnverifiable;
  final int remoteDeletionMismatches;
  final int remoteOnlyEntities;
  final int outboxVersionConflicts;
  final int unobservedOutboxOperations;
  final bool cloudCursorAheadOfBackup;

  bool get canRestoreLive => false;
  bool get canApplyImportedOperations => false;
  bool get canTrustImportedCursor => false;
  bool get canResumeAutoSync => false;
  bool get requiresManualReconciliation => true;

  /// No IDs, titles, note content, passwords, token, payload or preferences.
  String get summary {
    final out = StringBuffer();
    out.writeln('Inventario cloud consultato in sola lettura.');
    out.writeln('Cursore cloud osservato: $remoteCursor.');
    out.writeln('Elementi presenti nel backup: $entitiesInBackup.');
    out.writeln('Elementi non osservati nell’inventario: '
        '$entitiesNotObservedRemotely.');
    out.writeln('Revisioni cloud successive al backup: '
        '$remoteVersionsNewerThanBackup.');
    out.writeln('Revisioni non confrontabili nel backup: '
        '$remoteVersionsUnverifiable.');
    out.writeln('Differenze nelle cancellazioni: '
        '$remoteDeletionMismatches.');
    out.writeln('Elementi del cloud non presenti nel backup: '
        '$remoteOnlyEntities.');
    out.writeln('Modifiche importate con versione potenzialmente '
        'in conflitto: $outboxVersionConflicts.');
    out.writeln('Modifiche importate non osservate nel cloud: '
        '$unobservedOutboxOperations.');
    if (cloudCursorAheadOfBackup) {
      out.writeln('Il cloud contiene cambiamenti successivi '
          'al cursore salvato nel backup.');
    }
    out.writeln();
    out.writeln('Il confronto non blocca nuove modifiche sul server.');
    out.writeln('Lo storico sync può essere incompleto: assenza '
        'di un elemento non significa che sia sicuro importarlo.');
    out.writeln('Ripristino e replay restano disabilitati.');
    return out.toString().trimRight();
  }
}

class BackupCloudSafetyReviewer {
  const BackupCloudSafetyReviewer();

  BackupCloudSafetyReport inspect({
    required FullBackupSnapshot current,
    required FullBackupSnapshot backup,
    required RestoreServerInventory remote,
  }) {
    if (remote.cursor < 0 || remote.revisions.length > 10000) {
      throw const FormatException('Inventario cloud non valido.');
    }
    for (final entry in remote.revisions.entries) {
      final item = entry.value;
      if (entry.key.isEmpty || item.version < 0 ||
          item.changeId <= 0 || item.changeId > remote.cursor) {
        throw const FormatException('Revisione cloud non valida.');
      }
    }
    final local = const FullBackupCompare().preview(
      current: current, backup: backup,
    );
    final outboxReview = RestoreServerInventoryReview.compare(
      checkpoint: current, target: backup, remote: remote,
    );

    var total = 0;
    var unobserved = 0;
    var newer = 0;
    var unverifiable = 0;
    var deletionMismatch = 0;
    final knownBackupKeys = <String>{};
    for (final item in const [
      ('task_entries', 'task'),
      ('task_list_entries', 'list'),
      ('note_entries', 'note'),
    ]) {
      final type = item.$2;
      for (final row in backup.tables[item.$1]!) {
        total++;
        final id = row['id'] as String;
        final key = '$type:$id';
        knownBackupKeys.add(key);
        final seen = remote.revisions[key];
        if (seen == null) {
          unobserved++;
          continue;
        }
        final version = row['remote_version'];
        if (version is! int) {
          unverifiable++;
        } else if (seen.version > version) {
          newer++;
        }
        final deleted = row['deleted_at'] != null;
        if (seen.deleted != deleted) {
          deletionMismatch++;
        }
      }
    }

    return BackupCloudSafetyReport(
      local: local,
      remoteCursor: remote.cursor,
      entitiesInBackup: total,
      entitiesNotObservedRemotely: unobserved,
      remoteVersionsNewerThanBackup: newer,
      remoteVersionsUnverifiable: unverifiable,
      remoteDeletionMismatches: deletionMismatch,
      remoteOnlyEntities: remote.revisions.keys
          .where((key) => !knownBackupKeys.contains(key)).length,
      outboxVersionConflicts: outboxReview.versionConflicts,
      unobservedOutboxOperations: outboxReview.unobservedOperations,
      cloudCursorAheadOfBackup: local.backupCursor == null ||
          remote.cursor > local.backupCursor!,
    );
  }
}
