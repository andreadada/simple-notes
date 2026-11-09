import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_notes/data/models.dart';
import 'package:simple_notes/data/reminder_automations.dart';
import 'package:simple_notes/ui/reminder_planner.dart';
import 'package:simple_notes/ui/reminder_reconcile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  LocalTask task(String id, {int priority = 0, bool completed = false,
      TaskDue? due, List<TimeSlot> slots = const []}) =>
      LocalTask(id: id, title: 'Studio', dueAt: null,
        due: due ?? TaskDue.none, timeBlocks: slots, priority: priority,
        completed: completed, createdAt: DateTime.utc(2026, 11, 9));

  TaskDue tomorrow() => TaskDue.timed(
    date: '2026-11-10', time: '10:00', timeZone: 'Europe/Rome',
    offsetSeconds: 3600, instant: DateTime.utc(2026, 11, 10, 9));

  test('legacy defaults match existing 15-minute due and block plan', () {
    final t = task('t', priority: 2, due: tomorrow(), slots: [
      TimeSlot(id: 'slot', block: TimeBlock(
        start: DateTime.utc(2026, 11, 10, 12),
        end: DateTime.utc(2026, 11, 10, 13),
        timeZone: 'Europe/Rome')),
    ]);
    final now = DateTime.utc(2026, 11, 9);
    final previous = ReminderPlanner.desiredSchedule([t],
        ownerId: 'owner', now: now,
        dueLeadMinutes: 15, blockLeadMinutes: 15);
    final newPlan = ReminderPlanner.desiredScheduleForRules([t],
        ownerId: 'owner', now: now,
        rules: ReminderAutomationLibrary.defaults().rules);
    expect(newPlan.map((r) => r.key), previous.map((r) => r.key));
    expect(newPlan.map((r) => r.notificationId),
        previous.map((r) => r.notificationId));
  });

  test('filter priority, dedup and native cancellation after rule change', () {
    final t = task('t', priority: 3, due: tomorrow());
    final low = task('low', priority: 1, due: tomorrow());
    final now = DateTime.utc(2026, 11, 9);
    final a = ReminderAutomationRule(
      id: 'rule-a', kind: 'due', leadMinutes: 30, minPriority: 2);
    final b = ReminderAutomationRule(
      id: 'rule-b', kind: 'due', leadMinutes: 30, minPriority: 3);
    final first = ReminderPlanner.desiredScheduleForRules([t, low],
      ownerId: 'owner', now: now, rules: [a, b]);
    expect(first, hasLength(1));
    expect(first.single.fireAtUtc, DateTime.utc(2026, 11, 10, 8, 30));
    final next = ReminderPlanner.desiredScheduleForRules([t, low],
      ownerId: 'owner', now: now, rules: [a.copyWith(enabled: false),
        b.copyWith(enabled: false)]);
    expect(next, isEmpty);
    final diff = ReminderReconciler.diff(
      recorded: {first.single.key: first.single.notificationId},
      desired: next);
    expect(diff.cancelIds, [first.single.notificationId]);
    expect(diff.schedule, isEmpty);
    expect(ReminderPlanner.desiredScheduleForRules([
      task('done', completed: true, due: tomorrow()),
    ], ownerId: 'owner', now: now, rules: [a]), isEmpty);
  });

  test('owner keys and saved preferences are strictly isolated', () async {
    final prefs = await SharedPreferences.getInstance();
    const store = ReminderAutomationStore();
    final original = await store.load(prefs, 'A');
    expect(original.rules, hasLength(2));
    final custom = original.upsert(ReminderAutomationLibrary.create(
      kind: 'block', leadMinutes: 60, minPriority: 2));
    await store.save(prefs, 'A', custom);
    expect((await store.load(prefs, 'A')).rules, hasLength(3));
    expect((await store.load(prefs, 'B')).rules, hasLength(2));
    expect(ReminderAutomationStore.keyForOwner('A'),
        isNot(ReminderAutomationStore.keyForOwner('B')));
    expect(ReminderAutomationStore.keyForOwner('A'), isNot(contains('.A')));
    expect(() => ReminderAutomationStore.keyForOwner(''),
        throwsFormatException);
    await store.save(prefs, 'A', ReminderAutomationLibrary(rules: const []));
    expect((await store.load(prefs, 'A')).rules, isEmpty);
    expect((await store.load(prefs, 'B')).rules, hasLength(2));
  });

  test('corrupted or future rules fail closed without resetting preferences',
      () async {
    final prefs = await SharedPreferences.getInstance();
    const store = ReminderAutomationStore();
    final key = ReminderAutomationStore.keyForOwner('owner');
    await prefs.setString(key, 'CORRUPT');
    await expectLater(store.load(prefs, 'owner'), throwsFormatException);
    expect(prefs.getString(key), 'CORRUPT');
    final valid = jsonDecode(ReminderAutomationLibrary.defaults().serialize())
        as Map<String, dynamic>;
    valid['schema'] = 9;
    expect(() => ReminderAutomationLibrary.deserialize(jsonEncode(valid)),
        throwsFormatException);
    valid['schema'] = 1;
    (valid['rules'] as List).first['leadMinutes'] = 13;
    expect(() => ReminderAutomationLibrary.deserialize(jsonEncode(valid)),
        throwsFormatException);
    (valid['rules'] as List).first['leadMinutes'] = 15;
    (valid['rules'] as List).first['extra'] = 'secret';
    expect(() => ReminderAutomationLibrary.deserialize(jsonEncode(valid)),
        throwsFormatException);
    expect(() => ReminderAutomationLibrary(rules: const [
      ReminderAutomationRule(
        id: 'rule-one', kind: 'due', leadMinutes: 15),
      ReminderAutomationRule(
        id: 'rule-one', kind: 'due', leadMinutes: 30),
    ]), throwsFormatException);
  });
}
