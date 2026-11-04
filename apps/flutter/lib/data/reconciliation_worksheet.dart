import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'full_backup.dart';
import 'reconciliation_dry_run.dart';
import 'restore_cloud_inventory.dart';

/// Each option is a presentation preference, NOT permission to modify data.
enum DraftConflictChoice {
  undecided,
  preserveDevice,
  preserveBackup,
  preserveCloud,
}

class DraftConflictItem {
  const DraftConflictItem({
    required this.opaqueKey,
    required this.kind,
    required this.title,
    required this.warnings,
    required this.onDevice,
    required this.inBackup,
    required this.observedInCloud,
    required this.choice,
  });

  final String opaqueKey;
  final String kind;
  final String title;
  final List<String> warnings;
  final bool onDevice;
  final bool inBackup;
  final bool observedInCloud;
  final DraftConflictChoice choice;

  List<DraftConflictChoice> get availableChoices => [
    DraftConflictChoice.undecided,
    if (onDevice) DraftConflictChoice.preserveDevice,
    if (inBackup) DraftConflictChoice.preserveBackup,
    if (observedInCloud) DraftConflictChoice.preserveCloud,
  ];

  String get choiceLabel => switch (choice) {
    DraftConflictChoice.undecided => 'Da decidere',
    DraftConflictChoice.preserveDevice => 'Preferisci dispositivo (bozza)',
    DraftConflictChoice.preserveBackup => 'Preferisci backup (bozza)',
    DraftConflictChoice.preserveCloud => 'Preferisci cloud (bozza)',
  };

  DraftConflictItem withChoice(DraftConflictChoice newValue) =>
      DraftConflictItem(
        opaqueKey: opaqueKey, kind: kind, title: title,
        warnings: warnings,
        onDevice: onDevice, inBackup: inBackup,
        observedInCloud: observedInCloud, choice: newValue,
      );
}

/// The per-item title is displayed ONLY in the authenticated local dialog.
/// The aggregate summary contains no title, ID, payload or token.
class ReconciliationWorksheet {
  const ReconciliationWorksheet._(this.sourceFingerprint, this.items);

  final String sourceFingerprint;
  final List<DraftConflictItem> items;

  int get pendingCount =>
      items.where((item) => item.choice == DraftConflictChoice.undecided)
          .length;

  String get summary {
    final total = items.length;
    final chosen = total - pendingCount;
    final pending = pendingCount;
    return 'Bozza locale: $total elementi, $chosen ipotesi selezionate, '
        '$pending ancora da esaminare. Nessuna scelta viene salvata, '
        'nessun ripristino viene autorizzato.';
  }

  bool get canRestoreLive => false;
  bool get canWriteCloud => false;
  bool get canReplayImportedOutbox => false;
  bool get canResumeAutoSync => false;
  bool get isExecutable => false;

  ReconciliationWorksheet choose(String key, DraftConflictChoice option) {
    final index = items.indexWhere((item) => item.opaqueKey == key);
    if (index < 0) {
      throw const FormatException('Elemento di revisione sconosciuto.');
    }
    final item = items[index];
    if (!item.availableChoices.contains(option)) {
      throw const FormatException('Origine dati non disponibile.');
    }
    final next = [...items];
    next[index] = item.withChoice(option);
    return ReconciliationWorksheet._(
      sourceFingerprint, List.unmodifiable(next),
    );
  }

  bool isBoundTo({
    required FullBackupSnapshot current,
    required FullBackupSnapshot imported,
    required RestoreServerInventory cloud,
  }) {
    try {
      final draft = const ReconciliationDryRunPlanner().preview(
        current: current, imported: imported, cloud: cloud,
      );
      return draft.sourceFingerprint == sourceFingerprint;
    } catch (_) {
      return false;
    }
  }
}

/// Read-only, in-memory worksheet. Never opens the DB or calls the API.
/// >500 entities fail closed rather than returning a silently partial review.
class ReconciliationWorksheetBuilder {
  const ReconciliationWorksheetBuilder();

  ReconciliationWorksheet preview({
    required FullBackupSnapshot current,
    required FullBackupSnapshot imported,
    required RestoreServerInventory cloud,
  }) {
    final draft = const ReconciliationDryRunPlanner().preview(
      current: current, imported: imported, cloud: cloud,
    );
    final deviceRows = _entities(current);
    final backupRows = _entities(imported);
    final localQueue = _pending(current);
    final importedQueue = _pending(imported);
    final keys = <String>{
      ...deviceRows.keys, ...backupRows.keys,
      ...cloud.revisions.keys, ...localQueue, ...importedQueue,
    }.toList()..sort();
    if (keys.length > 500) {
      throw const FormatException('Revisione troppo grande per questa UI.');
    }

    final rows = <DraftConflictItem>[];
    for (final key in keys) {
      final device = deviceRows[key];
      final backup = backupRows[key];
      final remote = cloud.revisions[key];
      final reasons = <String>[];
      if (device == null) {
        reasons.add('Non presente sul dispositivo');
      }
      if (backup == null) {
        reasons.add('Non presente nel backup');
      }
      if (remote == null) {
        reasons.add('Non osservato nel registro cloud');
      }
      if (localQueue.contains(key)) {
        reasons.add('Modifica locale in attesa');
      }
      if (importedQueue.contains(key)) {
        reasons.add('Modifica del backup in attesa');
      }
      if (device != null && backup != null) {
        final before = jsonEncode([
          for (final col in device.columns) device.row[col],
        ]);
        final after = jsonEncode([
          for (final col in backup.columns) backup.row[col],
        ]);
        if (before != after) {
          reasons.add('Contenuti dispositivo e backup diversi');
        }
      }
      if (remote != null && device != null) {
        if (device.row['remote_version'] != remote.version) {
          reasons.add('Versione cloud e dispositivo differente');
        }
        if ((device.row['deleted_at'] != null) != remote.deleted) {
          reasons.add('Cancellazione dispositivo e cloud discordante');
        }
      }
      if (remote != null && backup != null) {
        if (backup.row['remote_version'] != remote.version) {
          reasons.add('Versione cloud e backup differente');
        }
        if ((backup.row['deleted_at'] != null) != remote.deleted) {
          reasons.add('Cancellazione backup e cloud discordante');
        }
      }
      if (reasons.isEmpty) {
        continue;
      }

      final separator = key.indexOf(':');
      final type = key.substring(0, separator);
      final originalTitle =
          (device?.row['title'] ?? backup?.row['title']) as String?;
      final title = originalTitle == null || originalTitle.trim().isEmpty
          ? '(nome non disponibile)'
          : originalTitle.length > 90
              ? originalTitle.substring(0, 90) : originalTitle;
      final fingerprint = draft.sourceFingerprint;
      final rawKey = '$fingerprint:$key';
      final opaqueKey = crypto.sha256.convert(utf8.encode(rawKey)).toString();
      rows.add(DraftConflictItem(
        opaqueKey: opaqueKey,
        kind: switch (type) {
          'note' => 'Nota',
          'task' => 'Attività',
          _ => 'Lista',
        },
        title: title,
        warnings: List.unmodifiable(reasons),
        onDevice: device != null,
        inBackup: backup != null,
        observedInCloud: remote != null,
        choice: DraftConflictChoice.undecided,
      ));
    }
    return ReconciliationWorksheet._(
      draft.sourceFingerprint, List.unmodifiable(rows),
    );
  }

  static Map<String, _Entry> _entities(FullBackupSnapshot snapshot) {
    final out = <String, _Entry>{};
    for (final spec in const [
      ('note_entries', 'note'),
      ('task_entries', 'task'),
      ('task_list_entries', 'list'),
    ]) {
      final kind = spec.$2;
      for (final row in snapshot.tables[spec.$1]!) {
        final id = row['id'] as String;
        out['$kind:$id'] = _Entry(
          row, FullBackupSnapshot.columns[spec.$1]!,
        );
      }
    }
    return out;
  }

  static Set<String> _pending(FullBackupSnapshot data) {
    final result = <String>{};
    for (final row in data.tables['pending_mutations']!) {
      final type = row['entity_type'] as String;
      final id = row['entity_id'] as String;
      result.add('$type:$id');
    }
    return result;
  }
}

class _Entry {
  const _Entry(this.row, this.columns);
  final Map<String, Object?> row;
  final List<String> columns;
}
