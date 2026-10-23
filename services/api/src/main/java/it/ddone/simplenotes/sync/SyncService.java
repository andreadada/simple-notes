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
    private final NoteRepository notes;
    private final ObjectMapper json;

    public SyncService(EntityManager em, SyncChangeRepository changes,
            SyncOperationRepository operations, TaskRepository tasks,
            NoteRepository notes, ObjectMapper json) {
        this.em = em;
        this.changes = changes;
        this.operations = operations;
        this.tasks = tasks;
        this.notes = notes;
        this.json = json;
    }

    @Transactional
    public SyncController.ApplyResponse apply(UUID owner, SyncController.ApplyRequest req) {
        // Serialize writes per account: sequence allocation and commit order stay aligned
        // across multiple backend instances using the same PostgreSQL database.
        em.createNativeQuery("SELECT pg_advisory_xact_lock(hashtext(:owner))")
            .setParameter("owner", owner.toString()).getSingleResult();

        if (!Set.of("task", "note").contains(req.entityType()) ||
                !Set.of("upsert", "delete").contains(req.action()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported sync operation");

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

        Mutation applied = "task".equals(req.entityType()) ?
            applyTask(owner, req) : applyNote(owner, req);
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
        Instant due = optionalInstant(value, "dueAt");
        boolean completed = value.path("completed").asBoolean(false);
        TaskEntity entity;
        if (existing == null) {
            if (req.expectedVersion() != null)
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Task deleted or missing on server");
            entity = new TaskEntity(owner, title, description, due);
            entity.id = req.entityId();
        } else {
            requireVersion(req.expectedVersion(), existing.version);
            entity = existing;
            entity.title = title;
            entity.description = description;
            entity.dueAt = due;
            entity.updatedAt = Instant.now();
        }
        entity.completedAt = completed ?
            (entity.completedAt == null ? Instant.now() : entity.completedAt) : null;
        tasks.saveAndFlush(entity);
        return new Mutation(entity.version, false, encode(Map.of(
            "title", entity.title, "completed", entity.completedAt != null,
            "description", entity.description == null ? "" : entity.description,
            "dueAt", entity.dueAt == null ? "" : entity.dueAt.toString(),
            "createdAt", entity.createdAt.toString())));
    }

    private Mutation applyNote(UUID owner, SyncController.ApplyRequest req) {
        NoteEntity existing = notes.findByIdAndOwnerIdAndDeletedAtIsNull(req.entityId(), owner)
            .orElse(null);
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
            if (req.expectedVersion() != null)
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
