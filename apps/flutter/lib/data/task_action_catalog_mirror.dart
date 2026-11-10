import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_action_automations.dart';
import 'task_action_cloud_api.dart';

enum TaskActionMirrorResult {
  unchanged,
  initialized,
  uploaded,
  downloaded,
  conflict,
  skipped,
}

/// The last fully acknowledged *pair* (remote revision and catalog). It is
/// owner-scoped, local-only metadata, NOT another task sync operation.
class TaskActionMirrorAnchor {
  const TaskActionMirrorAnchor({
    required this.version,
    required this.catalog,
  });

  final int version;
  final TaskActionLibrary catalog;

  static String keyForOwner(String owner) =>
      '${TaskActionStore.keyForOwner(owner)}.mirror.v1';

  String encode() => jsonEncode({
    'schema': 1,
    'version': version,
    'catalog': jsonDecode(catalog.serialize()),
  });

  factory TaskActionMirrorAnchor.decode(String source) {
    if (utf8.encode(source).length > 40 * 1024) {
      throw const FormatException('Checkpoint automazioni troppo grande.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> || value.length != 3 ||
        value['schema'] != 1 || value['version'] is! int ||
        (value['version'] as int) < 0 ||
        value['catalog'] is! Map<String, dynamic>) {
      throw const FormatException('Checkpoint automazioni non valido.');
    }
    return TaskActionMirrorAnchor(
      version: value['version'] as int,
      catalog: TaskActionLibrary.deserialize(
          jsonEncode(value['catalog'])),
    );
  }

  static TaskActionMirrorAnchor? read(
      SharedPreferences preferences, String owner) {
    final value = preferences.getString(keyForOwner(owner));
    return value == null ? null : TaskActionMirrorAnchor.decode(value);
  }

  Future<void> save(SharedPreferences preferences, String owner) async {
    final encoded = encode();
    TaskActionMirrorAnchor.decode(encoded);
    if (!await preferences.setString(keyForOwner(owner), encoded)) {
      throw StateError('Checkpoint automazioni non salvato.');
    }
  }
}

/// Conservative three-way reconciliation of rule *definitions*. Automatic
/// sync never resolves a two-device conflict by choosing a winner; the
/// existing explicit Publish/Download confirmation handles such decisions.
///
/// Write order is crash-safe: on download local rules are saved before the
/// anchor; on upload the server acknowledges before saving the anchor. A
/// crash between these steps converges by comparing the complete catalogs.
class TaskActionCatalogMirror {
  const TaskActionCatalogMirror();

  Future<TaskActionMirrorResult> synchronize({
    required SharedPreferences preferences,
    required String owner,
    required TaskActionCloudApi api,
    required Future<bool> Function(String owner) ownerMatches,
  }) async {
    if (!await ownerMatches(owner)) return TaskActionMirrorResult.skipped;
    final localKey = TaskActionStore.keyForOwner(owner);
    final wasPresent = preferences.containsKey(localKey);
    final store = const TaskActionStore();
    // Neither bad local JSON nor a bad checkpoint is silently reset.
    final start = await store.load(preferences, owner);
    final startEncoded = start.serialize();
    final anchor = TaskActionMirrorAnchor.read(preferences, owner);

    final remote = await api.read();
    if (!await ownerMatches(owner)) return TaskActionMirrorResult.skipped;
    final current = await store.load(preferences, owner);
    if (current.serialize() != startEncoded ||
        preferences.containsKey(localKey) != wasPresent) {
      return TaskActionMirrorResult.skipped;
    }

    final remoteEncoded = remote.library.serialize();
    // Refuse an unexpected server rollback or catalog mutation without
    // advancing the revision. Such changes invalidate the trusted anchor.
    if (anchor != null &&
        (remote.version < anchor.version ||
         (remote.version == anchor.version &&
          remoteEncoded != anchor.catalog.serialize()))) {
      return TaskActionMirrorResult.conflict;
    }
    final same = startEncoded == remoteEncoded;
    if (same) {
      await TaskActionMirrorAnchor(
        version: remote.version, catalog: remote.library,
      ).save(preferences, owner);
      return TaskActionMirrorResult.unchanged;
    }

    if (anchor == null) {
      // A freshly installed device has no local preference at all.
      // Explicitly saved empty libraries are a change, not an invitation
      // to erase someone else's published catalog.
      if (remote.version > 0 && !wasPresent) {
        return _download(preferences, owner, remote, store, ownerMatches,
            expectedLocal: startEncoded, expectedPresent: wasPresent);
      }
      if (remote.version == 0) {
        return _upload(preferences, owner, start, remote.version,
            store, api, ownerMatches,
            expectedLocal: startEncoded, expectedPresent: wasPresent);
      }
      return TaskActionMirrorResult.conflict;
    }

    // Never infer a safe merge from independent edit timestamps. Order of
    // rules is semantic, and deletion conflicts must remain visible.
    final baseEncoded = anchor.catalog.serialize();
    final localChanged = startEncoded != baseEncoded;
    final remoteChanged = remoteEncoded != baseEncoded;
    if (localChanged && remoteChanged) {
      return TaskActionMirrorResult.conflict;
    }
    if (localChanged) {
      return _upload(preferences, owner, start, remote.version,
          store, api, ownerMatches,
          expectedLocal: startEncoded, expectedPresent: wasPresent);
    }
    if (remoteChanged) {
      return _download(preferences, owner, remote, store, ownerMatches,
          expectedLocal: startEncoded, expectedPresent: wasPresent);
    }
    // The catalog matches the base but the server revision changed and
    // content is different only when a malformed state slipped through.
    return TaskActionMirrorResult.conflict;
  }

  Future<TaskActionMirrorResult> _upload(
      SharedPreferences preferences, String owner, TaskActionLibrary local,
      int remoteVersion, TaskActionStore store, TaskActionCloudApi api,
      Future<bool> Function(String) ownerMatches, {
      required String expectedLocal, required bool expectedPresent,
  }) async {
    if (!await _canWrite(preferences, owner, store, ownerMatches,
        expectedLocal, expectedPresent)) {
      return TaskActionMirrorResult.skipped;
    }
    final accepted = await api.replace(
      expectedVersion: remoteVersion, library: local);
    if (!await ownerMatches(owner)) return TaskActionMirrorResult.skipped;
    if (accepted.version <= remoteVersion ||
        accepted.library.serialize() != expectedLocal) {
      throw const FormatException('Risposta cloud non coerente.');
    }
    await TaskActionMirrorAnchor(
      version: accepted.version, catalog: accepted.library,
    ).save(preferences, owner);
    return TaskActionMirrorResult.uploaded;
  }

  Future<TaskActionMirrorResult> _download(
      SharedPreferences preferences, String owner,
      TaskActionCloudSnapshot remote, TaskActionStore store,
      Future<bool> Function(String) ownerMatches, {
      required String expectedLocal, required bool expectedPresent,
  }) async {
    if (!await _canWrite(preferences, owner, store, ownerMatches,
        expectedLocal, expectedPresent)) {
      return TaskActionMirrorResult.skipped;
    }
    await store.save(preferences, owner, remote.library);
    if (!await ownerMatches(owner)) return TaskActionMirrorResult.skipped;
    await TaskActionMirrorAnchor(
      version: remote.version, catalog: remote.library,
    ).save(preferences, owner);
    return TaskActionMirrorResult.downloaded;
  }

  Future<bool> _canWrite(
      SharedPreferences preferences, String owner, TaskActionStore store,
      Future<bool> Function(String) ownerMatches, String expectedLocal,
      bool expectedPresent) async {
    if (!await ownerMatches(owner)) return false;
    final current = await store.load(preferences, owner);
    return current.serialize() == expectedLocal &&
        preferences.containsKey(TaskActionStore.keyForOwner(owner)) ==
            expectedPresent &&
        await ownerMatches(owner);
  }

  /// Called only after an explicit, user-confirmed Publish/Download. An
  /// invalid checkpoint is not deleted by background reconciliation, but a
  /// deliberate manual resolution may replace it with the observed revision.
  Future<void> acknowledgeManual({
    required SharedPreferences preferences,
    required String owner,
    required TaskActionCloudSnapshot snapshot,
  }) async {
    await TaskActionMirrorAnchor(
      version: snapshot.version, catalog: snapshot.library,
    ).save(preferences, owner);
  }
}
