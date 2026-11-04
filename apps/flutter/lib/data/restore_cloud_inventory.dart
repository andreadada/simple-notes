import 'dart:convert';

import 'package:http/http.dart' as http;

import 'full_backup.dart';
import 'full_backup_recovery_guard.dart';

class RestoreInventoryRevision {
  const RestoreInventoryRevision({
    required this.version,
    required this.deleted,
    required this.changeId,
  });

  final int version;
  final bool deleted;
  final int changeId;
}

/// Snapshot of the sync-change ledger only. It may omit entities written by
/// other API endpoints; it does not reserve future versions or grant writes.
class RestoreServerInventory {
  const RestoreServerInventory(this.cursor, this.revisions);

  final int cursor;
  final Map<String, RestoreInventoryRevision> revisions;

  bool get canAuthorizeImportedSync => false;
}

/// Read-only client for P2.4B2C3 server contract. Explicit invocation only;
/// never wired into login, startup, normal CloudSync, or live restore.
class RestoreServerInventoryReader {
  const RestoreServerInventoryReader();

  Future<RestoreServerInventory> inspect({
    required http.Client client,
    required Uri apiBase,
    required Future<String> Function() accessToken,
  }) async {
    if (!apiBase.hasAuthority ||
        apiBase.userInfo.isNotEmpty ||
        apiBase.hasFragment || apiBase.hasQuery ||
        (apiBase.scheme != 'https' &&
            !(apiBase.scheme == 'http' &&
              const {'localhost', '127.0.0.1', '10.0.2.2'}
                  .contains(apiBase.host)))) {
      throw const FormatException('Origine del server non sicura.');
    }
    final token = await accessToken();
    if (token.isEmpty) {
      throw const FormatException('Autenticazione richiesta.');
    }
    final uri = apiBase.replace(path: '/api/v1/sync/inventory');
    final response = await client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
      throw const FormatException('Inventario cloud non disponibile.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const FormatException('Inventario cloud malformato.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        decoded['cursor'] is! int ||
        (decoded['cursor'] as int) < 0 ||
        decoded['complete'] != true ||
        decoded['items'] is! List) {
      throw const FormatException('Contratto inventario non compatibile.');
    }
    final items = decoded['items'] as List;
    if (items.length > 10000) {
      throw const FormatException('Inventario troppo grande.');
    }
    final cursor = decoded['cursor'] as int;
    final revisions = <String, RestoreInventoryRevision>{};
    for (final item in items) {
      if (item is! Map<String, dynamic> ||
          item.length != 5 ||
          !const {'note', 'task', 'list'}.contains(item['entityType']) ||
          item['entityId'] is! String ||
          (item['entityId'] as String).isEmpty ||
          (item['entityId'] as String).length > 1024 ||
          item['version'] is! int ||
          (item['version'] as int) < 0 ||
          item['deleted'] is! bool ||
          item['changeId'] is! int ||
          (item['changeId'] as int) < 1 ||
          (item['changeId'] as int) > cursor) {
        throw const FormatException('Revisione cloud non valida.');
      }
      final key = ''; 
    }
    return RestoreServerInventory(cursor, Map.unmodifiable(revisions));
  }
}

/// Conservative review, only for display after explicit authenticated GET.
/// A completed review still NEVER authorizes upload, replay or live restore.
class RestoreServerInventoryReview {
  const RestoreServerInventoryReview({
    required this.outboxCount,
    required this.unobservedOperations,
    required this.versionConflicts,
    required this.overlappingOperationIds,
    required this.cursorRegressed,
  });

  final int outboxCount;
  final int unobservedOperations;
  final int versionConflicts;
  final int overlappingOperationIds;
  final bool cursorRegressed;

  bool get requireManualReview => true;
  bool get canReplayImportedOutbox => false;
  bool get canRestoreLive => false;

  static RestoreServerInventoryReview compare({
    required FullBackupSnapshot checkpoint,
    required FullBackupSnapshot target,
    required RestoreServerInventory remote,
  }) {
    checkpoint.validate();
    target.validate();
    if (checkpoint.ownerId != target.ownerId) {
      throw const FormatException('Account del backup non corrispondente.');
    }
    final risk = RestoreReplayRisk.assess(checkpoint, target);
    var missing = 0;
    var conflicting = 0;
    for (final row in target.tables['pending_mutations']!) {
      final entityType = row['entity_type'] as String;
      final entityId = row['entity_id'] as String;
      final key = '$entityType:$entityId';
      final remoteRevision = remote.revisions[key];
      if (remoteRevision == null) {
        missing++;
        continue;
      }
      final table = switch (entityType) {
        'note' => 'note_entries',
        'task' => 'task_entries',
        'list' => 'task_list_entries',
        _ => throw const FormatException('Tipo outbox non valido'),
      };
      final local = target.tables[table]!
          .where((entry) => entry['id'] == entityId).toList();
      final localVersion = local.isEmpty
          ? null : local.single['remote_version'];
      if (localVersion is! int ||
          remoteRevision.version != localVersion ||
          remoteRevision.deleted) {
        conflicting++;
      }
    }
    return RestoreServerInventoryReview(
      outboxCount: target.count('pending_mutations'),
      unobservedOperations: missing,
      versionConflicts: conflicting,
      overlappingOperationIds: risk.sharedOperationIds,
      cursorRegressed: risk.cursorRegressedOrUnknown ||
          remote.cursor < 0,
    );
  }
}
