import 'dart:convert';

/// Machine-readable classification of HTTP 409 returned by /sync/apply.
///
/// A re-used operation ID with a different payload is not a normal
/// version conflict and MUST NOT enter the interactive rebase workflow.
enum SyncApplyConflictKind {
  versionOrEntity,
  operationIdReuse,
}

SyncApplyConflictKind classifySyncApplyConflict(String responseBody) {
  // Fail closed toward the existing non-destructive 409 handling when the
  // server is old, a proxy returns HTML, or a response is unexpectedly large.
  if (responseBody.length > 2048) {
    return SyncApplyConflictKind.versionOrEntity;
  }
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic> &&
        decoded['code'] == 'SYNC_OPERATION_ID_REUSE') {
      return SyncApplyConflictKind.operationIdReuse;
    }
  } catch (_) {
    // Keep old backend compatibility. No error text or token is logged.
  }
  return SyncApplyConflictKind.versionOrEntity;
}
