import 'dart:io';

/// P2.4B2W: platform capability boundary for sandbox directory persistence.
///
/// A file flush + rename does not synchronize the parent directory entry.
/// This contract makes the missing barrier explicit. It is NOT a live restore
/// authorization, an SQLite/SharedPreferences transaction or power-loss proof.
abstract interface class RecoveryDirectoryBarrier {
  bool get supportedHere;
  Future<void> syncDirectory(Directory directory);
}

/// Deliberate fail-closed fallback on unsupported/native-unverified systems.
class UnavailableRecoveryDirectoryBarrier
    implements RecoveryDirectoryBarrier {
  const UnavailableRecoveryDirectoryBarrier();

  @override
  bool get supportedHere => false;

  @override
  Future<void> syncDirectory(Directory directory) async {
    throw UnsupportedError('Fsync directory non disponibile o non attestato.');
  }
}
