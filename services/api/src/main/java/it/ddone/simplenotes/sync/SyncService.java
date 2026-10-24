package it.ddone.simplenotes.sync;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import it.ddone.simplenotes.note.*;
import it.ddone.simplenotes.task.*;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class SyncService {
    private final EntityManager em;
    private final SyncChangeRepository changes;
    private final SyncOperationRepository operations;
    private final TaskRepository tasks;
    private final TaskListRepository lists;
    private final NoteRepository notes;
    private final ObjectMapper json;

    public SyncService(EntityManager em, SyncChangeRepository changes,
            SyncOperationRepository operations, TaskRepository tasks,
            TaskListRepository lists, NoteRepository notes, ObjectMapper json) {
        this.em = em;
        this.changes = changes;
        this.operations = operations;
        this.tasks = tasks;
        this.lists = lists;
        this.notes = notes;
        this.json = json;
    }

    @Transactional
    public SyncController.ApplyResponse apply(UUID owner, SyncController.ApplyRequest req) {
        // Serialize writes per account: sequence allocation and commit order stay aligned
        // across multiple backend instances using the same PostgreSQL database.
        em.createNativeQuery("SELECT pg_advisory_xact_lock(hashtext(:owner))")
            .setParameter("owner", owner.toString()).getSingleResult();

        if (!Set.of("task", "note", "list").contains(req.entityType()) ||
                !Set.of("upsert", "delete", "restore").contains(req.action()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported sync operation");

        if ("restore".equals(req.action()) && !"note".equals(req.entityType()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Only notes can be restored");
        Optional<SyncOperation> previous = operations.findById(req.operationId());
        if (previous.isPresent()) {
            SyncOperation old = previous.get();
            if (!old.ownerId.equals(owner) || !old.entityType.equals(req.entityType()) ||
                    !old.entityId.equals(req.entityId()))
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Operation ID reused");
            return new SyncController.ApplyResponse(req.operationId(), old.resultingVersion, old.changeId);
        }
        if ("upsert".equals(req.action()) && (req.payload() == null || !req.payload().isObject()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Missing payload");

        Mutation applied = switch (req.entityType()) {
            case "task" -> applyTask(owner, req);
            case "list" -> applyList(owner, req);
            default -> applyNote(owner, req);
        };
        SyncChange change = changes.saveAndFlush(new SyncChange(owner, req.entityType(),
            req.entityId(), applied.payload(), applied.deleted(), applied.version()));
        operations.saveAndFlush(new SyncOperation(req.operationId(), owner, req.entityType(),
            req.entityId(), applied.version(), change.id));
        return new SyncController.ApplyResponse(req.operationId(), applied.version(), change.id);
    }

    private record Mutation(long version, boolean deleted, String payload) {}

    private Mutation applyTask(UUID owner, SyncController.ApplyRequest req) {
        TaskEntity existing = tasks.findByIdAndOwnerIdAndDeletedAtIsNull(req.entityId(), owner)
            .orElse(null);
        if ("delete".equals(req.action())) {
            if (existing == null) return new Mutation(0, true, "{}");
            requireVersion(req.expectedVersion(), existing.version);
            existing.deletedAt = existing.updatedAt = Instant.now();
            tasks.saveAndFlush(existing);
            return new Mutation(existing.version, true, "{}");
        }
        JsonNode value = req.payload();
        String title = requiredText(value, "title", 1024);
        String description = value.path("description").isNull() ? null :
            optionalText(value, "description");
        // Modern due semantics must never be silently overwritten by an older
        // client which uploads only dueAt during an unrelated title update.
        TaskDue due;
        if (value.has("due")) {
            due = TaskDue.parse(value.get("due"));
            if (value.has("dueAt") &&
                !Objects.equals(optionalInstant(value, "dueAt"), due.instant()))
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "dueAt does not match explicit due specification");
        } else {
            if (existing != null && Set.of("date", "datetime").contains(existing.dueKind))
                throw new ClientUpgradeRequiredException();
            due = TaskDue.fromOldInstant(optionalInstant(value, "dueAt"));
        }
        boolean completed = value.path("completed").asBoolean(false);
        UUID listId = optionalUuid(value, "listId");
        if (listId != null && !lists.existsByIdAndOwnerIdAndDeletedAtIsNull(listId, owner)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown or foreign list");
        }
        int priority = value.path("priority").asInt(0);
        if (priority < 0 || priority > 3 || (value.has("priority") && !value.get("priority").isInt())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid priority");
        }
        String tagsJson = encode(readTags(value.path("tags")));
        String subtasksJson = encode(readSubtasks(value.path("subtasks")));
        TaskEntity entity;
        if (existing == null) {
            if (req.expectedVersion() != null)
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Task deleted or missing on server");
            entity = new TaskEntity(owner, title, description, due.instant());
            entity.id = req.entityId();
        } else {
            requireVersion(req.expectedVersion(), existing.version);
            entity = existing;
            entity.title = title;
            entity.description = description;
            entity.updatedAt = Instant.now();
        }
        due.applyTo(entity);
        entity.listId = listId;
        entity.priority = priority;
        entity.tagsJson = tagsJson;
        entity.subtasksJson = subtasksJson;
        entity.completedAt = completed ?
            (entity.completedAt == null ? Instant.now() : entity.completedAt) : null;
        tasks.saveAndFlush(entity);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("title", entity.title);
        result.put("completed", entity.completedAt != null);
        result.put("description", entity.description == null ? "" : entity.description);
        result.put("dueAt", entity.dueAt == null ? "" : entity.dueAt.toString());
        result.put("due", TaskDue.fromEntity(entity).toPayload());
        result.put("createdAt", entity.createdAt.toString());
        result.put("listId", entity.listId == null ? null : entity.listId.toString());
        result.put("priority", entity.priority);
        result.put("tags", readStoredJson(entity.tagsJson));
        result.put("subtasks", readStoredJson(entity.subtasksJson));
        return new Mutation(entity.version, false, encode(result));
    }

    private Mutation applyList(UUID owner, SyncController.ApplyRequest req) {
        TaskListEntity existing = lists.findByIdAndOwnerIdAndDeletedAtIsNull(req.entityId(), owner)
            .orElse(null);
        if ("delete".equals(req.action())) {
            if (existing == null) return new Mutation(0, true, "{}");
            requireVersion(req.expectedVersion(), existing.version);
            if (tasks.existsByOwnerIdAndListIdAndDeletedAtIsNull(owner, req.entityId())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Move existing tasks to Inbox before deleting list");
            }
            existing.deletedAt = existing.updatedAt = Instant.now();
            lists.saveAndFlush(existing);
            return new Mutation(existing.version, true, "{}");
        }
        String title = requiredText(req.payload(), "title", 255).trim();
        TaskListEntity entity;
        if (existing == null) {
            if (req.expectedVersion() != null)
                throw new ResponseStatusException(HttpStatus.CONFLICT, "List deleted or missing");
            entity = new TaskListEntity(owner, title);
            entity.id = req.entityId();
        } else {
            requireVersion(req.expectedVersion(), existing.version);
            entity = existing;
            entity.title = title;
            entity.updatedAt = Instant.now();
        }
        lists.saveAndFlush(entity);
        return new Mutation(entity.version, false, encode(Map.of(
            "title", entity.title, "createdAt", entity.createdAt.toString())));
    }

    private static UUID optionalUuid(JsonNode payload, String field) {
        JsonNode value = payload.get(field);
        if (value == null || value.isNull() || value.asText().isBlank()) return null;
        if (!value.isTextual()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid " + field);
        try { return UUID.fromString(value.textValue()); }
        catch (IllegalArgumentException exception) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid " + field);
        }
    }

    private static List<String> readTags(JsonNode value) {
        if (value.isMissingNode() || value.isNull()) return List.of();
        if (!value.isArray() || value.size() > 16)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid tags");
        LinkedHashSet<String> tags = new LinkedHashSet<>();
        for (JsonNode item : value) {
            if (!item.isTextual() || item.textValue().isBlank() || item.textValue().length() > 40)
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid tag");
            tags.add(item.textValue().trim());
        }
        return List.copyOf(tags);
    }

    private static List<Map<String, Object>> readSubtasks(JsonNode value) {
        if (value.isMissingNode() || value.isNull()) return List.of();
        if (!value.isArray() || value.size() > 50)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid subtasks");
        Set<UUID> seen = new HashSet<>();
        List<Map<String, Object>> result = new ArrayList<>();
        for (JsonNode item : value) {
            if (!item.isObject()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid subtask");
            UUID id = optionalUuid(item, "id");
            if (id == null || !seen.add(id))
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid subtask ID");
            String title = requiredText(item, "title", 255).trim();
            if (!item.path("completed").isBoolean() && item.has("completed"))
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid subtask status");
            result.add(Map.of("id", id.toString(), "title", title,
                "completed", item.path("completed").asBoolean(false)));
        }
        return result;
    }

    private JsonNode readStoredJson(String jsonText) {
        try { return json.readTree(jsonText); }
        catch (JsonProcessingException exception) { throw new IllegalStateException(exception); }
    }

    private Mutation applyNote(UUID owner, SyncController.ApplyRequest req) {
        // Keep tombstones addressable by the owning user for explicit restoration.
        // A regular upsert must NEVER silently resurrect a deleted note.
        NoteEntity stored = notes.findById(req.entityId())
            .filter(note -> note.ownerId.equals(owner)).orElse(null);
        NoteEntity existing = stored != null && stored.deletedAt == null ? stored : null;
        if ("restore".equals(req.action())) {
            if (stored == null || stored.deletedAt == null)
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Note is not in the trash");
            requireVersion(req.expectedVersion(), stored.version);
            stored.deletedAt = null;
            stored.updatedAt = Instant.now();
            notes.saveAndFlush(stored);
            return new Mutation(stored.version, false, encode(Map.of(
                "title", stored.title, "body", stored.body,
                "createdAt", stored.createdAt.toString())));
        }
        if ("delete".equals(req.action())) {
            if (existing == null) return new Mutation(0, true, "{}");
            requireVersion(req.expectedVersion(), existing.version);
            existing.deletedAt = existing.updatedAt = Instant.now();
            notes.saveAndFlush(existing);
            return new Mutation(existing.version, true, "{}");
        }
        JsonNode value = req.payload();
        // Local note editor permits empty titles ("Senza titolo" in the UI).
        // Rejecting them as 400 used to strand the oldest outbox operation,
        // preventing later notes from uploading. Allow blank, still limit size.
        String title = requiredTextAllowEmpty(value, "title");
        if (title.length() > 255) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid title");
        }
        String body = requiredTextAllowEmpty(value, "body");
        NoteEntity entity;
        if (existing == null) {
            if (stored != null || req.expectedVersion() != null)
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Note deleted or missing on server");
            entity = new NoteEntity(owner, title, body);
            entity.id = req.entityId();
        } else {
            requireVersion(req.expectedVersion(), existing.version);
            entity = existing;
            entity.title = title;
            entity.body = body;
            entity.updatedAt = Instant.now();
        }
        notes.saveAndFlush(entity);
        return new Mutation(entity.version, false, encode(Map.of(
            "title", entity.title, "body", entity.body,
            "createdAt", entity.createdAt.toString())));
    }

    private static void requireVersion(Long expected, long current) {
        if (expected == null || expected != current)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Version conflict");
    }

    private static String requiredText(JsonNode payload, String key, int maxLength) {
        String text = requiredTextAllowEmpty(payload, key);
        if (text.isBlank() || text.length() > maxLength)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid " + key);
        return text;
    }

    private static String requiredTextAllowEmpty(JsonNode payload, String key) {
        JsonNode node = payload.get(key);
        if (node == null || !node.isTextual())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Missing " + key);
        return node.textValue();
    }

    private static String optionalText(JsonNode value, String name) {
        JsonNode node = value.get(name);
        return node != null && node.isTextual() ? node.textValue() : null;
    }

    private static Instant optionalInstant(JsonNode value, String name) {
        JsonNode node = value.get(name);
        if (node == null || node.isNull() || node.asText().isBlank()) return null;
        try { return Instant.parse(node.asText()); }
        catch (RuntimeException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid " + name);
        }
    }

    private String encode(Object payload) {
        try { return json.writeValueAsString(payload); }
        catch (JsonProcessingException e) { throw new IllegalStateException(e); }
    }

    @Transactional(readOnly = true)
    public SyncController.LatestChange latest(UUID owner, String type, UUID id) {
        if (!Set.of("task", "note", "list").contains(type)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported entity type");
        }
        SyncChange change = changes.latest(owner, type, id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Entity not synced"));
        try {
            return new SyncController.LatestChange(change.entityType, change.entityId,
                json.readTree(change.payload), change.deleted, change.version, change.id);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException(ex);
        }
    }

    @Transactional(readOnly = true)
    public SyncController.Changes changes(UUID owner, long cursor, int limit) {
        List<SyncChange> page = changes.after(owner, cursor, limit + 1);
        boolean hasMore = page.size() > limit;
        List<SyncController.Change> data = new ArrayList<>();
        for (SyncChange entry : page.subList(0, Math.min(page.size(), limit))) {
            try {
                data.add(new SyncController.Change(entry.id, entry.entityType,
                    entry.entityId, json.readTree(entry.payload), entry.deleted, entry.version));
            } catch (JsonProcessingException e) { throw new IllegalStateException(e); }
        }
        long next = data.isEmpty() ? cursor : data.get(data.size() - 1).changeId();
        return new SyncController.Changes(data, next, hasMore);
    }
}
