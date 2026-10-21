import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/cloud_auth.dart';
import '../data/local_store.dart';

class SyncState {
  final bool running;
  final bool conflict;
  final String? message;
  const SyncState({this.running = false, this.conflict = false, this.message});
}

final cloudSyncProvider = StateNotifierProvider<CloudSync, SyncState>(
    (ref) => CloudSync(ref));

class CloudSync extends StateNotifier<SyncState> {
  CloudSync(this.ref) : super(const SyncState());
  final Ref ref;
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> _request(
    String method, String path, {Map<String, dynamic>? json,
  }) async {
    final token = await ref.read(cloudAuthProvider.notifier).validAccessToken();
    final uri = Uri.parse('${CloudConfig.apiBaseUrl}/api/v1$path');
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
      throw StateError('Server HTTP ${response.statusCode}');
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
    try {
      // Explicit user action determines which account owns the local dataset.
      await db.bindOwner(cloud.userId!);
      final mutations = await db.pendingOperations();
      int uploaded = 0;
      for (final op in mutations) {
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
        await db.acknowledge(op, result['version'] as int);
        uploaded++;
      }
      int cursor = int.tryParse(await db.setting('syncCursor') ?? '') ?? 0;
      int downloaded = 0;
      while (true) {
        final result = await _request('GET', '/sync/changes?cursor=$cursor&limit=100');
        final changes = result['changes'] as List<dynamic>;
        for (final raw in changes) {
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
      state = const SyncState(conflict: true,
        message: 'Conflitto: i dati remoti sono stati modificati. '
          'Operazioni locali preservate, nessuna sovrascrittura.');
    } catch (e) {
      state = SyncState(message: 'Sync non riuscita; modifiche conservate offline. $e');
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class SyncConflict implements Exception {
  const SyncConflict();
}
