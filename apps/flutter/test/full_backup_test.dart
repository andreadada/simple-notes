import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/full_backup.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/countdowns_model.dart';
import 'package:simple_notes/ui/habits_model.dart';
import 'package:simple_notes/ui/ics_calendar.dart';
import 'package:simple_notes/ui/pomodoro_model.dart';
import 'package:simple_notes/ui/theme_mode_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = 'google-account-A';
  const password = 'very-long-test-password-2026';
  final created = DateTime.utc(2026, 11, 3, 10);

  Future<AppDatabase> database() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.bindOwner(owner);
    await db.upsertList(LocalTaskList(
      id: 'list-1', title: 'Università', createdAt: created));
    await db.upsertTask(LocalTask(
      id: 'task-1', title: 'Esame 12/11', dueAt: null,
      completed: false, createdAt: created, listId: 'list-1'));
    await db.upsertNote(LocalNote(
      id: 'note-1', title: 'Appunti',
      body: 'SEGRETO-NOTA-2026', createdAt: created));
    await db.upsertNote(LocalNote(
      id: 'trash-1', title: 'Nel cestino',
      body: 'Nota cancellata', createdAt: created));
    await db.removeNote('trash-1');
    await db.putSetting('syncCursor', '91');
    await db.putSetting('lastSyncSuccessUtc',
        '2026-11-03T02:24:58.000Z');
    return db;
  }

  Future<FullBackupSnapshot> snapshot(AppDatabase db) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = FullBackupSource.preferenceKeys(owner);
    await prefs.setString(keys['pomodoro']!,
        const PomodoroState().serialize());
    await prefs.setString(keys['habits']!, HabitsState().serialize());
    await prefs.setString(keys['countdowns']!, CountdownsState().serialize());
    await prefs.setString(keys['ics']!, const IcsLibrary().serialize());
    await prefs.setString(ThemeModePreference.key, 'light');
    // Unrelated owner must never be copied, even if present on this device.
    await prefs.setString(FullBackupSource.preferenceKeys('other')['ics']!,
        'OTHER-ACCOUNT-SECRET');
    return const FullBackupSource().capture(
      database: db, preferences: prefs,
      ownerId: owner, now: created,
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('snapshot captures raw SQLite including tombstones, outbox, owner',
      () async {
    final db = await database();
    addTearDown(db.close);
    final before = await db.pendingCount();
    final captured = await snapshot(db);
    expect(captured.count('task_entries'), 1);
    expect(captured.count('task_list_entries'), 1);
    expect(captured.count('note_entries'), 2);
    expect(captured.count('pending_mutations'), before);
    expect(captured.count('sync_settings'), 3);
    final tombstones = captured.tables['note_entries']!
        .where((row) => row['id'] == 'trash-1').toList();
    expect(tombstones, hasLength(1));
    expect(tombstones.single['deleted_at'], isNotNull);
    expect(captured.tables['sync_settings']!.any(
      (row) => row['key'] == 'syncCursor' && row['value'] == '91'), isTrue);
    expect(captured.preferences.keys.toSet(),
        FullBackupSnapshot.preferenceNames);
    expect(captured.preferences['ics'],
        const IcsLibrary().serialize());
    expect(captured.toJson().toString(),
        isNot(contains('OTHER-ACCOUNT-SECRET')));
    expect(await db.pendingCount(), before);
    expect((await db.snapshot()).notes, hasLength(1));
    expect((await db.snapshot()).trashedNotes, hasLength(1));
  });

  test('encrypted backup verifies full contents and does not expose plaintext',
      () async {
    final db = await database();
    addTearDown(db.close);
    final captured = await snapshot(db);
    final codec = const FullBackupCodec();
    final file = await codec.encrypt(captured, password);
    expect(file.length, lessThan(FullBackupCodec.maxFileBytes));
    final raw = utf8.decode(file);
    expect(raw, contains('AES-256-GCM'));
    for (final secret in [owner, 'SEGRETO-NOTA-2026',
        password, 'syncCursor', 'simple_notes.ics']) {
      expect(raw, isNot(contains(secret)));
    }
    final checked = await codec.inspect(file,
        password: password, expectedOwnerId: owner);
    expect(checked.createdAtUtc, captured.createdAtUtc);
    expect(checked.count('note_entries'), 2);
    expect(checked.count('pending_mutations'),
        captured.count('pending_mutations'));
    expect(checked.preferences['theme'], 'light');
    expect(checked.toJson(), captured.toJson());
    expect(await db.pendingCount(), captured.count('pending_mutations'));
  });

  test('wrong password or owner cannot inspect a valid backup', () async {
    final db = await database();
    addTearDown(db.close);
    final file = await const FullBackupCodec().encrypt(
        await snapshot(db), password);
    await expectLater(const FullBackupCodec().inspect(file,
      password: 'wrong-password-long-enough',
      expectedOwnerId: owner), throwsFormatException);
    await expectLater(const FullBackupCodec().inspect(file,
      password: password, expectedOwnerId: 'other-google-account'),
        throwsFormatException);
    expect((await db.snapshot()).notes.single.body,
        'SEGRETO-NOTA-2026');
  });

  test('tampered authenticated header or ciphertext fails closed', () async {
    final db = await database();
    addTearDown(db.close);
    final file = await const FullBackupCodec().encrypt(
        await snapshot(db), password);
    final decoded = jsonDecode(utf8.decode(file)) as Map<String, dynamic>;
    decoded['cipher'] = 'AES-128-CBC';
    await expectLater(const FullBackupCodec().inspect(
      utf8.encode(jsonEncode(decoded)),
      password: password, expectedOwnerId: owner),
      throwsFormatException);
    decoded['cipher'] = 'AES-256-GCM';
    decoded['tag'] = base64Encode(List<int>.filled(16, 7));
    await expectLater(const FullBackupCodec().inspect(
      utf8.encode(jsonEncode(decoded)),
      password: password, expectedOwnerId: owner),
      throwsFormatException);
  });

  test('unsupported/future schema and unexpected columns or prefs fail',
      () async {
    final db = await database();
    addTearDown(db.close);
    final valid = (await snapshot(db)).toJson();
    for (final key in ['schema', 'sqliteSchema']) {
      final altered = Map<String, dynamic>.from(valid);
      altered[key] = 999;
      expect(() => FullBackupSnapshot.fromJson(altered),
          throwsFormatException);
    }
    final strange = Map<String, dynamic>.from(valid);
    strange['tables'] = {
      ...Map<String, dynamic>.from(valid['tables'] as Map),
      'new_future_secrets': [],
    };
    expect(() => FullBackupSnapshot.fromJson(strange),
        throwsFormatException);
    final wrong = Map<String, dynamic>.from(valid);
    wrong['preferences'] = {
      ...Map<String, dynamic>.from(valid['preferences'] as Map),
      'oauth_refresh_token': 'do-not-export',
    };
    expect(() => FullBackupSnapshot.fromJson(wrong),
        throwsFormatException);
    final changedOwner = Map<String, dynamic>.from(valid);
    changedOwner['ownerId'] = 'another-owner';
    expect(() => FullBackupSnapshot.fromJson(changedOwner),
        throwsFormatException);
  });

  test('read-only backup refuses unbound/wrong account and corrupt preferences',
      () async {
    final db = await database();
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();
    await expectLater(const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: 'different'),
      throwsStateError);
    await prefs.setString(FullBackupSource.preferenceKeys(owner)['ics']!,
        'malformed-private-calendar-data');
    await expectLater(const FullBackupSource().capture(
      database: db, preferences: prefs, ownerId: owner),
      throwsFormatException);
    expect((await db.snapshot()).notes.length, 1);
  });
}
