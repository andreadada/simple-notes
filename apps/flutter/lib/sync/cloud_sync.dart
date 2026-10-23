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
  final String? message;
  final ConflictDetails? details;
  const SyncState({this.running = false, this.conflict = false,
      this.message, this.details});
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
    if (response.statusCode == 409) {
      throw const SyncConflict();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Server HTTP ${response.statusCode} su $path');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
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
      for (final op in mutations) {
        conflicting = op;
        verifyAccount();
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
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
      state = SyncState(message: 'Sincronizzazione completata: $uploaded inviate, '
          '$downloaded aggiornamenti ricevuti.');
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

class SyncConflict implements Exception {
  const SyncConflict();
}
