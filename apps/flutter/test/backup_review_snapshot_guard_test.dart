import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/backup_review_snapshot_guard.dart';
import 'package:simple_notes/data/full_backup.dart';

void main() {
  const guard = BackupReviewSnapshotGuard();
  const owner = 'snapshot-guard-owner';
  const secret = 'PRIVATE-BACKUP-TITLE';

  FullBackupSnapshot specimen({
    String account = owner,
    String title = secret,
    String cursor = '91',
    bool pending = false,
    String? theme,
    bool reversed = false,
    int day = 4,
  }) {
    Map<String, Object?> note(String id, String name) => {
      for (final col in FullBackupSnapshot.columns['note_entries']!) col: null,
      'id': id,
      'title': name,
      'body': 'PRIVATE-NOTE-BODY',
      'created_at': '2026-11-04T20:00:00.000Z',
      'remote_version': 4,
    };
    final notes = [note('note-one', title), note('note-two', 'Second')];
    if (reversed) notes.setAll(0, notes.reversed.toList());
    final settings = <Map<String, Object?>>[
      {'key': 'boundOwnerId', 'value': account},
      {'key': 'syncCursor', 'value': cursor},
    ];
    if (reversed) settings.setAll(0, settings.reversed.toList());
    final tables = <String, List<Map<String, Object?>>>{
      for (final key in FullBackupSnapshot.columns.keys)
        key: <Map<String, Object?>>[],
    };
    tables['note_entries'] = notes;
    tables['sync_settings'] = settings;
    if (pending) {
      tables['pending_mutations'] = [
        {
          'operation_id': 'op-1', 'entity_type': 'note',
          'entity_id': 'note-one', 'action': 'upsert',
          'payload': '{}', 'created_at': '2026-11-04T20:00:00.000Z',
        },
      ];
    }
    final snapshot = FullBackupSnapshot(
      ownerId: account,
      createdAtUtc: DateTime.utc(2026, 11, day),
      tables: tables,
      preferences: {
        for (final name in FullBackupSnapshot.preferenceNames)
          name: name == 'theme' ? theme : null,
      },
    );
    snapshot.validate();
    return snapshot;
  }

  test('capture time and SQLite row order alone do not invalidate', () {
    final original = specimen();
    final same = specimen(reversed: true, day: 6);
    expect(guard.isUnchanged(baseline: original, latest: same), isTrue);
    expect(original.tables['note_entries']!.first['id'], 'note-one');
    expect(same.tables['note_entries']!.first['id'], 'note-two');
  });

  test('note content, cursor and outbox changes invalidate a review', () {
    final baseline = specimen();
    for (final modified in [
      specimen(title: 'Edited locally'),
      specimen(cursor: '92'),
      specimen(pending: true),
    ]) {
      expect(guard.isUnchanged(
        baseline: baseline, latest: modified,
      ), isFalse);
    }
  });

  test('changed owner and owner preferences invalidate a review', () {
    final baseline = specimen();
    expect(guard.isUnchanged(
      baseline: baseline, latest: specimen(account: 'another-owner'),
    ), isFalse);
    expect(guard.isUnchanged(
      baseline: baseline, latest: specimen(theme: 'light'),
    ), isFalse);
  });

  test('malformed snapshots fail closed, never throw or mutate data', () {
    final baseline = specimen();
    final malformed = FullBackupSnapshot(
      ownerId: baseline.ownerId,
      createdAtUtc: DateTime.utc(2026, 11, 6),
      tables: {...baseline.tables, 'unknown_table': []},
      preferences: baseline.preferences,
    );
    final original = baseline.toJson().toString();
    expect(guard.isUnchanged(
      baseline: baseline, latest: malformed,
    ), isFalse);
    expect(guard.isUnchanged(
      baseline: malformed, latest: baseline,
    ), isFalse);
    expect(baseline.toJson().toString(), original);
  });

  test('private payload is never exposed in the return value', () {
    final expected = specimen();
    final observed = specimen(title: 'PRIVATE-OTHER-TITLE');
    final result = guard.isUnchanged(
      baseline: expected, latest: observed,
    );
    expect(result, isFalse);
    expect(result.toString(), isNot(contains(secret)));
    expect(result.toString(), isNot(contains(owner)));
  });
}
