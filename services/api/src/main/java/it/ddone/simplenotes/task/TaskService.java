package it.ddone.simplenotes.task;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import it.ddone.simplenotes.sync.SyncController;
import it.ddone.simplenotes.sync.SyncService;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Legacy REST task adapter. Mutations are committed using SyncService,
 * sharing owner locking, OCC and the canonical sync-change serialization.
 * No direct saveAndFlush may bypass that ledger.
 */
@Service
public class TaskService {
    private final TaskRepository repository;
    private final SyncService sync;
    private final ObjectMapper json;

    public TaskService(TaskRepository repository, SyncService sync,
            ObjectMapper json) {
        this.repository = repository;
        this.sync = sync;
        this.json = json;
    }

    @Transactional(readOnly = true)
    public List<TaskEntity> all(UUID ownerId) {
        return repository.findByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(ownerId);
    }

    @Transactional
    public TaskEntity create(UUID ownerId, String title, String description,
            Instant dueAt) {
        UUID id = UUID.randomUUID();
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("title", title);
        fields.put("description", description);
        fields.put("dueAt", dueAt == null ? null : dueAt.toString());
        fields.put("completed", false);
        fields.put("timeBlocks", List.of());
        fields.put("recurrence", TaskRecurrence.none().payload());
        sync.apply(ownerId, new SyncController.ApplyRequest(UUID.randomUUID(), id,
            "task", "upsert", null, json.valueToTree(fields), null));
        return repository.findById(id).orElseThrow();
    }

    @Transactional
    public TaskEntity update(UUID ownerId, UUID taskId, long expectedVersion,
            String title, String description, Instant dueAt, boolean completed) {
        sync.lockAccount(ownerId);
        TaskEntity stored = owned(ownerId, taskId);
        // The legacy editor cannot express civil date or zoned time semantics.
        if ("date".equals(stored.dueKind) || "datetime".equals(stored.dueKind)) {
            throw new ClientUpgradeRequiredException();
        }
        sync.apply(ownerId, new SyncController.ApplyRequest(UUID.randomUUID(),
            taskId, "task", "upsert", expectedVersion,
            updatePayload(stored, title, description,
                TaskDue.fromOldInstant(dueAt), completed), null));
        return repository.findById(taskId).orElseThrow();
    }

    @Transactional
    public TaskEntity setCompleted(UUID ownerId, UUID taskId,
            boolean completed) {
        sync.lockAccount(ownerId);
        TaskEntity stored = owned(ownerId, taskId);
        // Completion must preserve modern due, blocks, recurrence, priority,
        // tags, subtasks and list association. An OCC conflict is safer than
        // overwriting a newer edit made by another client.
        sync.apply(ownerId, new SyncController.ApplyRequest(UUID.randomUUID(),
            taskId, "task", "upsert", stored.version,
            updatePayload(stored, stored.title, stored.description,
                TaskDue.fromEntity(stored), completed), null));
        return repository.findById(taskId).orElseThrow();
    }

    @Transactional
    public void delete(UUID ownerId, UUID taskId) {
        sync.lockAccount(ownerId);
        TaskEntity stored = owned(ownerId, taskId);
        sync.apply(ownerId, new SyncController.ApplyRequest(UUID.randomUUID(),
            taskId, "task", "delete", stored.version, null, null));
    }

    private com.fasterxml.jackson.databind.JsonNode updatePayload(
            TaskEntity stored, String title, String description, TaskDue due,
            boolean completed) {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("title", title);
        fields.put("description", description);
        fields.put("due", due.toPayload());
        fields.put("dueAt", due.instant() == null ? null : due.instant().toString());
        fields.put("completed", completed);
        fields.put("timeBlocks", TaskTimeBlocks.toPayload(
            TaskTimeBlocks.fromEntity(stored, json)));
        fields.put("timeBlock", TaskTimeBlock.toPayload(stored));
        try {
            fields.put("recurrence", TaskRecurrence.parse(
                json.readTree(stored.recurrenceJson)).payload());
            fields.put("tags", json.readTree(stored.tagsJson));
            fields.put("subtasks", json.readTree(stored.subtasksJson));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Stored task metadata is invalid", e);
        }
        fields.put("listId", stored.listId == null ? null :
            stored.listId.toString());
        fields.put("priority", stored.priority);
        return json.valueToTree(fields);
    }

    private TaskEntity owned(UUID ownerId, UUID taskId) {
        return repository.findByIdAndOwnerIdAndDeletedAtIsNull(taskId, ownerId)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Task not found"));
    }
}
