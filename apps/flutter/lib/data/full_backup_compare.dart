import 'dart:convert';

import 'full_backup.dart';

/// Metadata-only comparison; never exposes note bodies, task descriptions,
/// preference values, account identifiers, or mutation payloads.
class BackupEntityDifference {
  const BackupEntityDifference({
    required this.addedInBackup,
    required this.missingFromBackup,
    required this.changedInBackup,
    required this.unchanged,
    required this.deletedInBackup,
  });

  final int addedInBackup;
  final int missingFromBackup;
  final int changedInBackup;
  final int unchanged;
  final int deletedInBackup;

  bool get hasChanges =>
      addedInBackup > 0 || missingFromBackup > 0 || changedInBackup > 0;
}

class FullBackupComparison {
  const FullBackupComparison({
    required this.entities,
    required this.localPendingMutations,
    required this.importedPendingMutations,
    required this.sharedOperationIds,
    required this.preferenceChanges,
    required this.cursorRegressedOrUnknown,
    required this.currentCursor,
    required this.backupCursor,
  });

  final Map<String, BackupEntityDifference> entities;
  final int localPendingMutations;
  final int importedPendingMutations;
  final int sharedOperationIds;
  final int preferenceChanges;
  final bool cursorRegressedOrUnknown;
  final int? currentCursor;
  final int? backupCursor;

  bool get hasEntityDifferences =>
      entities.values.any((difference) => difference.hasChanges);

  bool get currentDataMissingFromBackup =>
      entities.values.any((difference) =>
          difference.missingFromBackup > 0);

  bool get needsRemoteReconciliation => true;
  bool get canRestoreLive => false;
  bool get canReplayImportedOutbox => false;
  bool get automaticSyncAuthorized => false;

  /// Safe for a read-only Forui dialog: counts only, no user content.
  String get summary {
    final output = StringBuffer();
    output.writeln('Confronto locale — nessun dato verrà modificato.');
    output.writeln();
    for (final item in const [
      ('task_entries', 'Attività'),
      ('task_list_entries', 'Liste'),
      ('note_entries', 'Note (anche cestino)'),
    ]) {
      final label = item.$2;
      final value = entities[item.$1]!;
      final added = value.addedInBackup;
      final missing = value.missingFromBackup;
      final changed = value.changedInBackup;
      final deleted = value.deletedInBackup;
      output.writeln('$label: +$added nel backup, '
          '$missing mancanti nel backup, $changed diversi.');
      output.writeln('  Record cancellati nel backup: $deleted.');
    }
    output.writeln();
    output.writeln('Operazioni locali in attesa: $localPendingMutations.');
    output.writeln('Operazioni nel backup: $importedPendingMutations.');
    output.writeln('ID operazioni comuni: $sharedOperationIds.');
    output.writeln('Preferenze diverse: $preferenceChanges.');
    final before = currentCursor?.toString() ?? 'non verificabile';
    final after = backupCursor?.toString() ?? 'non verificabile';
    output.writeln('Cursore attuale: $before.');
    output.writeln('Cursore nel backup: $after.');
    if (cursorRegressedOrUnknown) {
      output.writeln('Attenzione: cursore precedente o non verificabile.');
    }
    if (currentDataMissingFromBackup) {
      output.writeln('Attenzione: alcuni dati locali mancano dal backup.');
    }
    output.writeln();
    output.writeln('Il cloud non è stato controllato.');
    output.writeln('Ripristino e replay delle modifiche importate '
        'rimangono disabilitati.');
    return output.toString().trimRight();
  }
}

/// P2.4B2E: read-only preview of a same-owner archive. The caller must
/// authenticate the file using FullBackupCodec.inspect before passing it.
class FullBackupCompare {
  const FullBackupCompare();

  FullBackupComparison preview({
    required FullBackupSnapshot current,
    required FullBackupSnapshot backup,
  }) {
    current.validate();
    backup.validate();
    if (current.ownerId != backup.ownerId) {
      throw const FormatException('Backup associato a un altro account.');
    }
    final differences = <String, BackupEntityDifference>{};
    for (final table in const [
      'task_entries', 'task_list_entries', 'note_entries',
    ]) {
      final columns = FullBackupSnapshot.columns[table]!;
      final actual = <String, Map<String, Object?>>{
        for (final row in current.tables[table]!)
          row['id'] as String: row,
      };
      final incoming = <String, Map<String, Object?>>{
        for (final row in backup.tables[table]!)
          row['id'] as String: row,
      };
      var added = 0;
      var changed = 0;
      var unchanged = 0;
      var tombstones = 0;
      for (final entry in incoming.entries) {
        if (entry.value['deleted_at'] != null) tombstones++;
        final previous = actual[entry.key];
        if (previous == null) {
          added++;
        } else {
          final before = jsonEncode([
            for (final name in columns) previous[name],
          ]);
          final after = jsonEncode([
            for (final name in columns) entry.value[name],
          ]);
          if (before == after) {
            unchanged++;
          } else {
            changed++;
          }
        }
      }
      differences[table] = BackupEntityDifference(
        addedInBackup: added,
        missingFromBackup: actual.keys
            .where((key) => !incoming.containsKey(key)).length,
        changedInBackup: changed,
        unchanged: unchanged,
        deletedInBackup: tombstones,
      );
    }
    final localIds = current.tables['pending_mutations']!
        .map((row) => row['operation_id'] as String).toSet();
    final importedIds = backup.tables['pending_mutations']!
        .map((row) => row['operation_id'] as String).toSet();
    int? cursor(FullBackupSnapshot value) {
      final matches = value.tables['sync_settings']!
          .where((row) => row['key'] == 'syncCursor');
      if (matches.isEmpty) return null;
      final text = matches.single['value'];
      if (text is! String) return null;
      final parsed = int.tryParse(text);
      return parsed == null || parsed < 0 ? null : parsed;
    }
    final currentCursor = cursor(current);
    final backupCursor = cursor(backup);
    return FullBackupComparison(
      entities: Map.unmodifiable(differences),
      localPendingMutations: localIds.length,
      importedPendingMutations: importedIds.length,
      sharedOperationIds: localIds.intersection(importedIds).length,
      preferenceChanges: FullBackupSnapshot.preferenceNames
          .where((key) => current.preferences[key] != backup.preferences[key])
          .length,
      cursorRegressedOrUnknown: currentCursor == null ||
          backupCursor == null || backupCursor < currentCursor,
      currentCursor: currentCursor,
      backupCursor: backupCursor,
    );
  }
}
