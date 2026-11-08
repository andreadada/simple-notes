import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import 'full_backup.dart';
import 'full_backup_rollback_rehearsal.dart';

/// B2C: detached cold-start simulation. Never connected to production startup.
enum RestorePhase { prepared, staging, verifying, recoveryRequired, rollbackVerified }

class RestoreMarker {
  const RestoreMarker(this.sequence, this.phase, this.ownerHash,
      this.checkpointHash, this.targetHash);

  final int sequence;
  final RestorePhase phase;
  final String ownerHash;
  final String checkpointHash;
  final String targetHash;

  Map<String, Object> toJson() => {
    'schema': 1, 'sequence': sequence, 'phase': phase.name,
    'ownerHash': ownerHash, 'checkpointHash': checkpointHash,
    'targetHash': targetHash,
  };

  factory RestoreMarker.fromJson(Object? source) {
    if (source is! Map<String, dynamic> || source.length != 6 ||
        source['schema'] != 1 || source['sequence'] is! int ||
        source['phase'] is! String || source['ownerHash'] is! String ||
        source['checkpointHash'] is! String ||
        source['targetHash'] is! String) {
      throw const FormatException('Registro di recupero non valido.');
    }
    final phases = RestorePhase.values
        .where((phase) => phase.name == source['phase']).toList();
    final validHash = RegExp(r'^[a-f0-9]{64}$');
    final number = source['sequence'] as int;
    if (number < 0 || number > 12 || phases.length != 1 ||
        !validHash.hasMatch(source['ownerHash'] as String) ||
        !validHash.hasMatch(source['checkpointHash'] as String) ||
        !validHash.hasMatch(source['targetHash'] as String)) {
      throw const FormatException('Registro di recupero incoerente.');
    }
    return RestoreMarker(number, phases.single,
        source['ownerHash'] as String, source['checkpointHash'] as String,
        source['targetHash'] as String);
  }

  RestoreMarker next(RestorePhase phase) => RestoreMarker(
      sequence + 1, phase, ownerHash, checkpointHash, targetHash);
}

/// A deliberately single-writer, append-only journal in an EXPLICIT test
/// directory. Does not guarantee directory fsync or cross-process locking.
/// Any torn/orphan marker, unknown file, gap or invalid transition FAILS CLOSED.
/// The journal contains only hashes/phases, never credentials or note contents.
class FileRestoreJournal {
  const FileRestoreJournal(this.directory);

  final Directory directory;

  static String _name(int sequence) {
    final padded = sequence.toString().padLeft(3, '0');
    return 'recovery-$padded.json';
  }

  static bool _allowed(RestorePhase old, RestorePhase next) =>
      switch (old) {
        RestorePhase.prepared =>
          next == RestorePhase.staging ||
              next == RestorePhase.recoveryRequired,
        RestorePhase.staging =>
          next == RestorePhase.verifying ||
              next == RestorePhase.recoveryRequired,
        RestorePhase.verifying => next == RestorePhase.recoveryRequired,
        RestorePhase.recoveryRequired => next == RestorePhase.rollbackVerified,
        RestorePhase.rollbackVerified => false,
      };

  Future<RestoreMarker?> read() async {
    final kind = await FileSystemEntity.type(
      directory.path, followLinks: false,
    );
    if (kind == FileSystemEntityType.notFound) return null;
    if (kind != FileSystemEntityType.directory) {
      throw const FormatException('Directory journal non regolare.');
    }
    final entries = await directory.list(followLinks: false).toList();
    if (entries.isEmpty) return null;
    if (entries.length > 13 || entries.any((entry) =>
        entry is! File ||
        !RegExp(r'^recovery-\d{3}\.json$')
            .hasMatch(path.basename(entry.path)))) {
      throw const FormatException('Registro incompleto o sospetto.');
    }
    entries.sort((a, b) => path.basename(a.path)
        .compareTo(path.basename(b.path)));
    RestoreMarker? previous;
    for (var i = 0; i < entries.length; i++) {
      final file = File(entries[i].path);
      if (path.basename(file.path) != _name(i) ||
          await file.length() > 4096) {
        throw const FormatException('Sequenza recovery non valida.');
      }
      final marker = RestoreMarker.fromJson(
          jsonDecode(await file.readAsString()));
      if (marker.sequence != i) {
        throw const FormatException('Contatore recovery non valido.');
      }
      if (previous == null) {
        if (marker.phase != RestorePhase.prepared) {
          throw const FormatException('Fase iniziale non valida.');
        }
      } else if (previous.ownerHash != marker.ownerHash ||
          previous.checkpointHash != marker.checkpointHash ||
          previous.targetHash != marker.targetHash ||
          !_allowed(previous.phase, marker.phase)) {
        throw const FormatException('Transizione recovery non valida.');
      }
      previous = marker;
    }
    return previous;
  }

  Future<void> append(RestoreMarker marker) async {
    final initialType = await FileSystemEntity.type(
      directory.path, followLinks: false,
    );
    if (initialType != FileSystemEntityType.notFound &&
        initialType != FileSystemEntityType.directory) {
      throw const FormatException('Directory journal non regolare.');
    }
    await directory.create(recursive: true);
    if (await FileSystemEntity.type(
          directory.path, followLinks: false,
        ) != FileSystemEntityType.directory) {
      throw const FormatException('Directory journal sostituita.');
    }
    final previous = await read();
    if (previous == null) {
      if (marker.sequence != 0 || marker.phase != RestorePhase.prepared) {
        throw StateError('Il registro deve iniziare in prepared.');
      }
    } else if (marker.sequence != previous.sequence + 1 ||
        marker.ownerHash != previous.ownerHash ||
        marker.checkpointHash != previous.checkpointHash ||
        marker.targetHash != previous.targetHash ||
        !_allowed(previous.phase, marker.phase)) {
      throw StateError('Avanzamento recovery non autorizzato.');
    }
    final name = _name(marker.sequence);
    final destination = File(path.join(directory.path, name));
    if (await destination.exists()) {
      throw StateError('Mai sovrascrivere il registro.');
    }
    final temporary = File(path.join(directory.path, '.$name.tmp'));
    await temporary.create(exclusive: true);
    try {
      await temporary.writeAsString(jsonEncode(marker.toJson()), flush: true);
      if (await destination.exists()) {
        throw StateError('Registro già esistente.');
      }
      await temporary.rename(destination.path);
      // Fresh read-back catches unexpected content and invalid sequences
      // immediately; it does NOT guarantee parent-directory fsync.
      final verified = await read();
      if (verified == null ||
          verified.sequence != marker.sequence ||
          verified.phase != marker.phase ||
          verified.ownerHash != marker.ownerHash ||
          verified.checkpointHash != marker.checkpointHash ||
          verified.targetHash != marker.targetHash) {
        throw const FormatException('Registro recovery non verificabile.');
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

/// A restored outbox is never replayed by this flow, even if both cursors
/// match. The cloud requires a separate future reconciliation procedure.
class RestoreReplayRisk {
  const RestoreReplayRisk(this.importedOutbox, this.savedOutbox,
      this.sharedOperationIds, this.cursorRegressedOrUnknown);

  final int importedOutbox;
  final int savedOutbox;
  final int sharedOperationIds;
  final bool cursorRegressedOrUnknown;

  bool get importedOutboxQuarantined => true;
  bool get importedCursorTrusted => false;
  bool get needsRemoteReconciliation => true;
  bool get automaticSyncAuthorized => false;

  static RestoreReplayRisk assess(
      FullBackupSnapshot saved, FullBackupSnapshot target) {
    final old = saved.tables['pending_mutations']!
        .map((row) => row['operation_id'] as String).toSet();
    final incoming = target.tables['pending_mutations']!
        .map((row) => row['operation_id'] as String).toSet();
    int? cursor(FullBackupSnapshot snapshot) {
      for (final row in snapshot.tables['sync_settings']!) {
        if (row['key'] == 'syncCursor') {
          final value = int.tryParse(row['value'] as String);
          return value != null && value >= 0 ? value : null;
        }
      }
      return null;
    }
    final before = cursor(saved);
    final after = cursor(target);
    return RestoreReplayRisk(incoming.length, old.length,
        old.intersection(incoming).length,
        before == null || after == null || after < before);
  }
}

class RestoreColdStartReport {
  const RestoreColdStartReport(this.phase, this.risk,
      this.sandboxRollbackVerified);

  final RestorePhase? phase;
  final RestoreReplayRisk? risk;
  final bool sandboxRollbackVerified;

  bool get recoveryPending =>
      phase != null && phase != RestorePhase.rollbackVerified;
  bool get liveRestoreAuthorized => false;
  bool get automaticSyncAuthorized => false;
}

/// Simulates a new process by reconstructing the coordinator over the same
/// dedicated journal directory. Never receives installed app data paths.
class FullBackupColdStartGuard {
  const FullBackupColdStartGuard(this.journal);

  final FileRestoreJournal journal;

  static String _hash(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();

  static String _ownerHash(String id) =>
      _hash(utf8.encode('simple-notes-recovery/v1:$id'));

  Future<RestoreColdStartReport> prepare({
    required List<int> checkpointBytes,
    required String checkpointPassword,
    required List<int> targetBytes,
    required String targetPassword,
    required String expectedOwnerId,
  }) async {
    if (await journal.read() != null) {
      throw StateError('Esiste già un registro di recovery.');
    }
    final codec = const FullBackupCodec();
    final saved = await codec.inspect(checkpointBytes,
        password: checkpointPassword, expectedOwnerId: expectedOwnerId);
    final target = await codec.inspect(targetBytes,
        password: targetPassword, expectedOwnerId: expectedOwnerId);
    final risk = RestoreReplayRisk.assess(saved, target);
    await journal.append(RestoreMarker(0, RestorePhase.prepared,
        _ownerHash(expectedOwnerId), _hash(checkpointBytes),
        _hash(targetBytes)));
    return RestoreColdStartReport(RestorePhase.prepared, risk, false);
  }

  Future<void> simulateNext(RestorePhase phase) async {
    final current = await journal.read();
    if (current == null) throw StateError('Preflight inesistente.');
    await journal.append(current.next(phase));
  }

  Future<RestoreColdStartReport> recover({
    required List<int> checkpointBytes,
    required String checkpointPassword,
    required List<int> targetBytes,
    required String targetPassword,
    required String expectedOwnerId,
    Future<void> Function(String phase)? injectCrash,
  }) async {
    var marker = await journal.read();
    if (marker == null) {
      return const RestoreColdStartReport(null, null, false);
    }
    if (marker.ownerHash != _ownerHash(expectedOwnerId) ||
        marker.checkpointHash != _hash(checkpointBytes) ||
        marker.targetHash != _hash(targetBytes)) {
      throw const FormatException('Account o backup cambiato durante il recovery.');
    }
    final codec = const FullBackupCodec();
    final saved = await codec.inspect(checkpointBytes,
        password: checkpointPassword, expectedOwnerId: expectedOwnerId);
    final target = await codec.inspect(targetBytes,
        password: targetPassword, expectedOwnerId: expectedOwnerId);
    final risk = RestoreReplayRisk.assess(saved, target);

    if (marker.phase != RestorePhase.rollbackVerified) {
      if (marker.phase != RestorePhase.recoveryRequired) {
        await journal.append(marker.next(RestorePhase.recoveryRequired));
        marker = (await journal.read())!;
        if (injectCrash != null) await injectCrash('recovery-required');
      }

      final proof = await const FullBackupRollbackRehearsal().verify(
        currentCheckpointBytes: checkpointBytes,
        currentCheckpointPassword: checkpointPassword,
        targetBackupBytes: targetBytes,
        targetBackupPassword: targetPassword,
        expectedOwnerId: expectedOwnerId,
      );
      if (!proof.rollbackVerified || proof.automaticSyncAuthorized) {
        throw StateError('Prova di rollback non valida.');
      }
      await journal.append(marker.next(RestorePhase.rollbackVerified));
      if (injectCrash != null) await injectCrash('rollback-verified');
    }
    return RestoreColdStartReport(
        RestorePhase.rollbackVerified, risk, true);
  }
}
