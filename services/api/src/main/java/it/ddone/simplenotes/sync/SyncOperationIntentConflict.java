package it.ddone.simplenotes.sync;

/** Immutable intent / operation ID collision. No payload is attached. */
final class SyncOperationIntentConflict extends RuntimeException {
    SyncOperationIntentConflict() {
        super("Sync operation ID reused for a different intent");
    }
}
