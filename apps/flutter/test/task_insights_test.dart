import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/task_insights.dart';
import 'package:simple_notes/data/task_templates.dart';

void main() {
  final now = DateTime(2026, 11, 9, 12);
  final yesterday = DateTime(2026, 11, 8);
  LocalTask task(
    String id, {
    String? civil,
    bool done = false,
    int priority = 0,
    String? listId,
    List<String> tags = const [],
    String description = '',
    List<LocalSubtask> subtasks = const [],
    DateTime? legacy,
  }) => LocalTask(
    id: id,
    title: 'Activity $id',
    dueAt: legacy,
    due: civil == null ? TaskDue.legacy(legacy) : TaskDue.dateOnly(civil),
    completed: done,
    createdAt: yesterday,
    listId: listId,
    priority: priority,
    tags: tags,
    description: description,
    subtasks: subtasks,
  );

  test('civil dates are filtered by calendar day, including DST boundaries',
      () {
    final values = [
      task('overdue', civil: '2026-11-08'),
      task('today', civil: '2026-11-09'),
      task('within7', civil: '2026-11-15'),
      task('outside', civil: '2026-11-16'),
      task('none'),
      task('done', civil: '2026-11-07', done: true),
    ];
    expect(TaskQuery(dueScope: TaskDueScope.overdue)
        .apply(values, at: now).map((x) => x.id), ['overdue']);
    expect(TaskQuery(dueScope: TaskDueScope.today)
        .apply(values, at: now).map((x) => x.id), ['today']);
    expect(TaskQuery(dueScope: TaskDueScope.next7)
        .apply(values, at: now).map((x) => x.id),
        ['today', 'within7']);
    expect(TaskQuery(dueScope: TaskDueScope.withoutDate)
        .apply(values, at: now).map((x) => x.id), ['none']);
  });

  test('search finds text in tags description subtasks and title', () {
    final values = [
      task('one', tags: ['Exam', 'Uni']),
      task('two', description: 'Diffraction study'),
      task('three', subtasks: [
        const LocalSubtask(id: 'sub', title: 'Measure signal'),
      ]),
    ];
    expect(TaskQuery(search: 'exAm').apply(values).single.id, 'one');
    expect(TaskQuery(search: 'diffraction').apply(values).single.id, 'two');
    expect(TaskQuery(search: 'signal').apply(values).single.id, 'three');
    expect(TaskQuery(search: 'activity two').apply(values).single.id, 'two');
  });

  test('tag, priority, list and completion filters compose without mutation',
      () {
    final values = [
      task('a', priority: 3, listId: 'l1', tags: ['WORK']),
      task('b', priority: 2, listId: 'l1', tags: ['work'], done: true),
      task('c', priority: 3, listId: 'l2', tags: ['work']),
    ];
    expect(TaskQuery(
      priority: 3, tag: 'work', listId: 'l1', completed: false,
    ).apply(values).map((x) => x.id), ['a']);
    expect(values.length, 3);
  });

  test('stable sorting handles absent dates and tie-breaking by ID', () {
    final values = [
      task('z'),
      task('b', civil: '2026-11-11'),
      task('a', civil: '2026-11-10'),
    ];
    expect(TaskQuery(sort: TaskSortOrder.deadline)
        .apply(values).map((x) => x.id), ['a', 'b', 'z']);
    expect(TaskQuery(sort: TaskSortOrder.title)
        .apply(values).map((x) => x.id), ['a', 'b', 'z']);
    expect(TaskQuery(sort: TaskSortOrder.createdNewest)
        .apply(values).map((x) => x.id), ['a', 'b', 'z']);
  });

  test('snapshot analytics are current-state only and isolate inbox', () {
    final values = [
      task('a', civil: '2026-11-08', priority: 3, listId: 'l1'),
      task('b', civil: '2026-11-09', done: true, listId: 'l1'),
      task('c', civil: '2026-11-12'),
      task('d'),
    ];
    final report = TaskAnalyticsSnapshot.fromTasks(values, at: now);
    expect(report.total, 4);
    expect(report.pending, 3);
    expect(report.completed, 1);
    expect(report.overdue, 1);
    expect(report.upcoming, 1);
    expect(report.highPriority, 1);
    expect(report.completionRatio, closeTo(.25, .0001));
    expect(report.byList['l1'], 2);
    expect(report.byList[null], 2);
    expect(TaskAnalyticsSnapshot.fromTasks([], at: now).completionRatio, 0);
  });

  test('all builtin templates generate safe, distinct ordinary tasks', () {
    final ids = <String>{};
    for (final template in TaskTemplateCatalog.templates) {
      expect(ids.add(template.id), isTrue);
      final first = template.instantiate(listId: 'my-list', createdAt: now);
      final second = template.instantiate(listId: 'my-list', createdAt: now);
      expect(first.id, isNot(second.id));
      expect(first.listId, 'my-list');
      expect(first.completed, isFalse);
      expect(first.subtasks, isNotEmpty);
      expect(first.subtasks.every((item) => !item.completed), isTrue);
      expect(first.subtasks.map((item) => item.id).toSet().length,
          first.subtasks.length);
      expect(first.subtasks.first.id, isNot(second.subtasks.first.id));
      expect(first.due.kind, 'none');
      expect(first.title, template.title);
    }
    expect(() => TaskTemplateCatalog.find('unknown'), throwsFormatException);
  });
}
