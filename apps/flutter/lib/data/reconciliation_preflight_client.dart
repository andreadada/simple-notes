import 'dart:convert';

import 'package:http/http.dart' as http;

import 'restore_cloud_inventory.dart';

/// A single non-mutating POST. The service compares revision metadata inside
/// one repeatable-read transaction but does NOT reserve or lease anything.
class ReconciliationPreflightResult {
  const ReconciliationPreflightResult({
    required this.observedCursor,
    required this.cursorMatches,
    required this.consistent,
    required this.checkedEntities,
    required this.mismatchedEntities,
  });

  final int observedCursor;
  final bool cursorMatches;
  final bool consistent;
  final int checkedEntities;
  final int mismatchedEntities;

  bool get canRestoreLive => false;
  bool get canApplyDecisions => false;
  bool get canWriteCloud => false;
  bool get canReplayImportedOutbox => false;
  bool get canResumeAutoSync => false;

  String get summary {
    final status = consistent
        ? 'Coerente al momento del controllo'
        : 'Versioni cambiate o precondizioni non soddisfatte';
    return 'Ricontrollo cloud di sola lettura: $status. '
        'Elementi verificati: $checkedEntities, '
        'diversi: $mismatchedEntities. '
        'Cursore remoto osservato: $observedCursor. '
        'Questo NON autorizza ripristino, upload o sincronizzazione. '
        'Il server può cambiare dopo la verifica.';
  }
}

/// Strict, explicit-only client for POST /sync/reconciliation/check.
/// The HTTP verb POST is used for a bounded JSON request body; the endpoint
/// MUST remain read-only. Not invoked during normal sync or application boot.
class ReconciliationPreflightClient {
  const ReconciliationPreflightClient();

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<ReconciliationPreflightResult> inspect({
    required http.Client client,
    required Uri apiBase,
    required Future<String> Function() accessToken,
    required RestoreServerInventory inventory,
  }) async {
    if (!apiBase.hasAuthority ||
        apiBase.userInfo.isNotEmpty ||
        apiBase.hasFragment || apiBase.hasQuery ||
        (apiBase.scheme != 'https' &&
            !(apiBase.scheme == 'http' &&
              const {'localhost', '127.0.0.1', '10.0.2.2'}
                  .contains(apiBase.host.toLowerCase())))) {
      throw const FormatException('Endpoint cloud non sicuro.');
    }
    if (inventory.cursor < 0 ||
        inventory.revisions.isEmpty ||
        inventory.revisions.length > 100) {
      // No partial check may appear to cover the complete inventory.
      throw const FormatException('Inventario non verificabile in un batch.');
    }
    final sorted = inventory.revisions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final items = <Map<String, Object?>>[];
    for (final item in sorted) {
      final separator = item.key.indexOf(':');
      if (separator <= 0 || separator == item.key.length - 1) {
        throw const FormatException('Chiave inventario non valida.');
      }
      final type = item.key.substring(0, separator);
      final id = item.key.substring(separator + 1);
      final revision = item.value;
      if (!const {'note', 'task', 'list'}.contains(type) ||
          !_uuid.hasMatch(id) ||
          revision.version < 0 ||
          revision.changeId < 1 ||
          revision.changeId > inventory.cursor) {
        throw const FormatException('Revisione inventario non valida.');
      }
      items.add({
        'entityType': type,
        'entityId': id,
        'changeId': revision.changeId,
        'version': revision.version,
        'deleted': revision.deleted,
      });
    }

    final token = await accessToken();
    if (token.isEmpty) {
      throw const FormatException('Token cloud assente.');
    }
    final endpoint = apiBase.replace(
      path: '/api/v1/sync/reconciliation/check',
    );
    final response = await client.post(
      endpoint,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'expectedCursor': inventory.cursor,
        'items': items,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 1024 * 1024) {
      throw const FormatException('Preflight remoto non disponibile.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const FormatException('Risposta preflight illeggibile.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 4 ||
        decoded['cursor'] is! int ||
        decoded['cursor'] < 0 ||
        decoded['cursorMatches'] is! bool ||
        decoded['consistent'] is! bool ||
        decoded['items'] is! List) {
      throw const FormatException('Contratto preflight non valido.');
    }
    final observedCursor = decoded['cursor'] as int;
    final cursorMatches = decoded['cursorMatches'] as bool;
    final consistent = decoded['consistent'] as bool;
    final observed = decoded['items'] as List;
    if (observed.length != items.length ||
        cursorMatches != (observedCursor == inventory.cursor)) {
      throw const FormatException('Preflight incompleto.');
    }
    var mismatches = 0;
    for (var i = 0; i < observed.length; i++) {
      final row = observed[i];
      final expected = items[i];
      if (row is! Map<String, dynamic> ||
          row.length != 6 ||
          row['entityType'] != expected['entityType'] ||
          row['entityId'] != expected['entityId'] ||
          row['matches'] is! bool) {
        throw const FormatException('Entità preflight inattesa.');
      }
      final changeId = row['changeId'];
      final version = row['version'];
      final deleted = row['deleted'];
      if ((changeId == null && (version != null || deleted != null)) ||
          (changeId != null &&
              (changeId is! int || changeId <= 0 ||
                  changeId > observedCursor ||
                  version is! int || version < 0 ||
                  deleted is! bool))) {
        throw const FormatException('Versione remota inattesa.');
      }
      final expectedMatch =
          changeId == expected['changeId'] &&
          version == expected['version'] &&
          deleted == expected['deleted'];
      if (row['matches'] != expectedMatch) {
        throw const FormatException('Indicatore preflight incoerente.');
      }
      if (!expectedMatch) mismatches++;
    }
    if (consistent != (cursorMatches && mismatches == 0)) {
      throw const FormatException('Preflight remoto non coerente.');
    }
    return ReconciliationPreflightResult(
      observedCursor: observedCursor,
      cursorMatches: cursorMatches,
      consistent: consistent,
      checkedEntities: observed.length,
      mismatchedEntities: mismatches,
    );
  }
}
