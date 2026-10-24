import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/cloud_auth.dart';
import '../data/app_database.dart';
import '../data/local_store.dart';

class ConflictDetails {
  final String entityType;
  final String entityId;
  final String localTitle;
  final String localBody;
  final bool localDeleted;
  final Map<String, dynamic>? remotePayload;
  final bool remoteDeleted;
  final int? remoteVersion;

  const ConflictDetails({
    required this.entityType,
    required this.entityId,
    required this.localTitle,
    required this.localBody,
    required this.localDeleted,
    required this.remotePayload,
    required this.remoteDeleted,
    required this.remoteVersion,
  });
}

class SyncState {
  final bool running;
  final bool conflict;
  final bool upgradeRequired;
  final String? message;
  final ConflictDetails? details;
  const SyncState({
    this.running = false,
    this.conflict = false,
    this.upgradeRequired = false,
    this.message,
    this.details,
  });
}

/// A deliberately non-sensitive local/cloud health summary.
/// Does not include tokens, account IDs, note text or task contents.
class SyncDiagnostics {
  const SyncDiagnostics({
    required this.authenticated,
    required this.apiConfigured,
    required this.accountMatchesLocal,
    required this.pending,
    required this.localTasks,
    required this.localNotes,
    required this.localLists,
    required this.cursor,
    required this.lastSuccessUtc,
    required this.backendStatus,
  });

  final bool authenticated;
  final bool apiConfigured;
  final bool accountMatchesLocal;
  final int pending;
  final int localTasks;
  final int localNotes;
  final int localLists;
  final int cursor;
  final DateTime? lastSuccessUtc;
  /// 'compatible', 'outdated', 'offline', 'signed-out', 'unconfigured'
  /// or 'account-mismatch' — no raw server errors or sensitive data.
  final String backendStatus;

  String get backendLabel => switch (backendStatus) {
    'compatible' => 'Compatibile (taskDueSchema 1)',
    'outdated' => 'Versione backend incompatibile',
    'offline' => 'API non raggiungibile o non verificabile',
    'signed-out' => 'Accedi con Google',
    'unconfigured' => 'API_BASE_URL non configurata',
    'account-mismatch' => 'Archivio locale associato a un altro account',
    _ => 'Stato non disponibile',
  };
}

final cloudSyncProvider = StateNotifierProvider<CloudSync, SyncState>(
    (ref) => CloudSync(ref));

class CloudSync extends StateNotifier<SyncState> {
  CloudSync(this.ref, {http.Client? client, String? apiBaseUrl})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _apiBaseUrl = apiBaseUrl ?? CloudConfig.apiBaseUrl,
        super(const SyncState());
  final Ref ref;
  final http.Client _client;
  final bool _ownsClient;
  final String _apiBaseUrl;

  Future<Map<String, dynamic>> _request(
    String method, String path, {Map<String, dynamic>? json,
  }) async {
    final token = await ref.read(cloudAuthProvider.notifier).validAccessToken();
    final uri = Uri.parse('$_apiBaseUrl/api/v1$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final http.Response response;
    if (method == 'POST') {
      response = await _client.post(uri, headers: headers, body: jsonEncode(json))
          .timeout(const Duration(seconds: 20));
    } else {
      response = await _client.get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    }
    if (response.statusCode == 426) {
      throw const SyncUpgradeRequired();
    }
    if (response.statusCode == 409) {
      throw const SyncConflict();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Server HTTP ${response.statusCode} su $path');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// The old Coolify deployment may not yet expose /capabilities. A 404
  /// means modern date-only/timed writes must remain safely in the outbox.
  Future<bool> _supportsTypedDue() async {
    final token = await ref.read(cloudAuthProvider.notifier).validAccessToken();
    final result = await _client.get(
      Uri.parse('$_apiBaseUrl/api/v1/capabilities'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    if (result.statusCode == 404) return false;
    if (result.statusCode != 200) {
      throw StateError('Capacità API non verificabili (HTTP ${result.statusCode})');
    }
    final capability = jsonDecode(result.body) as Map<String, dynamic>;
    return capability['taskDueSchema'] == 1;
  }

  /// T4: passive, read-only diagnostics for real Windows/Android acceptance.
  /// Never uploads outbox entries, changes local ownership or logs secrets.
  Future<SyncDiagnostics> inspectSync() async {
    final db = ref.read(databaseProvider);
    final session = ref.read(cloudAuthProvider);
    final pending = await db.pendingCount();
    final snapshot = await db.snapshot();
    final owner = await db.setting('boundOwnerId');
    final cursor = int.tryParse(await db.setting('syncCursor') ?? '') ?? 0;
    final lastRaw = await db.setting('lastSyncSuccessUtc');
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    final matches = owner == null ||
        (session.userId != null && owner == session.userId);
    String backend;
    if (!CloudConfig.enabled) {
      // Injected test clients can point at mock servers even without dart-defines.
      backend = _apiBaseUrl.startsWith('https://')
          ? 'signed-out' : 'unconfigured';
    } else {
      backend = 'signed-out';
    }
    if (!session.authenticated || session.userId == null) {
      backend = 'signed-out';
    } else if (!matches) {
      backend = 'account-mismatch';
    } else if (!_apiBaseUrl.startsWith('https://') &&
        !_apiBaseUrl.startsWith('http://localhost:') &&
        !_apiBaseUrl.startsWith('http://127.0.0.1:') &&
        !_apiBaseUrl.startsWith('http://10.0.2.2:')) {
      backend = 'unconfigured';
    } else {
      try {
        final result = await _request('GET', '/capabilities');
        backend = result['taskDueSchema'] == 1 &&
            result['requiresExplicitDueForModernTasks'] == true &&
            result['taskDueKinds'] is List &&
            {'none', 'date', 'datetime', 'legacy'}.every(
              (kind) => (result['taskDueKinds'] as List).contains(kind))
            ? 'compatible' : 'outdated';
      } on SyncUpgradeRequired {
        backend = 'outdated';
      } on StateError catch (error) {
        backend = error.toString().contains('HTTP 404') ||
            error.toString().contains('HTTP 426')
            ? 'outdated' : 'offline';
      } catch (_) {
        backend = 'offline';
      }
    }
    return SyncDiagnostics(
      authenticated: session.authenticated,
      apiConfigured: _apiBaseUrl.isNotEmpty,
      accountMatchesLocal: matches,
      pending: pending,
      localTasks: snapshot.tasks.length,
      localNotes: snapshot.notes.length,
      localLists: snapshot.lists.length,
      cursor: cursor,
      lastSuccessUtc: last?.toUtc(),
      backendStatus: backend,
    );
  }

  Future<void> synchronize() async {
    if (state.running) return;
    final cloud = ref.read(cloudAuthProvider);
    if (!cloud.authenticated || cloud.userId == null) {
      state = const SyncState(message: 'Accedi con Google prima di sincronizzare.');
      return;
    }
    state = const SyncState(running: true);
    final db = ref.read(databaseProvider);
    PendingMutation? conflicting;
    try {
      // Explicit user action determines which account owns the local dataset.
      await db.bindOwner(cloud.userId!);
      final mutations = await db.pendingOperations();
      void verifyAccount() {
        if (ref.read(cloudAuthProvider).userId != cloud.userId) {
          throw StateError('Account cambiato durante la sincronizzazione');
        }
      }
      int uploaded = 0;
      bool? typedDueSupported;
      for (final op in mutations) {
        conflicting = op;
        verifyAccount();
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        // An operation with a precise new due kind requires the V7 server.
        // Never upload a date-only task to a server that silently ignores due.
        final due = payload['due'];
        if (op.entityType == 'task' && op.action == 'upsert' &&
            due is Map && (due['kind'] == 'date' || due['kind'] == 'datetime')) {
          typedDueSupported ??= await _supportsTypedDue();
          if (!typedDueSupported) throw const SyncUpgradeRequired();
        }
        if (op.entityType == 'task' && payload['dueAt'] is String) {
          final parsed = DateTime.tryParse(payload['dueAt'] as String);
          payload['dueAt'] = parsed?.toUtc().toIso8601String();
        }
        final expected = await db.remoteVersionFor(op.entityType, op.entityId);
        final result = await _request('POST', '/sync/apply', json: {
          'operationId': op.operationId,
          'entityId': op.entityId,
          'entityType': op.entityType,
          'action': op.action,
          'expectedVersion': expected,
          'payload': payload,
        });
        verifyAccount();
        await db.acknowledge(op, result['version'] as int);
        conflicting = null;
        uploaded++;
      }
      int cursor = int.tryParse(await db.setting('syncCursor') ?? '') ?? 0;
      int downloaded = 0;
      while (true) {
        verifyAccount();
        final result = await _request('GET', '/sync/changes?cursor=$cursor&limit=100');
        final changes = result['changes'] as List<dynamic>;
        for (final raw in changes) {
          verifyAccount();
          final item = raw as Map<String, dynamic>;
          await db.applyRemote(
            type: item['entityType'] as String,
            entityId: item['entityId'] as String,
            payload: item['payload'] as Map<String, dynamic>,
            deleted: item['deleted'] as bool,
            version: item['version'] as int,
          );
          downloaded++;
        }
        cursor = result['nextCursor'] as int;
        await db.putSetting('syncCursor', cursor.toString());
        if (result['hasMore'] != true) break;
      }
      await ref.read(localStoreProvider.notifier).reload();
      // Commit a local-only success marker after both upload and pull succeed.
      // Do not update it for HTTP 426, 409, offline or partial sync failures.
      await db.putSetting('lastSyncSuccessUtc',
          DateTime.now().toUtc().toIso8601String());
      state = SyncState(message: 'Sincronizzazione completata: $uploaded inviate, '
          '$downloaded aggiornamenti ricevuti.');
    } on SyncUpgradeRequired {
      state = const SyncState(upgradeRequired: true, message:
        'Il server o un client precedente non supporta questa scadenza. '
        'Aggiorna il backend e i dispositivi; modifiche offline conservate.');
    } on SyncConflict {
      final op = conflicting;
      ConflictDetails? details;
      if (op != null) {
        final local = jsonDecode(op.payload) as Map<String, dynamic>;
        Map<String, dynamic>? latest;
        try {
          latest = await _request('GET',
              '/sync/latest?entityType=${op.entityType}&entityId=${op.entityId}');
        } catch (_) {
          // The conflict remains unresolved; no local writes are discarded.
        }
        details = ConflictDetails(
          entityType: op.entityType, entityId: op.entityId,
          localTitle: local['title'] as String? ?? '(eliminato)',
          localBody: local['body'] as String? ?? local['description'] as String? ?? '',
          localDeleted: op.action == 'delete',
          remotePayload: latest?['payload'] as Map<String, dynamic>?,
          remoteDeleted: latest?['deleted'] == true,
          remoteVersion: latest?['version'] as int?,
        );
      }
      state = SyncState(conflict: true, details: details,
        message: 'Conflitto tra modifiche locali e server: scegli quale '
          'versione conservare. Nessun dato è stato cancellato.');
    } catch (e) {
      state = SyncState(message: 'Sync non riuscita; modifiche conservate offline. $e');
    }
  }

  /// Explicitly resolve a conflict. Never silently discard outbox entries.
  /// The latest server version is refetched to avoid acting on a stale
  /// comparison if another device edits while the dialog is open.
  Future<void> resolveConflict({required bool keepLocal}) async {
    final conflict = state.details;
    final cloud = ref.read(cloudAuthProvider);
    if (conflict == null || state.running || cloud.userId == null ||
        conflict.remoteVersion == null) {
      return;
    }
    state = SyncState(running: true, conflict: true, details: conflict);
    try {
      final latest = await _request('GET',
          '/sync/latest?entityType=${conflict.entityType}&entityId=${conflict.entityId}');
      if (ref.read(cloudAuthProvider).userId != cloud.userId) {
        throw StateError('Account Google cambiato');
      }
      final version = latest['version'] as int;
      if (version != conflict.remoteVersion ||
          (latest['deleted'] == true) != conflict.remoteDeleted) {
        state = const SyncState(conflict: true,
          message: 'La versione server è cambiata ancora. '
              'Sincronizza nuovamente per rivedere il conflitto.');
        return;
      }
      final db = ref.read(databaseProvider);
      if (keepLocal) {
        if (conflict.remoteDeleted) {
          state = SyncState(conflict: true, details: conflict,
            message: 'Elemento eliminato sul server: non è possibile '
                'sovrascriverlo. Conserva una copia separata prima di procedere.');
          return;
        }
        await db.rebaseLocalConflict(type: conflict.entityType,
            entityId: conflict.entityId, remoteVersion: version);
      } else {
        await db.acceptRemoteConflict(type: conflict.entityType,
            entityId: conflict.entityId,
            payload: latest['payload'] as Map<String, dynamic>,
            deleted: latest['deleted'] as bool, version: version);
        await ref.read(localStoreProvider.notifier).reload();
      }
      state = const SyncState(message: 'Conflitto risolto. Sincronizzazione in corso...');
      await synchronize();
    } catch (error) {
      state = SyncState(conflict: true, details: conflict,
        message: 'Impossibile risolvere il conflitto: $error');
    }
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }
}

class SyncUpgradeRequired implements Exception {
  const SyncUpgradeRequired();
}

class SyncConflict implements Exception {
  const SyncConflict();
}
