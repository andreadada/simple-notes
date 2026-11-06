import 'full_backup.dart';
import 'reconciliation_preflight_client.dart';
import 'reconciliation_worksheet.dart';
import 'restore_cloud_inventory.dart';

/// P2.4B2T: a content-free receipt for an entirely local, non-executable
/// human review. This is NEVER a permission slip to restore or sync.
class ReconciliationReviewReceipt {
  const ReconciliationReviewReceipt({
    required this.sourcesMatch,
    required this.cloudCheckCurrent,
    required this.cloudCheckConsistent,
    required this.allDecisionsReviewed,
    required this.unresolvedDecisions,
    required this.reviewedDecisions,
    required this.importedPendingOperations,
  });

  final bool sourcesMatch;
  final bool cloudCheckCurrent;
  final bool cloudCheckConsistent;
  final bool allDecisionsReviewed;
  final int unresolvedDecisions;
  final int reviewedDecisions;
  final int importedPendingOperations;

  /// Completion means only that the non-mutating UI flow was traversed.
  /// The check is not a cloud lease and may be outdated immediately.
  bool get reviewComplete =>
      sourcesMatch &&
      cloudCheckCurrent &&
      cloudCheckConsistent &&
      allDecisionsReviewed;

  bool get importedOutboxQuarantined => true;
  bool get canRestoreLive => false;
  bool get canWriteCloud => false;
  bool get canApplyDecisions => false;
  bool get canReplayImportedOutbox => false;
  bool get canResumeAutoSync => false;

  /// No owner, entity IDs, titles, bodies, passwords, tokens, fingerprints
  /// or mutation payloads are included, even when the review is complete.
  String get summary {
    final status = !sourcesMatch
        ? 'Confronto non valido: le sorgenti sono cambiate'
        : !cloudCheckCurrent
            ? 'Ricontrollo cloud assente o riferito a versioni superate'
            : !cloudCheckConsistent
                ? 'Il cloud non coincide con l’inventario osservato'
                : !allDecisionsReviewed
                    ? 'Restano scelte da esaminare'
                    : 'Revisione informativa completata';
    return '$status. '
        'Scelte esaminate: $reviewedDecisions, '
        'da decidere: $unresolvedDecisions. '
        'Operazioni importate ancora in quarantena: '
        '$importedPendingOperations. '
        'Nessun ripristino o upload autorizzato; '
        'le revisioni cloud non sono riservate e '
        'il confronto non è un lock.';
  }
}

/// Strictly read-only combination of an owner-bound worksheet and the result
/// of the optional revision check. A preflight response is only an observation
/// and cannot authorize writes even if it reports fully consistent versions.
class ReconciliationReviewReceiptBuilder {
  const ReconciliationReviewReceiptBuilder();

  ReconciliationReviewReceipt inspect({
    required String expectedOwnerId,
    required FullBackupSnapshot current,
    required FullBackupSnapshot imported,
    required RestoreServerInventory cloud,
    required ReconciliationWorksheet worksheet,
    ReconciliationPreflightResult? preflight,
  }) {
    current.validate();
    imported.validate();
    if (expectedOwnerId.isEmpty ||
        current.ownerId != expectedOwnerId ||
        imported.ownerId != expectedOwnerId) {
      throw const FormatException('Account del confronto non corrispondente.');
    }

    final bound = worksheet.isBoundTo(
      current: current,
      imported: imported,
      cloud: cloud,
    );
    final eligibleBatch =
        cloud.revisions.isNotEmpty && cloud.revisions.length <= 100;
    final currentCheck = preflight != null &&
        eligibleBatch &&
        preflight.checkedEntities == cloud.revisions.length &&
        preflight.observedCursor == cloud.cursor &&
        preflight.cursorMatches &&
        preflight.mismatchedEntities >= 0 &&
        preflight.mismatchedEntities <= preflight.checkedEntities;
    final consistentCheck = currentCheck &&
        preflight!.consistent &&
        preflight.mismatchedEntities == 0;

    // An obsolete worksheet must not count as reviewed, even if all choices
    // were selected in a previous modal. Never reuse its selections.
    final reviewed = bound
        ? worksheet.items.where((item) =>
            item.choice != DraftConflictChoice.undecided &&
            item.availableChoices.contains(item.choice)).length
        : 0;
    final unresolved = bound ? worksheet.items.length - reviewed : 0;
    return ReconciliationReviewReceipt(
      sourcesMatch: bound,
      cloudCheckCurrent: currentCheck,
      cloudCheckConsistent: consistentCheck,
      allDecisionsReviewed: bound && unresolved == 0,
      reviewedDecisions: reviewed,
      unresolvedDecisions: unresolved,
      importedPendingOperations: imported.count('pending_mutations'),
    );
  }
}
