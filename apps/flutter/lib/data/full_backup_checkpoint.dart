import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:path/path.dart' as path;

import 'full_backup.dart';
import 'full_backup_restore_rehearsal.dart';

/// Storage contract for one *new* checkpoint. No method may replace a backup.
///
/// The caller must provide a dedicated directory. This API is not connected
/// to the running application's database, preferences, authentication or sync.
abstract class FullBackupCheckpointStore {
  Future<void> writeNew(List<int> encryptedBytes);
  Future<List<int>> readBack();
}

/// P2.4B2B1: opt-in checkpoint file writer for detached preflight only.
///
/// This class is not wired to any UI, production startup or live restore.
/// A temporary file is flushed then renamed within the same directory.
/// Full crash durability (including directory fsync), ZIP/MSIX migration and
/// cross-store rollback require separate platform verification before use.
class FileFullBackupCheckpointStore implements FullBackupCheckpointStore {
  FileFullBackupCheckpointStore(this.directory)
      : checkpointId = _randomHex(24);

  final Directory directory;
  final String checkpointId;

  File get file => File(path.join(
      directory.path, 'simple-notes-checkpoint-$checkpointId.snb'));

  static String _randomHex(int byteCount) {
    final random = Random.secure();
    return List.generate(byteCount, (_) =>
        random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<void> writeNew(List<int> encryptedBytes) async {
    if (encryptedBytes.isEmpty ||
        encryptedBytes.length > FullBackupCodec.maxFileBytes) {
      throw const FormatException('Dimensioni checkpoint non valide.');
    }
    await directory.create(recursive: true);
    if (await file.exists()) {
      throw StateError('Checkpoint già esistente: non sovrascrivere.');
    }
    final temporary = File(path.join(directory.path,
        '.checkpoint-$checkpointId-${_randomHex(8)}.tmp'));
    await temporary.create(exclusive: true);
    try {
      await temporary.writeAsBytes(encryptedBytes, flush: true);
      // A fresh, random checkpointId must never replace an existing file.
      if (await file.exists()) {
        throw StateError('Checkpoint già esistente: non sovrascrivere.');
      }
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<List<int>> readBack() async {
    if (!await file.exists() ||
        await file.length() > FullBackupCodec.maxFileBytes) {
      throw const FormatException('Checkpoint assente o troppo grande.');
    }
    return file.readAsBytes();
  }
}

/// Verifies the current profile can be checkpointed and reconstructed *before*
/// any future restore attempt. No installed SQLite or SharedPreferences writes.
class FullBackupCheckpointPreflight {
  const FullBackupCheckpointPreflight();

  Future<FullBackupCheckpointReceipt> prepare({
    required FullBackupSnapshot current,
    required String expectedOwnerId,
    required String password,
    required FullBackupCheckpointStore store,
  }) async {
    current.validate();
    if (expectedOwnerId.isEmpty || current.ownerId != expectedOwnerId) {
      throw const FormatException('Checkpoint di un account differente.');
    }

    final codec = const FullBackupCodec();
    final encoded = await codec.encrypt(current, password);
    await store.writeNew(encoded);
    final readBack = await store.readBack();
    final before = hash.sha256.convert(encoded).toString();
    final after = hash.sha256.convert(readBack).toString();
    if (before != after) {
      throw const FormatException('Checkpoint scritto in modo incompleto.');
    }

    // Authentication and comparison both happen after read-back from storage.
    final reopened = await codec.inspect(
      readBack, password: password, expectedOwnerId: expectedOwnerId,
    );
    if (jsonEncode(reopened.toJson()) != jsonEncode(current.toJson())) {
      throw const FormatException('Checkpoint incoerente con il profilo.');
    }

    // Demonstrate that the *checkpoint*, not merely the original in-memory
    // object, round-trips through every SQLite table in a separate DB.
    final rehearsal = await const FullBackupRestoreRehearsal().verify(
      encryptedBytes: readBack, password: password,
      expectedOwnerId: expectedOwnerId,
    );
    if (rehearsal.automaticSyncAuthorized) {
      throw StateError('Riaccredito sync non consentito.');
    }
    return FullBackupCheckpointReceipt(
      checksumSha256: after,
      bytes: readBack.length,
      rowCounts: Map.unmodifiable(rehearsal.rowsByTable),
      createdAtUtc: reopened.createdAtUtc,
    );
  }
}

class FullBackupCheckpointReceipt {
  const FullBackupCheckpointReceipt({
    required this.checksumSha256,
    required this.bytes,
    required this.rowCounts,
    required this.createdAtUtc,
  });

  final String checksumSha256;
  final int bytes;
  final Map<String, int> rowCounts;
  final DateTime createdAtUtc;

  /// A verified checkpoint never by itself permits live restore or replay.
  bool get liveRestoreAuthorized => false;
  bool get automaticSyncAuthorized => false;
}
