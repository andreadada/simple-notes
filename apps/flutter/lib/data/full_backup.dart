import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/countdowns_model.dart';
import '../ui/habits_model.dart';
import '../ui/ics_calendar.dart';
import '../ui/pomodoro_model.dart';
import '../ui/theme_mode_preference.dart';
import 'app_database.dart';
import 'user_task_templates.dart';
import 'reminder_automations.dart';

/// P2.4B1: encrypted, owner-bound *read-only* complete profile archive.
/// Import is deliberately PREVIEW ONLY until cold-start restore guards exist.
class FullBackupSnapshot {
  const FullBackupSnapshot({
    required this.ownerId,
    required this.createdAtUtc,
    required this.tables,
    required this.preferences,
  });

  static const format = 'simple-notes-full-backup';
  static const schema = 1;
  static const sqliteSchema = 8;

  // Explicit table/column allowlist: fail closed if Drift schema evolves.
  // In particular, do not silently back up an unknown future secret column.
  static const columns = <String, List<String>>{
    'task_entries': [
      'id', 'title', 'description', 'list_id', 'priority',
      'tags_json', 'subtasks_json', 'due_at', 'due_kind', 'due_date',
      'due_time', 'due_timezone', 'due_offset_seconds',
      'block_start_at', 'block_end_at', 'block_timezone',
      'blocks_json', 'recurrence_json', 'completed', 'created_at',
      'remote_version', 'deleted_at',
    ],
    'task_list_entries': [
      'id', 'title', 'created_at', 'remote_version', 'deleted_at',
    ],
    'note_entries': [
      'id', 'title', 'body', 'created_at', 'remote_version', 'deleted_at',
    ],
    'pending_mutations': [
      'operation_id', 'entity_type', 'entity_id', 'action', 'payload',
      'created_at',
    ],
    'sync_settings': ['key', 'value'],
  };
  static const allowedSettings = <String>{
    'boundOwnerId', 'syncCursor', 'lastSyncSuccessUtc',
  };
  // Required v1 fields stay stable. New, optional domain preferences are
  // backward-compatible: older encrypted v1 backups remain inspectable.
  static const requiredPreferenceNames = <String>{
    'ics', 'pomodoro', 'habits', 'countdowns', 'theme',
  };
  static const preferenceNames = <String>{
    ...requiredPreferenceNames, 'templates', 'automations',
  };

  final String ownerId;
  final DateTime createdAtUtc;
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, String?> preferences;

  int count(String table) => tables[table]?.length ?? 0;

  Map<String, dynamic> toJson() => {
    'format': format,
    'schema': schema,
    'sqliteSchema': sqliteSchema,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'ownerId': ownerId,
    'tables': tables,
    'preferences': preferences,
  };

  /// Refuse unknown tables/columns/keys, duplicates, invalid stored JSON,
  /// incorrect owner binding, or malformed owner-specific preference blobs.
  void validate() {
    if (ownerId.isEmpty || ownerId.length > 1024 ||
        !createdAtUtc.isUtc ||
        tables.keys.toSet().length != columns.length ||
        !tables.keys.toSet().containsAll(columns.keys) ||
        !preferences.keys.toSet().containsAll(requiredPreferenceNames) ||
        preferences.keys.any((name) => !preferenceNames.contains(name))) {
      throw const FormatException('Archivio non compatibile.');
    }
    var total = 0;
    for (final entry in columns.entries) {
      final rows = tables[entry.key]!;
      if (rows.length > 100000) {
        throw const FormatException('Numero record del backup non valido.');
      }
      total += rows.length;
      final ids = <String>{};
      for (final row in rows) {
        if (row.keys.length != entry.value.length ||
            !row.keys.toSet().containsAll(entry.value) ||
            row.values.any((v) =>
                v != null && v is! String && v is! int &&
                v is! double && v is! bool)) {
          throw const FormatException('Colonne SQLite non compatibili.');
        }
        final key = entry.key == 'pending_mutations'
            ? row['operation_id']
            : entry.key == 'sync_settings' ? row['key'] : row['id'];
        if (key is! String || key.isEmpty || !ids.add(key)) {
          throw const FormatException('Chiave record SQLite non valida.');
        }
        if (entry.key == 'sync_settings' &&
            !allowedSettings.contains(key)) {
          throw const FormatException('Nuova preferenza sync non supportata.');
        }
        if (entry.key == 'pending_mutations') {
          if (!const {'list', 'task', 'note'}.contains(row['entity_type']) ||
              !const {'upsert', 'delete', 'restore'}.contains(row['action']) ||
              row['entity_id'] is! String || row['payload'] is! String) {
            throw const FormatException('Operazione in coda non valida.');
          }
          jsonDecode(row['payload'] as String);
        }
      }
    }
    if (total > 250000) {
      throw const FormatException('Backup con troppe righe.');
    }
    final owners = tables['sync_settings']!
        .where((row) => row['key'] == 'boundOwnerId').toList();
    if (owners.length != 1 || owners.single['value'] != ownerId) {
      throw const FormatException('Account del backup incoerente.');
    }
    for (final name in preferenceNames) {
      final value = preferences[name];
      if (value == null) continue;
      if (value.length > 8 * 1024 * 1024) {
        throw const FormatException('Preferenza troppo grande nel backup.');
      }
      switch (name) {
        case 'ics':
          IcsLibrary.deserialize(value);
        case 'pomodoro':
          PomodoroState.deserialize(value);
        case 'habits':
          HabitsState.deserialize(value);
        case 'countdowns':
          CountdownsState.deserialize(value);
        case 'theme':
          if (!const {'dark', 'light', 'system'}.contains(value)) {
            throw const FormatException('Preferenza tema non valida.');
          }
        case 'templates':
          UserTaskTemplateLibrary.deserialize(value);
        case 'automations':
          ReminderAutomationLibrary.deserialize(value);
      }
    }
  }

  factory FullBackupSnapshot.fromJson(Map<String, dynamic> source) {
    if (source.length != 7 ||
        source['format'] != format || source['schema'] != schema ||
        source['sqliteSchema'] != sqliteSchema ||
        source['ownerId'] is! String ||
        source['createdAtUtc'] is! String ||
        source['tables'] is! Map ||
        source['preferences'] is! Map) {
      throw const FormatException('Formato di backup non supportato.');
    }
    final stamp = DateTime.parse(source['createdAtUtc'] as String);
    if (!stamp.isUtc) {
      throw const FormatException('Data backup non UTC.');
    }
    final rawTables = Map<String, dynamic>.from(source['tables'] as Map);
    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in rawTables.entries) {
      if (entry.value is! List) {
        throw const FormatException('Tabella backup non valida.');
      }
      tables[entry.key] = [
        for (final row in entry.value as List)
          Map<String, Object?>.from(row as Map),
      ];
    }
    final preferences = <String, String?>{};
    for (final entry in (source['preferences'] as Map).entries) {
      if (entry.key is! String ||
          entry.value != null && entry.value is! String) {
        throw const FormatException('Preferenza del backup non valida.');
      }
      preferences[entry.key as String] = entry.value as String?;
    }
    final snapshot = FullBackupSnapshot(
      ownerId: source['ownerId'] as String,
      createdAtUtc: stamp,
      tables: tables,
      preferences: preferences,
    );
    snapshot.validate();
    return snapshot;
  }
}

class FullBackupSource {
  const FullBackupSource();

  static Map<String, String> preferenceKeys(String ownerId) {
    final digest = hash.sha256.convert(utf8.encode(ownerId));
    final suffix = digest.toString();
    return {
      'ics': icsOwnerKey(ownerId),
      'pomodoro': 'simple_notes.pomodoro.v1.$suffix',
      'habits': 'simple_notes.habits.v1.$suffix',
      'countdowns': 'simple_notes.countdowns.v1.$suffix',
      'theme': ThemeModePreference.key,
      'templates': UserTaskTemplateStore.keyForOwner(ownerId),
      'automations': ReminderAutomationStore.keyForOwner(ownerId),
    };
  }

  /// No modification: one SQLite transaction + owner-scoped preference reads.
  /// SharedPreferences is not transactional with SQLite; no live restore
  /// should assume this is a perfectly simultaneous cross-store snapshot.
  Future<FullBackupSnapshot> capture({
    required AppDatabase database,
    required SharedPreferences preferences,
    required String ownerId,
    DateTime? now,
  }) async {
    if (ownerId.isEmpty) {
      throw StateError('Accedi con Google prima di creare il backup.');
    }
    final rows = await database.fullBackupRows(ownerId);
    final prefs = <String, String?>{};
    for (final entry in preferenceKeys(ownerId).entries) {
      final raw = preferences.get(entry.value);
      if (raw != null && raw is! String) {
        throw const FormatException('Preferenze del dispositivo non leggibili.');
      }
      prefs[entry.key] = raw as String?;
    }
    final snapshot = FullBackupSnapshot(
      ownerId: ownerId,
      createdAtUtc: (now ?? DateTime.now()).toUtc(),
      tables: rows,
      preferences: prefs,
    );
    snapshot.validate();
    return snapshot;
  }
}

/// Password encryption: AES-256-GCM with authenticated header (AAD) and
/// PBKDF2-HMAC-SHA256. No password, owner ID, or contents appear in header.
class FullBackupCodec {
  const FullBackupCodec();

  static const maxPlainBytes = 16 * 1024 * 1024;
  static const maxFileBytes = 25 * 1024 * 1024;
  static const iterations = 180000;
  static const _aad = 'simple-notes-full-backup/v1';

  static void _password(String password) {
    if (password.trim().length < 12 || password.length > 256) {
      throw const FormatException('Usa una password di almeno 12 caratteri.');
    }
  }

  static List<int> _random(int count) {
    final source = Random.secure();
    return List<int>.generate(count, (_) => source.nextInt(256));
  }

  static Future<SecretKey> _key(String password, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
          .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<List<int>> encrypt(FullBackupSnapshot source, String password) async {
    _password(password);
    source.validate();
    final plain = utf8.encode(jsonEncode(source.toJson()));
    if (plain.length > maxPlainBytes) {
      throw const FormatException('Backup troppo grande (16 MB massimo).');
    }
    final salt = _random(16);
    final nonce = _random(12);
    final key = await _key(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      plain, secretKey: key, nonce: nonce, aad: utf8.encode(_aad),
    );
    final envelope = {
      'format': FullBackupSnapshot.format,
      'schema': FullBackupSnapshot.schema,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
    final output = utf8.encode(jsonEncode(envelope));
    if (output.length > maxFileBytes) {
      throw const FormatException('Backup cifrato troppo grande.');
    }
    return output;
  }

  /// Password + authenticated decryption + full schema + same-owner preview.
  /// Never writes SQLite, SharedPreferences, OAuth or the sync outbox.
  Future<FullBackupSnapshot> inspect(
    List<int> bytes, {
    required String password,
    required String expectedOwnerId,
  }) async {
    if (bytes.isEmpty || bytes.length > maxFileBytes ||
        expectedOwnerId.isEmpty || password.isEmpty) {
      throw const FormatException('File di backup non valido.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> || decoded.length != 9 ||
          decoded['format'] != FullBackupSnapshot.format ||
          decoded['schema'] != FullBackupSnapshot.schema ||
          decoded['cipher'] != 'AES-256-GCM' ||
          decoded['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          decoded['iterations'] != iterations) {
        throw const FormatException('Versione di backup non supportata.');
      }
      final salt = base64Decode(decoded['salt'] as String);
      final nonce = base64Decode(decoded['nonce'] as String);
      final tag = base64Decode(decoded['tag'] as String);
      final encrypted = base64Decode(decoded['ciphertext'] as String);
      if (salt.length != 16 || nonce.length != 12 || tag.length != 16 ||
          encrypted.isEmpty || encrypted.length > maxPlainBytes) {
        throw const FormatException('Parametri backup non validi.');
      }
      final key = await _key(password, salt);
      final plain = await AesGcm.with256bits().decrypt(
        SecretBox(encrypted, nonce: nonce, mac: Mac(tag)),
        secretKey: key, aad: utf8.encode(_aad),
      );
      final data = jsonDecode(utf8.decode(plain));
      final snapshot = FullBackupSnapshot.fromJson(
          Map<String, dynamic>.from(data as Map));
      if (snapshot.ownerId != expectedOwnerId) {
        throw const FormatException('Backup di un account diverso.');
      }
      return snapshot;
    } catch (_) {
      // Do not reveal decrypted content or distinguish wrong password
      // from corrupted ciphertext in user-facing errors.
      throw const FormatException(
        'Password errata, backup non valido o account differente. '
        'Nessun dato è stato modificato.');
    }
  }
}
