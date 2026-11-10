import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/task_templates.dart';
import 'package:simple_notes/data/user_task_templates.dart';
import 'package:simple_notes/data/user_template_catalog_mirror.dart';
import 'package:simple_notes/data/user_template_cloud_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const mirror = UserTemplateCatalogMirror();
  const store = UserTaskTemplateStore();
  const owner = 'account-A';
  final empty = UserTaskTemplateLibrary();

  UserTaskTemplateLibrary named(String title) =>
    UserTaskTemplateLibrary(templates: [
      TaskTemplate(
        id: 'custom-fixture', title: title, description: 'Fixture',
        tags: const ['test'], subtasks: const ['Verify'],
      ),
    ]);

  UserTemplateCloudApi server(
      UserTaskTemplateLibrary Function() catalog,
      int Function() version,
      void Function(UserTaskTemplateLibrary, int) put,
      {void Function()? onRead, int? status}) {
    return UserTemplateCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'JWT_PRIVATE',
      client: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer JWT_PRIVATE');
        if (status != null) return http.Response('{}', status);
        if (req.method == 'GET') {
          onRead?.call();
          return http.Response(jsonEncode({
            'version': version(),
            'catalog': jsonDecode(catalog().serialize()),
          }), 200);
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final incoming = UserTaskTemplateLibrary.deserialize(
            jsonEncode(body['catalog']));
        final expected = body['expectedVersion'] as int;
        if (expected != version()) return http.Response('{}', 409);
        put(incoming, expected);
        return http.Response(jsonEncode({
          'version': version(),
          'catalog': jsonDecode(catalog().serialize()),
        }), 200);
      }),
    );
  }

  test('first device downloads remote catalog, then remains aligned', () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = named('cloud');
    var writes = 0;
    final api = server(() => remote, () => 4, (_, __) => writes++);
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.downloaded);
    expect((await store.load(prefs, owner)).serialize(), remote.serialize());
    expect(UserTemplateMirrorAnchor.read(prefs, owner)!.version, 4);
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.unchanged);
    expect(writes, 0);
  });

  test('offline models are published once to empty cloud via CAS', () async {
    final prefs = await SharedPreferences.getInstance();
    final local = named('offline');
    await store.save(prefs, owner, local);
    var cloud = empty, version = 0, writes = 0;
    final api = server(() => cloud, () => version, (lib, _) {
      cloud = lib; version++; writes++;
    });
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.uploaded);
    expect(cloud.serialize(), local.serialize());
    expect(writes, 1);
    expect(UserTemplateMirrorAnchor.read(prefs, owner)!.version, 1);
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.unchanged);
    expect(writes, 1);
  });

  test('empty untouched library never triggers unnecessary remote PUT', () async {
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    final api = server(() => empty, () => 0, (_, __) => writes++);
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.unchanged);
    expect(prefs.containsKey(UserTaskTemplateStore.keyForOwner(owner)), isFalse);
    expect(writes, 0);
    expect(UserTemplateMirrorAnchor.read(prefs, owner)!.version, 0);
  });

  test('anchored local changes upload, remote changes download without loop', () async {
    final prefs = await SharedPreferences.getInstance();
    var cloud = named('baseline'), version = 2, writes = 0;
    await store.save(prefs, owner, cloud);
    final api = server(() => cloud, () => version, (lib, _) {
      cloud = lib; version++; writes++;
    });
    await mirror.synchronize(preferences: prefs, owner: owner,
        api: api, ownerMatches: (_) async => true);
    await store.save(prefs, owner, named('local'));
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
        api: api, ownerMatches: (_) async => true),
        UserTemplateMirrorResult.uploaded);
    expect(writes, 1);
    cloud = named('from-other-device'); version++;
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
        api: api, ownerMatches: (_) async => true),
        UserTemplateMirrorResult.downloaded);
    expect((await store.load(prefs, owner)).serialize(), cloud.serialize());
    expect(writes, 1);
  });

  test('different offline changes on both sides preserve both originals',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var remote = named('baseline'), version = 5, writes = 0;
    await store.save(prefs, owner, remote);
    final api = server(() => remote, () => version, (_, __) => writes++);
    await mirror.synchronize(preferences: prefs, owner: owner,
        api: api, ownerMatches: (_) async => true);
    final local = named('local-only');
    await store.save(prefs, owner, local);
    remote = named('cloud-only'); version++;
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
        api: api, ownerMatches: (_) async => true),
        UserTemplateMirrorResult.conflict);
    expect((await store.load(prefs, owner)).serialize(), local.serialize());
    expect(remote.serialize(), named('cloud-only').serialize());
    expect(UserTemplateMirrorAnchor.read(prefs, owner)!.version, 5);
    expect(writes, 0);
  });

  test('first-time divergent catalogs and intentional deletion fail closed',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(prefs, owner, named('different'));
    final cloud = named('published');
    final api = server(() => cloud, () => 2, (_, __) =>
        fail('No unexpected upload'));
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.conflict);
    await store.save(prefs, owner, empty); // Explicit empty is a deletion.
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.conflict);
    expect((await store.load(prefs, owner)).templates, isEmpty);
  });

  test('account switch and local concurrent modification skip writes',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var allowed = true;
    final api = server(() => named('cloud'), () => 3, (_, __) {},
        onRead: () => allowed = false);
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => allowed),
      UserTemplateMirrorResult.skipped);
    expect(prefs.containsKey(UserTaskTemplateStore.keyForOwner(owner)), isFalse);
    expect(UserTemplateMirrorAnchor.read(prefs, owner), isNull);
    final local = named('edited-during-get');
    final api2 = server(() => named('cloud'), () => 3, (_, __) {},
      onRead: () => prefs.setString(
          UserTaskTemplateStore.keyForOwner(owner), local.serialize()));
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api2, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.skipped);
    expect((await store.load(prefs, owner)).serialize(), local.serialize());
  });

  test('corrupt preference or anchor never gets silently overwritten',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final api = server(() => empty, () => 0, (_, __) {});
    final anchor = UserTemplateMirrorAnchor.keyForOwner(owner);
    await prefs.setString(anchor, '{corrupted');
    await expectLater(mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true), throwsFormatException);
    expect(prefs.getString(anchor), '{corrupted');
    await prefs.remove(anchor);
    await prefs.setString(UserTaskTemplateStore.keyForOwner(owner), '{bad');
    await expectLater(mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true), throwsFormatException);
    expect(prefs.getString(UserTaskTemplateStore.keyForOwner(owner)), '{bad');
  });

  test('cloud rollback, forged same version and 409 never alter local data',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final baseline = named('baseline');
    await store.save(prefs, owner, baseline);
    var version = 5;
    var cloud = baseline;
    final api = server(() => cloud, () => version, (_, __) {});
    await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true);
    version = 4;
    cloud = named('older');
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.conflict);
    version = 5;
    expect(await mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true),
      UserTemplateMirrorResult.conflict);
    expect((await store.load(prefs, owner)).serialize(), baseline.serialize());

    await store.save(prefs, owner, named('offline-edit'));
    final conflictApi = server(() => baseline, () => 5, (_, __) {},
        status: 409);
    await expectLater(mirror.synchronize(preferences: prefs, owner: owner,
      api: conflictApi, ownerMatches: (_) async => true),
      throwsA(isA<UserTemplateCloudConflict>()));
    expect((await store.load(prefs, owner)).serialize(),
        named('offline-edit').serialize());
  });

  test('manual user resolution moves anchor without changing templates',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final chosen = named('selected-by-user');
    await mirror.acknowledgeManual(
      preferences: prefs, owner: owner,
      snapshot: UserTemplateCloudSnapshot(version: 8, library: chosen));
    final anchor = UserTemplateMirrorAnchor.read(prefs, owner)!;
    expect(anchor.version, 8);
    expect(anchor.catalog.serialize(), chosen.serialize());
    expect(UserTemplateMirrorAnchor.keyForOwner(owner), isNot(contains(owner)));
    expect(prefs.containsKey(UserTaskTemplateStore.keyForOwner(owner)), isFalse);
  });

  test('upload server must increment revision and echo accepted catalog',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(prefs, owner, named('local'));
    final api = UserTemplateCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'token',
      client: MockClient((req) async => http.Response(jsonEncode({
        'version': 0,
        'catalog': jsonDecode(
          (req.method == 'PUT' ? named('local') : empty).serialize()),
      }), 200)),
    );
    await expectLater(mirror.synchronize(preferences: prefs, owner: owner,
      api: api, ownerMatches: (_) async => true), throwsFormatException);
    expect(UserTemplateMirrorAnchor.read(prefs, owner), isNull);
  });
}
