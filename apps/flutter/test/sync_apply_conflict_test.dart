import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/sync/sync_apply_conflict.dart';

void main() {
  test('operation-ID reuse has a distinct non-mergeable code', () {
    final body = jsonEncode({'code': 'SYNC_OPERATION_ID_REUSE'});
    expect(classifySyncApplyConflict(body),
        SyncApplyConflictKind.operationIdReuse);
  });

  test('ordinary version conflict remains interactive and compatible', () {
    for (final input in [
      '{"status":409,"detail":"Version conflict"}',
      '{"code":"SYNC_CONCURRENT_UPDATE"}',
      '{"code":"SYNC_OPERATION_ID_REUSE_typo"}',
      '',
      '<html>Bad Gateway</html>',
      'not-json',
      'null',
      '[]',
      '{"code":null}',
      '{"code":123}',
      'x' * 2049,
    ]) {
      expect(classifySyncApplyConflict(input),
          SyncApplyConflictKind.versionOrEntity);
    }
  });

  test('a safe server error does not contain sensitive entity data', () {
    const response = '{"code":"SYNC_OPERATION_ID_REUSE"}';
    expect(response, isNot(contains('accountId')));
    expect(response, isNot(contains('PRIVATE_NOTE_BODY')));
    expect(response, isNot(contains('operationId')));
    expect(classifySyncApplyConflict(response),
        SyncApplyConflictKind.operationIdReuse);
  });
}
