import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/task_action_automations.dart';
import 'package:simple_notes/data/task_action_catalog_mirror.dart';
import 'package:simple_notes/data/task_action_cloud_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const mirror = TaskActionCatalogMirror();
  const store = TaskActionStore();
  const owner = 'account-A';
  final empty = TaskActionLibrary();
  TaskActionLibrary tagged(String value) => TaskActionLibrary(rules: [
    TaskActionLibrary.newRule(
      trigger: 'created', action: 'tag', value: value),
  ]);
  TaskActionCloudApi server(
      TaskActionLibrary Function() getCatalog,
      int Function() getVersion,
      void Function(TaskActionLibrary, int) put,
      {void Function()? onRead}) {
    return TaskActionCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          onRead?.call();
          return http.Response(jsonEncode({
            'version': getVersion(),
            'catalog': jsonDecode(getCatalog().serialize()),
          }), 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final lib = TaskActionLibrary.deserialize(
          jsonEncode(body['catalog']));
        final expected = body['expectedVersion'] as int;
        if (expected != getVersion()) return http.Response('{}', 409);
        put(lib, expected);
        return http.Response(jsonEncode({
          'version': getVersion(),
          'catalog': jsonDecode(getCatalog().serialize()),
        }), 200);
      }),
    );
  }

  test('new device with no preference pulls remote without task writes',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var cloud = tagged('remote');
    var version = 4, writes = 0;
    final api = server(() => cloud, () => version, (lib, old) { writes++; });
    final result = await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true);
    expect(result, TaskActionMirrorResult.downloaded);
    expect((await store.load(prefs, owner)).serialize(), cloud.serialize());
    expect(TaskActionMirrorAnchor.read(prefs, owner)!.version, 4);
    expect(writes, 0);
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.unchanged);
  });

  test('offline-created rules upload safely once to empty cloud', () async {
    final prefs = await SharedPreferences.getInstance();
    final local = tagged('offline');
    await store.save(prefs, owner, local);
    var cloud = empty, version = 0, writes = 0;
    final api = server(() => cloud, () => version, (lib, old) {
      cloud = lib; version++; writes++;
    });
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.uploaded);
    expect(version, 1);
    expect(writes, 1);
    expect(cloud.serialize(), local.serialize());
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.unchanged);
    expect(writes, 1);
  });

  test('anchored local edits upload, remote edits pull, no feedback loop',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var cloud = tagged('one'), version = 1, writes = 0;
    await store.save(prefs, owner, cloud);
    final api = server(() => cloud, () => version, (lib, old) {
      cloud = lib; version++; writes++;
    });
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.unchanged);
    final changed = tagged('two');
    await store.save(prefs, owner, changed);
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.uploaded);
    expect(writes, 1);
    final fromOtherDevice = tagged('three');
    cloud = fromOtherDevice; version++;
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.downloaded);
    expect((await store.load(prefs, owner)).serialize(),
      fromOtherDevice.serialize());
    expect(writes, 1);
  });

  test('both sides changed offline => explicit conflict without any writes',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final baseline = tagged('base');
    await store.save(prefs, owner, baseline);
    var cloud = baseline, version = 2, writes = 0;
    final api = server(() => cloud, () => version, (lib, old) { writes++; });
    await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true);
    final local = tagged('local');
    await store.save(prefs, owner, local);
    cloud = tagged('remote'); version++;
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.conflict);
    expect((await store.load(prefs, owner)).serialize(), local.serialize());
    expect(cloud.rules.single.value, 'remote');
    expect(TaskActionMirrorAnchor.read(prefs, owner)!.version, 2);
    expect(writes, 0);
  });

  test('no baseline and both sides nonempty never pick a winner', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(prefs, owner, tagged('first'));
    var cloud = tagged('second'), version = 5;
    final api = server(() => cloud, () => version, (_, __) {
      fail('unexpected upload');
    });
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.conflict);
    expect(TaskActionMirrorAnchor.read(prefs, owner), isNull);
  });

  test('explicit empty preference is never mistaken for a new device',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(prefs, owner, empty);
    var cloud = tagged('remote');
    final api = server(() => cloud, () => 3, (_, __) {
      fail('unexpected upload');
    });
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.conflict);
    expect((await store.load(prefs, owner)).rules, isEmpty);
  });

  test('account switch during network request does not alter preferences',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var active = true;
    final remote = tagged('other');
    final api = server(() => remote, () => 3, (_, __) {}, onRead: () {
      active = false;
    });
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => active),
      TaskActionMirrorResult.skipped);
    expect(prefs.containsKey(TaskActionStore.keyForOwner(owner)), isFalse);
    expect(TaskActionMirrorAnchor.read(prefs, owner), isNull);
  });

  test('local edits during GET are never silently overwritten',
      () async {
    final prefs = await SharedPreferences.getInstance();
    var cloud = tagged('remote');
    final changed = tagged('new-local');
    final api = server(() => cloud, () => 3, (_, __) {},
        onRead: () {
          // Simulate an edit made while a cloud GET is outstanding.
          prefs.setString(TaskActionStore.keyForOwner(owner),
              changed.serialize());
        });
    expect(await mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      TaskActionMirrorResult.skipped);
    expect((await store.load(prefs, owner)).serialize(), changed.serialize());
  });

  test('corrupt anchor and corrupt rules fail closed without cleanup',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final api = server(() => empty, () => 0, (_, __) {});
    final anchorKey = TaskActionMirrorAnchor.keyForOwner(owner);
    await prefs.setString(anchorKey, '{broken');
    await expectLater(mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      throwsFormatException);
    expect(prefs.getString(anchorKey), '{broken');
    await prefs.remove(anchorKey);
    await prefs.setString(TaskActionStore.keyForOwner(owner), '{bad');
    await expectLater(mirror.synchronize(preferences: prefs,
      owner: owner, api: api, ownerMatches: (_) async => true),
      throwsFormatException);
    expect(prefs.getString(TaskActionStore.keyForOwner(owner)), '{bad');
  });

  test('backend rollback fails closed without local changes', () async {
    final prefs = await SharedPreferences.getInstance();
    final baseline = tagged('base');
    await store.save(prefs, owner, baseline);
    var remote = baseline, version = 5;
    final api = server(() => remote, () => version, (_, __) {
      fail('unexpected upload');
    });
    await mirror.synchronize(preferences: prefs,
        owner: owner, api: api, ownerMatches: (_) async => true);
    version = 4; remote = tagged('old');
    expect(await mirror.synchronize(preferences: prefs,
        owner: owner, api: api, ownerMatches: (_) async => true),
        TaskActionMirrorResult.conflict);
    expect((await store.load(prefs, owner)).serialize(), baseline.serialize());
    expect(TaskActionMirrorAnchor.read(prefs, owner)?.version, 5);
  });

  test('same version with different remote catalog is a conflict', () async {
    final prefs = await SharedPreferences.getInstance();
    final baseline = tagged('base');
    await store.save(prefs, owner, baseline);
    var remote = baseline;
    final api = server(() => remote, () => 2, (_, __) {
      fail('unexpected upload');
    });
    await mirror.synchronize(preferences: prefs,
        owner: owner, api: api, ownerMatches: (_) async => true);
    remote = tagged('other');
    expect(await mirror.synchronize(preferences: prefs,
        owner: owner, api: api, ownerMatches: (_) async => true),
        TaskActionMirrorResult.conflict);
    expect((await store.load(prefs, owner)).serialize(), baseline.serialize());
  });

  test('upload requires incremented server revision', () async {
    final prefs = await SharedPreferences.getInstance();
    final local = tagged('offline');
    await store.save(prefs, owner, local);
    final api = TaskActionCloudApi(
      baseUrl: 'https://api.example.com',
      tokenProvider: () async => 'token',
      client: MockClient((request) async => http.Response(jsonEncode({
          'version': 0,
          'catalog': jsonDecode(
              (request.method == 'PUT' ? local : empty).serialize()),
        }), 200)),
    );
    await expectLater(mirror.synchronize(preferences: prefs,
        owner: owner, api: api, ownerMatches: (_) async => true),
        throwsFormatException);
    expect(TaskActionMirrorAnchor.read(prefs, owner), isNull);
  });

  test('manual resolution updates anchor only after user explicitly chooses',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = tagged('chosen');
    await mirror.acknowledgeManual(
      preferences: prefs, owner: owner,
      snapshot: TaskActionCloudSnapshot(version: 8, library: remote));
    final anchor = TaskActionMirrorAnchor.read(prefs, owner)!;
    expect(anchor.version, 8);
    expect(anchor.catalog.serialize(), remote.serialize());
    expect(TaskActionMirrorAnchor.keyForOwner(owner), isNot(contains(owner)));
  });
}
