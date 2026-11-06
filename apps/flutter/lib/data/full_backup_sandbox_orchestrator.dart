import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import 'full_backup.dart';
import 'full_backup_disk_recovery_rehearsal.dart';

/// P2.4B2U: a deliberately *test-only* confirmation for a disposable
/// filesystem rehearsal. It does NOT grant permission to restore a profile.
/// Never persist, transmit, display or log this object or its fingerprints.
class SandboxRestoreConsent {
  SandboxRestoreConsent._(
    this._ownerDigest,
    this._checkpointDigest,
    this._targetDigest,
  );

  static const confirmationPhrase = 'SIMULA RIPRISTINO';

  final String _ownerDigest;
  final String _checkpointDigest;
  final String _targetDigest;
  bool _consumed = false;

  static String _digest(List<int> input) =>
      crypto.sha256.convert(input).toString();

  static String _owner(String id) =>
      _digest(utf8.encode('simple-notes-sandbox-consent/v1:$id'));

  /// Opt-in is intentionally separate from the dry-run review receipt.
  /// Neither a correct phrase nor a completed review enables live restore.
  static SandboxRestoreConsent confirm({
    required String ownerId,
    required List<int> checkpointBytes,
    required List<int> targetBytes,
    required String typedConfirmation,
    required bool understandsLocalReplacement,
    required bool understandsImportedOutboxQuarantine,
  }) {
    if (ownerId.isEmpty ||
        ownerId.length > 1024 ||
        typedConfirmation != confirmationPhrase ||
        !understandsLocalReplacement ||
        !understandsImportedOutboxQuarantine ||
        !_validBytes(checkpointBytes) ||
        !_validBytes(targetBytes)) {
      throw const FormatException('Conferma sandbox mancante o non valida.');
    }
    return SandboxRestoreConsent._(
      _owner(ownerId),
      _digest(checkpointBytes),
      _digest(targetBytes),
    );
  }

  static bool _validBytes(List<int> bytes) =>
      bytes.isNotEmpty && bytes.length <= FullBackupCodec.maxFileBytes;

  void _consume({
    required String expectedOwnerId,
    required List<int> checkpointBytes,
    required List<int> targetBytes,
  }) {
    if (_consumed ||
        _ownerDigest != _owner(expectedOwnerId) ||
        _checkpointDigest != _digest(checkpointBytes) ||
        _targetDigest != _digest(targetBytes) ||
        !_validBytes(checkpointBytes) ||
        !_validBytes(targetBytes)) {
      throw const FormatException(
          'Conferma già utilizzata o archivi/account cambiati.');
    }
    // Burn BEFORE any sandbox checkpoint, SQLite or journal write, even when\n    // subsequent authenticated preflight fails.
    _consumed = true;
  }

  bool get canRestoreLive => false;
  bool get canWriteCloud => false;
  bool get canReplayImportedOutbox => false;
  bool get canResumeAutoSync => false;
}

/// A content-free receipt from the verified sandbox rollback. The target
/// snapshot and its pending mutations are NEVER promoted to an installed app.
class SandboxRestoreOutcome {
  const SandboxRestoreOutcome._(this.rowCounts);

  final Map<String, int> rowCounts;

  bool get sandboxRollbackVerified => true;
  bool get installedProfileChanged => false;
  bool get importedOutboxQuarantined => true;
  bool get canRestoreLive => false;
  bool get canWriteCloud => false;
  bool get canReplayImportedOutbox => false;
  bool get canResumeAutoSync => false;
}

/// A one-way orchestration of prepare -> stage -> cold-start compensation.
///
/// The sole constructor uses DiskRestoreRehearsal.create(), which allocates
/// its own OS temporary directory. Never accept a caller-provided path or
/// the installed app's SQLite/SharedPreferences. This class is NOT imported
/// by main.dart, startup, OAuth or CloudSync.
///
/// File flush/rename here does not provide a directory fsync or a real
/// cross-process exclusion guarantee; therefore NO production restore.
class SandboxRestoreOrchestrator {
  SandboxRestoreOrchestrator._(this._sandbox);

  final DiskRestoreRehearsal _sandbox;

  static Future<SandboxRestoreOrchestrator> create() async =>
      SandboxRestoreOrchestrator._(await DiskRestoreRehearsal.create());

  /// Only for assertions in tests. This path is never chosen by the caller.
  Directory get temporaryDirectoryForTest => _sandbox.directory;

  SandboxRestoreOrchestrator coldStartForTest() =>
      SandboxRestoreOrchestrator._(_sandbox.coldStart());

  Future<SandboxRestoreOutcome> run({
    required String expectedOwnerId,
    required List<int> checkpointBytes,
    required String checkpointPassword,
    required List<int> targetBytes,
    required String targetPassword,
    required SandboxRestoreConsent? consent,
    Future<void> Function(String stage)? injectCrash,
  }) async {
    if (consent == null ||
        !SandboxRestoreConsent._validBytes(checkpointBytes) ||
        !SandboxRestoreConsent._validBytes(targetBytes)) {
      throw const FormatException('Conferma o archivi sandbox non validi.');
    }
    // Capture immutable copies synchronously, BEFORE the first await: a
    // caller-owned List<int> must not mutate the approved ciphertext while
    // AES-GCM verification or disk preflight is in progress.
    final checkpointCopy = List<int>.unmodifiable(checkpointBytes);
    final targetCopy = List<int>.unmodifiable(targetBytes);
    consent._consume(
      expectedOwnerId: expectedOwnerId,
      checkpointBytes: checkpointCopy,
      targetBytes: targetCopy,
    );
    // Both AES-GCM archives must authenticate as the same owner BEFORE any
    // SQLite or preferences writes. All subsequent stores are disposable.
    await _sandbox.prepare(
      checkpointBytes: checkpointCopy,
      checkpointPassword: checkpointPassword,
      targetBytes: targetCopy,
      targetPassword: targetPassword,
      expectedOwnerId: expectedOwnerId,
    );
    // Fault injection propagates; only an explicit new process simulation
    // can resume compensating after an interrupted SQLite/prefs write.
    await _sandbox.applyTargetForTest(
      expectedOwnerId: expectedOwnerId,
      targetPassword: targetPassword,
      injectCrash: injectCrash,
    );
    return recoverAfterColdStart(
      expectedOwnerId: expectedOwnerId,
      checkpointPassword: checkpointPassword,
      targetPassword: targetPassword,
    );
  }

  /// Crash recovery must not require a second consent: the staging journal
  /// exists already and must be compensated before any other operations.
  /// This NEVER resumes normal sync, even after a successful rollback.
  Future<SandboxRestoreOutcome> recoverAfterColdStart({
    required String expectedOwnerId,
    required String checkpointPassword,
    required String targetPassword,
    Future<void> Function(String stage)? injectCrash,
  }) async {
    final receipt = await _sandbox.coldStart().recover(
      expectedOwnerId: expectedOwnerId,
      checkpointPassword: checkpointPassword,
      targetPassword: targetPassword,
      injectCrash: injectCrash,
    );
    if (!receipt.rollbackVerifiedOnDisk ||
        receipt.liveRestoreAuthorized ||
        receipt.automaticSyncAuthorized ||
        !receipt.importedOutboxQuarantined) {
      throw StateError('Rollback sandbox non verificato.');
    }
    return SandboxRestoreOutcome._(Map.unmodifiable(receipt.rows));
  }

  Future<void> disposeForTest() => _sandbox.disposeForTest();
}
