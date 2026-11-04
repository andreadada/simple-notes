import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'full_backup.dart';
import 'restore_cloud_inventory.dart';

/// A choice for an explanation only. No strategy authorizes a real write.
enum ReconciliationStrategy {
  deferAll,
  keepDevice,
  preferBackup,
  preferCloud,
}

enum ReconciliationHazard {
  cloudNotObserved,
  missingFromBackup,
  missingOnDevice,
  cloudOnly,
  deviceBackupDifferent,
  backupDeletedMismatch,
  deviceDeletedMismatch,
  backupVersionUnknown,
  deviceVersionUnknown,
  cloudNewerThanBackup,
  cloudOlderThanBackup,
  cloudNewerThanDevice,
  cloudOlderThanDevice,
  importedOutbox,
  deviceOutbox,
}

/// Aggregated, content-free output. Contains no entity IDs or mutation
/// payloads; the fingerprint is private to the draft and not a signature.
class ReconciliationDryRun {
  const ReconciliationDryRun({
    required this.strategy,
    required this.sourceFingerprint,
    required this.totalEntities,
    required this.entitiesNeedingReview,
    required this.observedEntities,
    required this.hazardCounts,
    required this.importedOperationCount,
    required this.deviceOperationCount,
  });

  final ReconciliationStrategy strategy;
  final String sourceFingerprint;
  final int totalEntities;
  final int entitiesNeedingReview;
  final int observedEntities;
  final Map<ReconciliationHazard, int> hazardCounts;
  final int importedOperationCount;
  final int deviceOperationCount;

  bool get needsFreshCloudReview => true;
  bool get requiresHumanReview => true;
  bool get canRestoreLive => false;
  bool get canWriteToCloud => false;
  bool get canReplayImportedOutbox => false;
  bool get canResumeAutoSync => false;
  bool get isExecutable => false;

  String get summary {
    final out = StringBuffer();
    out.writeln('Simulazione di riconciliazione (nessuna modifica).');
    out.writeln('Entità complessive: $totalEntities.');
    out.writeln('Entità da verificare: $entitiesNeedingReview.');
    out.writeln('Entità osservate nel cloud: $observedEntities.');
    out.writeln('Operazioni in attesa sul dispositivo: '
        '$deviceOperationCount.');
    out.writeln('Operazioni importate in attesa: '
        '$importedOperationCount.');
    const captions = <ReconciliationHazard, String>{
      ReconciliationHazard.cloudNotObserved: 'Non osservate nel registro cloud',
      ReconciliationHazard.missingFromBackup: 'Assenti dal backup',
      ReconciliationHazard.missingOnDevice: 'Assenti sul dispositivo',
      ReconciliationHazard.cloudOnly: 'Presenti solo nel cloud',
      ReconciliationHazard.deviceBackupDifferent:
          'Record del dispositivo diversi dal backup',
      ReconciliationHazard.backupDeletedMismatch:
          'Cancellazioni backup/cloud discordanti',
      ReconciliationHazard.deviceDeletedMismatch:
          'Cancellazioni dispositivo/cloud discordanti',
      ReconciliationHazard.backupVersionUnknown:
          'Versioni backup non verificabili',
      ReconciliationHazard.deviceVersionUnknown:
          'Versioni dispositivo non verificabili',
      ReconciliationHazard.cloudNewerThanBackup:
          'Cloud più recente del backup',
      ReconciliationHazard.cloudOlderThanBackup:
          'Backup più recente del registro cloud',
      ReconciliationHazard.cloudNewerThanDevice:
          'Cloud più recente del dispositivo',
      ReconciliationHazard.cloudOlderThanDevice:
          'Dispositivo più recente del registro cloud',
      ReconciliationHazard.importedOutbox:
          'Record con modifiche del backup in coda',
      ReconciliationHazard.deviceOutbox:
          'Record con modifiche locali in coda',
    };
    for (final hazard in ReconciliationHazard.values) {
      final count = hazardCounts[hazard] ?? 0;
      if (count > 0) {
        final caption = captions[hazard]!;
        out.writeln('$caption: $count.');
      }
    }
    final preferenceLabel = switch (strategy) {
      ReconciliationStrategy.deferAll => 'Rinvia ogni decisione',
      ReconciliationStrategy.keepDevice =>
        'Proporre di preservare i dati locali',
      ReconciliationStrategy.preferBackup =>
        'Proporre di preservare il backup',
      ReconciliationStrategy.preferCloud =>
        'Proporre di preservare il cloud',
    };
    out.writeln();
    out.writeln('Preferenza ipotetica: $preferenceLabel.');
    out.writeln('Nessuna scelta è stata applicata o autorizzata.');
    out.writeln('Un inventario remoto non blocca modifiche concorrenti.');
    out.writeln('Ripristino, upload e replay restano disabilitati.');
    return out.toString().trimRight();
  }
}

class ReconciliationDryRunPlanner {
  const ReconciliationDryRunPlanner();

  /// All inputs are read-only. The current and imported snapshots must
  /// previously pass authenticated same-owner archive verification.
  ReconciliationDryRun preview({
    required FullBackupSnapshot current,
    required FullBackupSnapshot imported,
    required RestoreServerInventory cloud,
    ReconciliationStrategy strategy = ReconciliationStrategy.deferAll,
  }) {
    current.validate();
    imported.validate();
    if (current.ownerId != imported.ownerId) {
      throw const FormatException('Il backup appartiene a un altro account.');
    }
    if (cloud.cursor < 0 || cloud.revisions.length > 10000) {
      throw const FormatException('Inventario remoto non coerente.');
    }
    for (final item in cloud.revisions.entries) {
      if (!_validKey(item.key) || item.value.version < 0 ||
          item.value.changeId <= 0 ||
          item.value.changeId > cloud.cursor) {
        throw const FormatException('Revisione remota non valida.');
      }
    }

    final onDevice = _entities(current);
    final fromBackup = _entities(imported);
    final localQueue = _outbox(current);
    final importQueue = _outbox(imported);
    final keys = <String>{
      ...onDevice.keys, ...fromBackup.keys,
      ...cloud.revisions.keys, ...localQueue, ...importQueue,
    }.toList()..sort();

    final counts = {
      for (final reason in ReconciliationHazard.values) reason: 0,
    };
    var reviewed = 0;
    var observed = 0;
    for (final key in keys) {
      final reasons = <ReconciliationHazard>{};
      final local = onDevice[key];
      final backup = fromBackup[key];
      final remote = cloud.revisions[key];
      if (remote == null) {
        reasons.add(ReconciliationHazard.cloudNotObserved);
      } else {
        observed++;
      }
      if (backup == null) {
        reasons.add(ReconciliationHazard.missingFromBackup);
      }
      if (local == null) {
        reasons.add(ReconciliationHazard.missingOnDevice);
      }
      if (remote != null && backup == null && local == null) {
        reasons.add(ReconciliationHazard.cloudOnly);
      }
      if (local != null && backup != null &&
          !_sameRecord(local, backup)) {
        reasons.add(ReconciliationHazard.deviceBackupDifferent);
      }
      if (backup != null && remote != null) {
        if ((backup.row['deleted_at'] != null) != remote.deleted) {
          reasons.add(ReconciliationHazard.backupDeletedMismatch);
        }
        _compareVersion(backup.row['remote_version'], remote.version,
            reasons, imported: true);
      }
      if (local != null && remote != null) {
        if ((local.row['deleted_at'] != null) != remote.deleted) {
          reasons.add(ReconciliationHazard.deviceDeletedMismatch);
        }
        _compareVersion(local.row['remote_version'], remote.version,
            reasons, imported: false);
      }
      if (importQueue.contains(key)) {
        reasons.add(ReconciliationHazard.importedOutbox);
      }
      if (localQueue.contains(key)) {
        reasons.add(ReconciliationHazard.deviceOutbox);
      }
      if (reasons.isNotEmpty) {
        reviewed++;
      }
      for (final reason in reasons) {
        counts[reason] = counts[reason]! + 1;
      }
    }

    // Local invalidation checksum: never transmitted, never an authorization.
    final orderedRemote = cloud.revisions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final fingerprint = crypto.sha256.convert(utf8.encode(jsonEncode({
      'device': current.toJson(),
      'backup': imported.toJson(),
      'remoteCursor': cloud.cursor,
      'remote': [
        for (final row in orderedRemote)
          [row.key, row.value.version,
            row.value.deleted, row.value.changeId],
      ],
    }))).toString();

    return ReconciliationDryRun(
      strategy: strategy,
      sourceFingerprint: fingerprint,
      totalEntities: keys.length,
      entitiesNeedingReview: reviewed,
      observedEntities: observed,
      hazardCounts: Map.unmodifiable(counts),
      importedOperationCount: imported.count('pending_mutations'),
      deviceOperationCount: current.count('pending_mutations'),
    );
  }

  static bool _validKey(String key) {
    final separator = key.indexOf(':');
    if (separator < 1 || separator == key.length - 1 ||
        key.length > 1152) {
      return false;
    }
    return const {'note', 'task', 'list'}
        .contains(key.substring(0, separator));
  }

  static Map<String, _EntityRecord> _entities(FullBackupSnapshot snapshot) {
    final result = <String, _EntityRecord>{};
    for (final type in const [
      ('task_entries', 'task'),
      ('task_list_entries', 'list'),
      ('note_entries', 'note'),
    ]) {
      final columns = FullBackupSnapshot.columns[type.$1]!;
      final name = type.$2;
      for (final row in snapshot.tables[type.$1]!) {
        final id = row['id'] as String;
        result['$name:$id'] = _EntityRecord(row, columns);
      }
    }
    return result;
  }

  static Set<String> _outbox(FullBackupSnapshot snapshot) {
    final result = <String>{};
    for (final row in snapshot.tables['pending_mutations']!) {
      final type = row['entity_type'] as String;
      final id = row['entity_id'] as String;
      result.add('$type:$id');
    }
    return result;
  }

  static bool _sameRecord(_EntityRecord one, _EntityRecord two) {
    return jsonEncode([for (final col in one.columns) one.row[col]]) ==
        jsonEncode([for (final col in two.columns) two.row[col]]);
  }

  static void _compareVersion(
      Object? value, int remote, Set<ReconciliationHazard> hazards,
      {required bool imported}) {
    if (value is! int || value < 0) {
      hazards.add(imported
          ? ReconciliationHazard.backupVersionUnknown
          : ReconciliationHazard.deviceVersionUnknown);
    } else if (remote > value) {
      hazards.add(imported
          ? ReconciliationHazard.cloudNewerThanBackup
          : ReconciliationHazard.cloudNewerThanDevice);
    } else if (remote < value) {
      hazards.add(imported
          ? ReconciliationHazard.cloudOlderThanBackup
          : ReconciliationHazard.cloudOlderThanDevice);
    }
  }
}

class _EntityRecord {
  const _EntityRecord(this.row, this.columns);
  final Map<String, Object?> row;
  final List<String> columns;
}
