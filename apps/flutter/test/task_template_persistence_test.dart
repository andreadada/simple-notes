import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/data/app_database.dart';
import 'package:simple_notes/data/task_templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a template persists as one task with one sync operation and subtasks',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner('templates-owner');
      final draft = TaskTemplateCatalog.find('study-session').instantiate();
      await db.upsertTask(draft);
      final restored = await db.snapshot();
      expect(restored.tasks, hasLength(1));
      expect(restored.tasks.single.id, draft.id);
      expect(restored.tasks.single.title, draft.title);
      expect(restored.tasks.single.tags, ['studio']);
      expect(restored.tasks.single.subtasks, hasLength(4));
      expect(restored.tasks.single.subtasks.every(
          (item) => !item.completed), isTrue);

      final rows = await db.fullBackupRows('templates-owner');
      final outbox = rows['pending_mutations']!;
      expect(outbox, hasLength(1));
      expect(outbox.single['entity_type'], 'task');
      expect(outbox.single['entity_id'], draft.id);
      expect(outbox.single['action'], 'upsert');
    } finally {
      await db.close();
    }
  });

  test('each template use creates an independent task and operation', () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db.bindOwner('templates-owner');
      final template = TaskTemplateCatalog.find('meeting');
      final first = template.instantiate();
      final second = template.instantiate();
      await db.transaction(() async {
        await db.upsertTask(first);
        await db.upsertTask(second);
      });
      final rows = await db.fullBackupRows('templates-owner');
      expect(rows['task_entries'], hasLength(2));
      expect(rows['pending_mutations'], hasLength(2));
      expect(rows['pending_mutations']!
          .map((row) => row['operation_id']).toSet().length, 2);
    } finally {
      await db.close();
    }
  });
}
