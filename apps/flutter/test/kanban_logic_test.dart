import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/kanban_logic.dart';

LocalTask task(String id, {String? listId, int priority = 0,
    bool completed = false}) => LocalTask(
  id: id, title: id, dueAt: null,
  completed: completed, createdAt: DateTime.utc(2026, 10, 26),
  listId: listId, priority: priority,
);

void main() {
  test('Inbox and lists preserve all tasks without duplicate cards', () {
    final data = LocalData(
      lists: [
        LocalTaskList(id: 'uni', title: 'Università',
          createdAt: DateTime.utc(2026)),
        LocalTaskList(id: 'job', title: 'Lavoro',
          createdAt: DateTime.utc(2026)),
      ],
      tasks: [
        task('inbox'), task('uni1', listId: 'uni', priority: 3),
        task('uni2', listId: 'uni', priority: 1),
        task('job1', listId: 'job'), task('orphan', listId: 'removed'),
        task('done', completed: true),
      ],
    );
    final columns = KanbanLogic.columns(data);
    expect(columns.map((x) => x.title),
      ['Inbox', 'Università', 'Lavoro']);
    expect(columns[0].tasks.map((x) => x.id),
      ['inbox', 'orphan']);
    expect(columns[1].tasks.map((x) => x.id),
      ['uni1', 'uni2']);
    expect(columns[2].tasks.map((x) => x.id), ['job1']);
    expect(columns.expand((x) => x.tasks).length, 5);
    expect(data.tasks.singleWhere((x) => x.id == 'orphan').listId,
      'removed'); // no silent rewrite
  });

  test('Drag targets reject invalid, completed and unchanged moves', () {
    final data = LocalData(
      lists: [LocalTaskList(id: 'a', title: 'A',
        createdAt: DateTime.utc(2026))],
      tasks: [
        task('existing', listId: 'a'),
        task('inbox'),
        task('completed', completed: true),
      ],
    );
    expect(KanbanLogic.canMove(data, 'existing', 'a'), false);
    expect(KanbanLogic.canMove(data, 'existing', null), true);
    expect(KanbanLogic.canMove(data, 'inbox', 'a'), true);
    expect(KanbanLogic.canMove(data, 'inbox', 'missing'), false);
    expect(KanbanLogic.canMove(data, 'missing-task', null), false);
    expect(KanbanLogic.canMove(data, 'completed', 'a'), false);
    expect(KanbanLogic.canMove(data, 'inbox', null), false);
  });

  test('Projection leaves input payload unchanged after sorting', () {
    final original = task('a', listId: 'x', priority: 3);
    final data = LocalData(tasks: [original]);
    final before = original.toJson();
    KanbanLogic.columns(data);
    expect(original.toJson(), before);
  });
}
