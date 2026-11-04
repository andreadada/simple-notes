import 'dart:convert';

import 'package:http/http.dart' as http;

import 'full_backup.dart';
import 'full_backup_recovery_guard.dart';

/// A read-only event-stream observation, NOT an authoritative server
/// snapshot or evidence that a restored operation can safely be uploaded.
class RestoreCloudObservation {
  const RestoreCloudObservation({
    required this.lastCursor,
    required this.eventsRead,
    required this.revisions,
  });

  final int lastCursor;
  final int eventsRead;
  final Map<String, int> revisions;

  bool get uploadAuthorized => false;
  bool get importedCursorTrusted => false;
}

/// P2.4B2C2: optional, explicitly invoked cloud *read-only* preflight.
/// It never calls /sync/apply, modifies local state, or grants replay.
/// This is NOT invoked from normal app startup or while recovery is blocked.
class RestoreCloudReadOnlyPreflight {
  const RestoreCloudReadOnlyPreflight();

  Future<RestoreCloudObservation> inspect({
    required http.Client client,
    required Uri apiBase,
    required Future<String> Function() accessToken,
  }) async {
    final hostname = apiBase.host.toLowerCase();
    if (apiBase.scheme != 'https' &&
        !(apiBase.scheme == 'http' &&
          const {'localhost', '127.0.0.1', '10.0.2.2'}
              .contains(hostname))) {
      throw const FormatException('Origine cloud non sicura.');
    }
    if (apiBase.userInfo.isNotEmpty ||
        apiBase.hasFragment || apiBase.hasQuery) {
      throw const FormatException('Endpoint cloud non valido.');
    }
    final token = await accessToken();
    if (token.isEmpty) {
      throw const FormatException('Sessione cloud assente.');
    }
    var cursor = 0;
    var count = 0;
    final latest = <String, int>{};
    for (var page = 0; page < 100; page++) {
      final uri = apiBase.replace(
        path: '/api/v1/sync/changes',
        queryParameters: {
          'cursor': cursor.toString(),
          'limit': '100',
        },
      );
      final response = await client.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        // Do not print any response payload or authentication token.
        throw const FormatException('Lettura cloud non verificabile.');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw const FormatException('Risposta cloud non valida.');
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['changes'] is! List ||
          decoded['nextCursor'] is! int ||
          decoded['hasMore'] is! bool) {
        throw const FormatException('Formato sync non valido.');
      }
      final events = decoded['changes'] as List;
      final nextCursor = decoded['nextCursor'] as int;
      final hasMore = decoded['hasMore'] as bool;
      if (events.length > 100 || count + events.length > 10000 ||
          nextCursor < cursor ||
          (hasMore && nextCursor == cursor)) {
        throw const FormatException('Paginazione cloud incoerente.');
      }
      for (final event in events) {
        if (event is! Map<String, dynamic> ||
            !const {'note', 'task', 'list'}
                .contains(event['entityType']) ||
            event['entityId'] is! String ||
            (event['entityId'] as String).isEmpty ||
            (event['entityId'] as String).length > 1024 ||
            event['version'] is! int ||
            (event['version'] as int) < 0 ||
            event['deleted'] is! bool) {
          throw const FormatException('Evento remoto non valido.');
        }
        final name = event['entityType'] as String;
        final id = event['entityId'] as String;
        final key = '$name:$id';
        final version = event['version'] as int;
        final earlier = latest[key];
        if (earlier != null && version < earlier) {
          throw const FormatException('Versione remota regredita.');
        }
        latest[key] = version;
      }
      count += events.length;
      cursor = nextCursor;
      if (!hasMore) {
        return RestoreCloudObservation(
          lastCursor: cursor,
          eventsRead: count,
          revisions: Map.unmodifiable(latest),
        );
      }
    }
    throw const FormatException('Lettura cloud parziale: troppe pagine.');
  }
}

/// The returned plan is *always* review-only. A server event stream may have
/// compaction and cannot prove absence of a newer remote record.
class RestoreCloudReview {
  const RestoreCloudReview({
    required this.importedOperations,
    required this.potentiallyStaleEntities,
    required this.unobservedEntities,
    required this.duplicateOperationIds,
    required this.cursorRegressedOrUnknown,
  });

  final int importedOperations;
  final int potentiallyStaleEntities;
  final int unobservedEntities;
  final int duplicateOperationIds;
  final bool cursorRegressedOrUnknown;

  bool get needsManualReview => true;
  bool get canReplayOperations => false;
  bool get canWriteToCloud => false;
  bool get canTrustImportedCursor => false;

  static RestoreCloudReview compare({
    required FullBackupSnapshot checkpoint,
    required FullBackupSnapshot target,
    required RestoreCloudObservation observation,
  }) {
    checkpoint.validate();
    target.validate();
    if (checkpoint.ownerId != target.ownerId) {
      throw const FormatException('Account non compatibili.');
    }
    final risk = RestoreReplayRisk.assess(checkpoint, target);
    final operations = target.tables['pending_mutations']!;
    final unknown = <String>{};
    final stale = <String>{};
    for (final operation in operations) {
      final type = operation['entity_type'] as String;
      final id = operation['entity_id'] as String;
      final key = '$type:$id';
      final currentVersion = observation.revisions[key];
      final table = switch (type) {
        'note' => 'note_entries',
        'task' => 'task_entries',
        'list' => 'task_list_entries',
        _ => throw const FormatException('Tipo modifica sconosciuto'),
      };
      final matched = target.tables[table]!
          .where((row) => row['id'] == id).toList();
      final localVersion = matched.isEmpty
          ? null : matched.single['remote_version'];
      if (currentVersion == null) {
        unknown.add(key);
      } else if (localVersion is! int ||
          currentVersion > localVersion) {
        stale.add(key);
      }
    }
    return RestoreCloudReview(
      importedOperations: operations.length,
      potentiallyStaleEntities: stale.length,
      unobservedEntities: unknown.length,
      duplicateOperationIds: risk.sharedOperationIds,
      cursorRegressedOrUnknown: risk.cursorRegressedOrUnknown ||
          observation.lastCursor < 0,
    );
  }
}
