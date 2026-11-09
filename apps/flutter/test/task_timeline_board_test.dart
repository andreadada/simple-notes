import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/ui/task_timeline_board.dart';

void main() {
  final anchor = DateTime(2026, 11, 9);
  final created = DateTime.utc(2026, 11, 1);

  LocalTask scheduled(String id, {String? due, List<TimeSlot> slots = const []}) =>
      LocalTask(
        id: id,
        title: id,
        dueAt: null,
        due: due == null ? TaskDue.none : TaskDue.dateOnly(due),
        timeBlocks: slots,
        completed: false,
        createdAt: created,
      );

  test('civil deadline is a milestone, never a fictitious UTC block', () {
    final task = scheduled('civil', due: '2026-11-12');
    final spans = TaskTimelineSchedule.spans(task, anchor);
    expect(spans.length, 1);
    expect(spans.single.startDay, 3);
    expect(spans.single.endDay, 3);
    expect(spans.single.milestone, isTrue);
  });

  test('outside window and missing due are not scheduled', () {
    expect(TaskTimelineSchedule.spans(
      scheduled('none'), anchor), isEmpty);
    expect(TaskTimelineSchedule.spans(
      scheduled('before', due: '2026-11-08'), anchor), isEmpty);
    expect(TaskTimelineSchedule.spans(
      scheduled('after', due: '2026-11-23'), anchor), isEmpty);
    expect(TaskTimelineSchedule.spans(
      scheduled('last', due: '2026-11-22'), anchor).single.startDay, 13);
    expect(() => TaskTimelineSchedule.spans(
      scheduled('none'), anchor, days: 63), throwsFormatException);
  });

  test('time blocks project across days and clip within board', () {
    final task = scheduled('range', slots: [
      TimeSlot(
        id: 'block',
        block: TimeBlock(
          start: DateTime(2026, 11, 9, 23),
          end: DateTime(2026, 11, 10, 22),
          timeZone: 'Europe/Rome',
        ),
      ),
    ]);
    final blocks = TaskTimelineSchedule.spans(task, anchor);
    expect(blocks, hasLength(1));
    expect(blocks.single.startDay, 0);
    expect(blocks.single.endDay, 1);
    expect(blocks.single.milestone, isFalse);
  });

  test('calendar offsets ignore DST duration differences', () {
    expect(TaskTimelineSchedule.dayOffset(
      DateTime(2026, 10, 26), DateTime(2026, 10, 24),
    ), 2);
    expect(TaskTimelineSchedule.dayOffset(
      DateTime(2026, 3, 30), DateTime(2026, 3, 28),
    ), 2);
  });
}
