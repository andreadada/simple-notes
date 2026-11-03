import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/portable_csv.dart';
import 'package:simple_notes/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final created = DateTime.utc(2026, 11, 3, 9);
  LocalData fixture() => LocalData(
    lists: [
      LocalTaskList(id: 'list-1', title: 'Università', createdAt: created),
    ],
    tasks: [
      LocalTask(
        id: 'task-1', title: 'Esercizio, da "consegnare"',
        description: 'Prima riga\nSeconda riga',
        dueAt: null, due: TaskDue.dateOnly('2026-11-10'),
        recurrence: TaskRecurrence('weekly', interval: 2),
        completed: false, createdAt: created, listId: 'list-1',
        priority: 2, tags: ['studio', 'fisica'],
        subtasks: [const LocalSubtask(
          id: 'sub-1', title: 'Verifica formule', completed: true,
        )],
        timeBlocks: [
          TimeSlot(id: 'slot-1', block: TimeBlock(
            start: DateTime.utc(2026, 11, 9, 9),
            end: DateTime.utc(2026, 11, 9, 10),
            timeZone: 'Europe/Rome',
          )),
        ],
      ),
    ],
    notes: [
      LocalNote(
        id: 'note-1', title: 'Riassunto',
        body: 'Prima,"seconda"\nTerza', createdAt: created,
      ),
    ],
    trashedNotes: [
      LocalNote(
        id: 'trashed', title: 'SEGRETO_CESTINO',
        body: 'DA_NON_ESPORTARE', createdAt: created,
      ),
    ],
  );

  test('task CSV preserves dates and flattened domain fields', () {
    final bytes = PortableCsv(fixture()).encode(CsvDataset.tasks);
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    final csv = utf8.decode(bytes);
    expect(csv, contains('\r\n'));
    expect(csv, contains('"id","title","description","completed"'));
    expect(csv, contains('"Esercizio, da ""consegnare"""'));
    expect(csv, contains('"Prima riga\nSeconda riga"'));
    expect(csv, contains('"date","2026-11-10","","",""'));
    expect(csv, contains('"weekly","2"'));
    expect(csv, contains('"Università"'));
    expect(csv, contains('Europe/Rome'));
    expect(csv, contains('slot-1'));
    expect(csv, contains('sub-1'));
    expect(csv, contains('fisica'));
    expect(csv, contains('"false"'));
    expect(csv, isNot(contains('SEGRETO_CESTINO')));
    expect(csv, isNot(contains('refreshToken')));
  });

  test('notes CSV escapes quotes, commas, CRLF and excludes trash', () {
    final bytes = PortableCsv(fixture()).encode(CsvDataset.notes);
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    final csv = utf8.decode(bytes);
    expect(csv, startsWith('"id","title","body","created_at_utc"\r\n'));
    expect(csv, contains('"Prima,""seconda""\nTerza"'));
    expect(csv, contains('2026-11-03T09:00:00.000Z'));
    expect(csv, isNot(contains('SEGRETO_CESTINO')));
    expect(csv, isNot(contains('DA_NON_ESPORTARE')));
  });

  test('list CSV counts only active tasks and does not export note bodies', () {
    final csv = utf8.decode(PortableCsv(fixture()).encode(CsvDataset.lists));
    expect(csv, contains('"id","title","created_at_utc","task_count"'));
    expect(csv, contains('"list-1","Università","2026-11-03T09:00:00.000Z","1"'));
    expect(csv, isNot(contains('Riassunto')));
    expect(csv, isNot(contains('DA_NON_ESPORTARE')));
  });

  test('CSV formula injection is neutralized after leading whitespace', () {
    final dangerous = [
      '=HYPERLINK("https://evil.example","click")',
      '+SUM(1,1)', '-1+2', '@SUM(1,2)',
      ' \t=2+2', '\u200B=3+3', '\r=7+7', '\n=8+8',
    ];
    final data = LocalData(notes: [
      for (var i = 0; i < dangerous.length; i++)
        LocalNote(id: 'n$i', title: dangerous[i],
            body: dangerous[i], createdAt: created),
    ]);
    final csv = utf8.decode(PortableCsv(data).encode(CsvDataset.notes));
    for (final value in dangerous) {
      final escaped = "'$value".replaceAll('"', '""');
      expect(csv, contains('"$escaped"'), reason: value);
    }
    expect(csv, contains('""click""'));
  });

  test('empty dataset is a valid CSV with its own header', () {
    final empty = const PortableCsv(LocalData());
    for (final dataset in CsvDataset.values) {
      expect(empty.count(dataset), 0);
      final bytes = empty.encode(dataset);
      expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(bytes);
      expect(csv.endsWith('\r\n'), isTrue);
      expect(csv.split('\r\n').length, 2);
    }
  });

  test('records and payload limits refuse large exports', () {
    final note = LocalNote(
        id: 'one', title: 'a', body: 'b', createdAt: created);
    final hugeCount = PortableCsv(LocalData(
        notes: List<LocalNote>.filled(PortableCsv.maxRecords + 1, note)));
    expect(() => hugeCount.encode(CsvDataset.notes), throwsFormatException);
    final hugeBytes = PortableCsv(LocalData(notes: [
      LocalNote(id: 'large', title: 'large', body: 'x' * PortableCsv.maxBytes,
          createdAt: created),
    ]));
    expect(() => hugeBytes.encode(CsvDataset.notes), throwsFormatException);
  });

  test('CSV export from SQLite snapshot leaves outbox and data untouched',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertNote(fixture().notes.single);
    final before = await db.snapshot();
    final pending = await db.pendingCount();
    final exported = utf8.decode(
        PortableCsv(before).encode(CsvDataset.notes));
    expect(exported, contains('Riassunto'));
    expect(await db.pendingCount(), pending);
    final after = await db.snapshot();
    expect(after.notes.single.toJson(), before.notes.single.toJson());
    expect(after.tasks.length, before.tasks.length);
  });
}
