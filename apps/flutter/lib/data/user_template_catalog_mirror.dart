import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_task_templates.dart';
import 'user_template_cloud_api.dart';

enum UserTemplateMirrorResult {
  unchanged,
  uploaded,
  downloaded,
  conflict,
  skipped,
}

/// Per-account trusted last common catalog, separate from tasks and outbox.
/// The payload contains only template definitions, never account credentials.
class UserTemplateMirrorAnchor {
  const UserTemplateMirrorAnchor({
    required this.version,
    required this.catalog,
  });

  final int version;
  final UserTaskTemplateLibrary catalog;

  static String keyForOwner(String owner) =>
      '${UserTaskTemplateStore.keyForOwner(owner)}.mirror.v1';

  String encode() => jsonEncode({
    'schema': 1,
    'version': version,
    'catalog': jsonDecode(catalog.serialize()),
  });

  factory UserTemplateMirrorAnchor.decode(String source) {
    if (utf8.encode(source).length > 160 * 1024) {
      throw const FormatException('Checkpoint modelli troppo grande.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> || value.length != 3 ||
        value['schema'] != 1 || value['version'] is! int ||
        (value['version'] as int) < 0 ||
        value['catalog'] is! Map<String, dynamic>) {
      throw const FormatException('Checkpoint modelli non valido.');
    }
    return UserTemplateMirrorAnchor(
      version: value['version'] as int,
      catalog: UserTaskTemplateLibrary.deserialize(
          jsonEncode(value['catalog'])),
    );
  }

  static UserTemplateMirrorAnchor? read(
      SharedPreferences prefs, String owner) {
    final raw = prefs.getString(keyForOwner(owner));
    return raw == null ? null : UserTemplateMirrorAnchor.decode(raw);
  }

  Future<void> save(SharedPreferences prefs, String owner) async {
    final value = encode();
    UserTemplateMirrorAnchor.decode(value);
    if (!await prefs.setString(keyForOwner(owner), value)) {
      throw StateError('Checkpoint modelli non salvato.');
    }
  }
}

/// Foreground-only conservative, three-way reconciliation. No automatic
/// winner is chosen when both devices have changed their template catalogs.
/// On download, the local library is written before the anchor; on upload,
/// the cloud PUT is CAS-acknowledged before the anchor is written.
class UserTemplateCatalogMirror {
  const UserTemplateCatalogMirror();

  Future<UserTemplateMirrorResult> synchronize({
    required SharedPreferences preferences,
    required String owner,
    required UserTemplateCloudApi api,
    required Future<bool> Function(String owner) ownerMatches,
  }) async {
    if (!await ownerMatches(owner)) return UserTemplateMirrorResult.skipped;
    const store = UserTaskTemplateStore();
    final key = UserTaskTemplateStore.keyForOwner(owner);
    final wasPresent = preferences.containsKey(key);
    final local = await store.load(preferences, owner);
    final original = local.serialize();
    final anchor = UserTemplateMirrorAnchor.read(preferences, owner);

    final cloud = await api.read();
    if (!await ownerMatches(owner)) return UserTemplateMirrorResult.skipped;
    if (!await _sameLocal(preferences, owner, store,
        original, wasPresent)) {
      return UserTemplateMirrorResult.skipped;
    }

    final serverJson = cloud.library.serialize();
    if (cloud.version == 0 &&
        cloud.library.templates.isNotEmpty) {
      throw const FormatException('Catalogo cloud non inizializzato.');
    }
    if (anchor != null &&
        (cloud.version < anchor.version ||
         (cloud.version == anchor.version &&
          serverJson != anchor.catalog.serialize()))) {
      return UserTemplateMirrorResult.conflict;
    }
    if (original == serverJson) {
      if (!await ownerMatches(owner)) return UserTemplateMirrorResult.skipped;
      await UserTemplateMirrorAnchor(
        version: cloud.version, catalog: cloud.library,
      ).save(preferences, owner);
      return UserTemplateMirrorResult.unchanged;
    }

    if (anchor == null) {
      if (cloud.version > 0 && !wasPresent) {
        return _download(preferences, owner, cloud, store, ownerMatches,
            original, wasPresent);
      }
      // Nothing has ever been published. Explicitly saved local models can
      // seed the empty server; the absent empty library needs no PUT.
      if (cloud.version == 0 && local.templates.isNotEmpty) {
        return _upload(preferences, owner, local, cloud.version, store,
            api, ownerMatches, original, wasPresent);
      }
      return UserTemplateMirrorResult.conflict;
    }

    final base = anchor.catalog.serialize();
    final localChanged = original != base;
    final serverChanged = serverJson != base;
    if (localChanged && serverChanged) {
      return UserTemplateMirrorResult.conflict;
    }
    if (localChanged) {
      return _upload(preferences, owner, local, cloud.version, store,
          api, ownerMatches, original, wasPresent);
    }
    if (serverChanged) {
      return _download(preferences, owner, cloud, store, ownerMatches,
          original, wasPresent);
    }
    return UserTemplateMirrorResult.conflict;
  }

  Future<UserTemplateMirrorResult> _upload(
      SharedPreferences prefs, String owner, UserTaskTemplateLibrary local,
      int remoteVersion, UserTaskTemplateStore store,
      UserTemplateCloudApi api, Future<bool> Function(String) ownerMatches,
      String expected, bool wasPresent) async {
    if (!await _mayWrite(prefs, owner, store, ownerMatches,
        expected, wasPresent)) {
      return UserTemplateMirrorResult.skipped;
    }
    final accepted = await api.replace(
      expectedVersion: remoteVersion, library: local);
    if (!await ownerMatches(owner)) return UserTemplateMirrorResult.skipped;
    if (accepted.version <= remoteVersion ||
        accepted.library.serialize() != expected) {
      throw const FormatException('Risposta modelli cloud incoerente.');
    }
    await UserTemplateMirrorAnchor(
      version: accepted.version, catalog: accepted.library,
    ).save(prefs, owner);
    return UserTemplateMirrorResult.uploaded;
  }

  Future<UserTemplateMirrorResult> _download(
      SharedPreferences prefs, String owner,
      UserTemplateCloudSnapshot remote,
      UserTaskTemplateStore store, Future<bool> Function(String) ownerMatches,
      String expected, bool wasPresent) async {
    if (!await _mayWrite(prefs, owner, store, ownerMatches,
        expected, wasPresent)) {
      return UserTemplateMirrorResult.skipped;
    }
    await store.save(prefs, owner, remote.library);
    if (!await ownerMatches(owner)) return UserTemplateMirrorResult.skipped;
    await UserTemplateMirrorAnchor(
      version: remote.version, catalog: remote.library,
    ).save(prefs, owner);
    return UserTemplateMirrorResult.downloaded;
  }

  Future<bool> _sameLocal(
      SharedPreferences prefs, String owner, UserTaskTemplateStore store,
      String expected, bool wasPresent) async {
    final current = await store.load(prefs, owner);
    return current.serialize() == expected &&
        prefs.containsKey(UserTaskTemplateStore.keyForOwner(owner)) ==
            wasPresent;
  }

  Future<bool> _mayWrite(
      SharedPreferences prefs, String owner, UserTaskTemplateStore store,
      Future<bool> Function(String) ownerMatches,
      String expected, bool wasPresent) async {
    if (!await ownerMatches(owner)) return false;
    return await _sameLocal(prefs, owner, store, expected, wasPresent) &&
        await ownerMatches(owner);
  }

  /// Update anchor after a *user-confirmed* manual Pubblica/Scarica, never
  /// as a side effect of showing a confirmation dialog.
  Future<void> acknowledgeManual({
    required SharedPreferences preferences,
    required String owner,
    required UserTemplateCloudSnapshot snapshot,
  }) async {
    await UserTemplateMirrorAnchor(
      version: snapshot.version, catalog: snapshot.library,
    ).save(preferences, owner);
  }
}
