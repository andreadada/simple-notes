package it.ddone.simplenotes.sync;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.NullNode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import it.ddone.simplenotes.note.*;
import it.ddone.simplenotes.task.*;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
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

    /// P2.4B2C3: one consistent PostgreSQL snapshot of owner-scoped latest
    /// revisions. This is GET-only; it does not mutate or acknowledge sync.
    /// Distinct latest rows include tombstones, but never payload contents.
    /// Large accounts fail closed rather than returning a partial inventory.
    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public SyncController.Inventory inventory(UUID owner) {
        // The sync-only ledger might omit legacy-created rows. "complete"
        // MUST NOT be returned if actual account rows diverge from history.
        // The preflight and inventory share the same read-only owner audit.
        if (!ownerMaterializedHistoryCoherent(owner)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Account data and sync history differ");
        }
        long cursor = ((Number) em.createNativeQuery(
                "SELECT COALESCE(MAX(id),0) FROM sync_change WHERE owner_id = :owner")
            .setParameter("owner", owner).getSingleResult()).longValue();

        @SuppressWarnings("unchecked")
        List<Object[]> rows = em.createNativeQuery(
                "SELECT DISTINCT ON (entity_type, entity_id) " +
                "entity_type, entity_id, version, deleted, id " +
                "FROM sync_change WHERE owner_id = :owner " +
                "ORDER BY entity_type, entity_id, id DESC")
            .setParameter("owner", owner)
            .setMaxResults(10001)
            .getResultList();
        if (rows.size() > 10000) {
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,
                "Inventory exceeds safety limit; no partial snapshot returned");
        }
        List<SyncController.InventoryItem> latest = new ArrayList<>(rows.size());
        for (Object[] row : rows) {
            latest.add(new SyncController.InventoryItem(
                (String) row[0],
                (UUID) row[1],
                ((Number) row[2]).longValue(),
                (Boolean) row[3],
                ((Number) row[4]).longValue()));
        }
        return new SyncController.Inventory(cursor, List.copyOf(latest), true);
    }

    /// One repeatable-read snapshot for the expected account cursor and
    /// up to 100 latest entity ledger revisions. Never writes any table,
    /// acknowledges any operation, or grants a subsequent commit permit.
    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public SyncController.ReconciliationCheckResponse reconciliationCheck(
            UUID owner, SyncController.ReconciliationCheckRequest req) {
        if (req.expectedCursor() == null || req.expectedCursor() < 0 ||
                req.items() == null || req.items().isEmpty() ||
                req.items().size() > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Invalid reconciliation request");
        }
        var seen = new HashSet<String>();
        for (var row : req.items()) {
            if (row == null || row.entityId() == null ||
                    !Set.of("task", "note", "list").contains(row.entityType()) ||
                    !seen.add(row.entityType() + ":" + row.entityId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Duplicate or invalid revision key");
            }
            if (row.changeId() == null) {
                if (row.version() != null || row.deleted() != null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Absent revision must have no version or tombstone");
                }
            } else if (row.changeId() <= 0 || row.version() == null ||
                    row.version() < 0 || row.deleted() == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Incomplete expected revision");
            }
        }
        // Check the entire owner account, not just the entities submitted
        // by the client. An inventory derived solely from sync_change could
        // otherwise omit unrelated legacy-created records entirely.
        if (!ownerMaterializedHistoryCoherent(owner)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Account data and sync history differ");
        }
        long cursor = ((Number) em.createNativeQuery(
                "SELECT COALESCE(MAX(id),0) FROM sync_change WHERE owner_id = :owner")
            .setParameter("owner", owner).getSingleResult()).longValue();
        var observed = new ArrayList<SyncController.ObservedRevision>();
        boolean everyRevisionMatches = true;
        for (var expected : req.items()) {
            SyncChange latest = changes.latest(owner, expected.entityType(),
                expected.entityId()).orElse(null);
            // A legacy REST endpoint can change the materialized row without
            // appending sync_change. In that case the ledger-only preflight
            // would be misleading even if the expected cursor still matches.
            // Reject the entire batch instead of reporting false consistency.
            if (!materializedMatchesLedger(owner, expected.entityType(),
                    expected.entityId(), latest)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Materialized state differs from sync history");
            }
            Long changeId = latest == null ? null : latest.id;
            Long version = latest == null ? null : latest.version;
            Boolean deleted = latest == null ? null : latest.deleted;
            boolean matches = Objects.equals(changeId, expected.changeId()) &&
                Objects.equals(version, expected.version()) &&
                Objects.equals(deleted, expected.deleted());
            everyRevisionMatches &= matches;
            observed.add(new SyncController.ObservedRevision(
                expected.entityType(), expected.entityId(), changeId,
                version, deleted, matches));
        }
        boolean cursorMatches = cursor == req.expectedCursor();
        return new SyncController.ReconciliationCheckResponse(cursor,
            cursorMatches, cursorMatches && everyRevisionMatches,
            List.copyOf(observed));
    }

    /// Complete account read-only consistency scan for the preflight.
    /// Both halves are necessary:
    /// 1) materialized rows missing/mismatched in sync history;
    /// 2) latest active sync events whose materialized entity is missing.
    /// A synthetic tombstone for an already-absent entity is valid, however.
    /// Table names are a compile-time allowlist, never user-controlled.
    private boolean ownerMaterializedHistoryCoherent(UUID owner) {
        for (var entry : Map.of(
                "note", "note",
                "task", "task",
                "list", "task_list").entrySet()) {
            String type = entry.getKey();
            String table = entry.getValue();
            Object unmatchedRows = em.createNativeQuery(
                    "SELECT EXISTS (SELECT 1 FROM " + table + " materialized " +
                    "LEFT JOIN LATERAL (" +
                    "SELECT c.version, c.deleted FROM sync_change c " +
                    "WHERE c.owner_id = :owner AND c.entity_type = :type " +
                    "AND c.entity_id = materialized.id " +
                    "ORDER BY c.id DESC LIMIT 1) ledger ON TRUE " +
                    "WHERE materialized.owner_id = :owner AND " +
                    "(ledger.version IS NULL OR " +
                    "ledger.version <> materialized.version OR " +
                    "ledger.deleted <> (materialized.deleted_at IS NOT NULL)))")
                .setParameter("owner", owner)
                .setParameter("type", type).getSingleResult();
            if (Boolean.TRUE.equals(unmatchedRows)) return false;

            Object missingActiveRows = em.createNativeQuery(
                    "SELECT EXISTS (SELECT 1 FROM (" +
                    "SELECT DISTINCT ON (entity_id) entity_id, deleted " +
                    "FROM sync_change WHERE owner_id = :owner " +
                    "AND entity_type = :type " +
                    "ORDER BY entity_id, id DESC) ledger " +
                    "LEFT JOIN " + table + " materialized " +
                    "ON materialized.id = ledger.entity_id " +
                    "AND materialized.owner_id = :owner " +
                    "WHERE materialized.id IS NULL AND NOT ledger.deleted)")
                .setParameter("owner", owner)
                .setParameter("type", type).getSingleResult();
            if (Boolean.TRUE.equals(missingActiveRows)) return false;
        }
        return true;
    }

    /// Fail closed if an entity was created/changed by a legacy endpoint
    /// without updating the sync ledger. Only approved table identifiers
    /// are interpolated. Parameters always scope owner and entity ID.
    private boolean materializedMatchesLedger(UUID owner, String entityType,
            UUID entityId, SyncChange latest) {
        String table = switch (entityType) {
            case "note" -> "note";
            case "task" -> "task";
            case "list" -> "task_list";
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Unsupported entity type");
        };
        @SuppressWarnings("unchecked")
        List<Object[]> rows = em.createNativeQuery(
                "SELECT version, (deleted_at IS NOT NULL) FROM " + table +
                " WHERE owner_id = :owner AND id = :entity")
            .setParameter("owner", owner)
            .setParameter("entity", entityId)
            .getResultList();
        if (rows.size() != 1) {
            // /sync/apply delete of a nonexistent record deliberately
            // generates a tombstone even though there is no physical row.
            return rows.isEmpty() && (latest == null || latest.deleted);
        }
        if (latest == null) return false;
        Object[] row = rows.get(0);
        return ((Number) row[0]).longValue() == latest.version &&
            ((Boolean) row[1]) == latest.deleted;
    }

    /**
     * Must be called inside an existing write transaction before reading a
     * legacy row for a later mutation. Same advisory transaction lock as
     * sync/apply; serializes legacy REST reads with Flutter sync writes.
     */
    public void lockAccount(UUID owner) {
        em.createNativeQuery("SELECT pg_advisory_xact_lock(hashtext(:owner))")
            .setParameter("owner", owner.toString()).getSingleResult();
    }

    @Transactional
    public SyncController.ApplyResponse apply(UUID owner, SyncController.ApplyRequest req) {
        // All writes (including legacy REST) lock before reading or mutating.
        lockAccount(owner);

        if (!Set.of("task", "note", "list").contains(req.entityType()) ||
                !Set.of("upsert", "delete", "restore").contains(req.action()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported sync operation");

        if ("restore".equals(req.action()) && !"note".equals(req.entityType()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Only notes can be restored");
        // An operation ID names one immutable user intent. Ignore the
        // transient cursor CAS in the digest: a byte-for-byte semantic retry
        // after a successful commit must remain idempotent despite cursor
        // advancement. Recursively sort JSON objects for order independence.
        String fingerprint = requestFingerprint(req);
        Optional<SyncOperation> previous = operations.findById(req.operationId());
        if (previous.isPresent()) {
            SyncOperation old = previous.get();
            if (!old.ownerId.equals(owner)) {
                // Never reveal details of another account's operation.
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Operation ID reused");
            }
            if (!old.entityType.equals(req.entityType()) ||
                    !old.entityId.equals(req.entityId()) ||
                    (old.requestFingerprint != null &&
                     !old.requestFingerprint.equals(fingerprint))) {
                throw new SyncOperationIntentConflict();
            }
            // Pre-V11 historical rows have no fingerprint. Preserve their
            // legacy retry behavior; do not rewrite or backfill them.
            return new SyncController.ApplyResponse(req.operationId(),
                old.resultingVersion, old.changeId);
        }
        if ("upsert".equals(req.action()) && (req.payload() == null || !req.payload().isObject()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Missing payload");

        // Optional CAS precondition, checked AFTER the account advisory lock
        // and AFTER idempotent replay lookup but BEFORE any write. Legacy sync
        // clients omit this field; a future recovery client must supply it.
        if (req.expectedAccountCursor() != null) {
            long observedCursor = ((Number) em.createNativeQuery(
                    "SELECT COALESCE(MAX(id),0) FROM sync_change WHERE owner_id = :owner")
                .setParameter("owner", owner).getSingleResult()).longValue();
            if (req.expectedAccountCursor() != observedCursor) {
                throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Account cursor changed; refresh inventory before retry");
            }
        }

        Mutation applied = switch (req.entityType()) {
            case "task" -> applyTask(owner, req);
            case "list" -> applyList(owner, req);
            default -> applyNote(owner, req);
        };
        SyncChange change = changes.saveAndFlush(new SyncChange(owner, req.entityType(),
            req.entityId(), applied.payload(), applied.deleted(), applied.version()));
        operations.saveAndFlush(new SyncOperation(req.operationId(), owner, req.entityType(),
            req.entityId(), applied.version(), change.id, fingerprint));
        return new SyncController.ApplyResponse(req.operationId(), applied.version(), change.id);
    }

    /**
     * SHA-256 of immutable mutation intent, NOT a cloud restore permit.
     * Includes entity identity, action, expected record version and canonical
     * payload; excludes expectedAccountCursor because it is a transient CAS
     * guard, not part of the actual operation. Never expose the digest in API.
     */
    private String requestFingerprint(SyncController.ApplyRequest req) {
        ObjectNode data = json.createObjectNode();
        data.put("schema", 1);
        data.put("entityType", req.entityType());
        data.put("entityId", req.entityId().toString());
        data.put("action", req.action());
        if (req.expectedVersion() == null) {
            data.putNull("expectedVersion");
        } else {
            data.put("expectedVersion", req.expectedVersion());
        }
        data.set("payload", canonicalPayload(req.payload()));
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(data.toString().getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("Required SHA-256 unavailable", ex);
        }
    }

    private JsonNode canonicalPayload(JsonNode input) {
        if (input == null || input.isNull()) return NullNode.getInstance();
        if (input.isObject()) {
            ObjectNode ordered = json.createObjectNode();
            List<String> names = new ArrayList<>();
            input.fieldNames().forEachRemaining(names::add);
            Collections.sort(names);
            for (String key : names) ordered.set(key,
                canonicalPayload(input.get(key)));
            return ordered;
        }
        if (input.isArray()) {
            ArrayNode values = json.createArrayNode();
            input.forEach(item -> values.add(canonicalPayload(item)));
            return values;
        }
        return input;
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
        // v9 is canonical. v8 payloads may update 0/1 slots, but must
        // never silently erase 2+ independent time slots from a newer app.
        List<TaskTimeBlocks.Slot> oldSlots = existing == null ? List.of()
            : TaskTimeBlocks.fromEntity(existing, json);
        List<TaskTimeBlocks.Slot> slots;
        if (value.has("timeBlocks")) {
            slots = TaskTimeBlocks.parse(value.get("timeBlocks"));
            if (value.has("timeBlock")) {
                TaskTimeBlock mirror = TaskTimeBlock.parse(value.get("timeBlock"));
                TaskTimeBlock first = slots.isEmpty() ? null : slots.get(0).block();
                if (!Objects.equals(mirror, first))
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "timeBlock mirror does not match timeBlocks[0]");
            }
        } else {
            if (oldSlots.size() > 1) throw new ClientUpgradeRequiredException();
            TaskTimeBlock oldBlock = null;
            if (value.has("timeBlock")) {
                oldBlock = TaskTimeBlock.parse(value.get("timeBlock"));
            } else if (!oldSlots.isEmpty()) {
                throw new ClientUpgradeRequiredException();
            }
            slots = oldBlock == null ? List.of()
                : List.of(new TaskTimeBlocks.Slot(
                    oldSlots.isEmpty() ? "legacy" : oldSlots.get(0).id(), oldBlock));
        }
        // A legacy client must not erase an enabled recurrence while merely
        // editing title or tags. New clients send explicit {"kind":"none"}.
        TaskRecurrence oldRecurrence;
        try {
            oldRecurrence = existing == null ? TaskRecurrence.none()
                : TaskRecurrence.parse(json.readTree(existing.recurrenceJson));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Invalid stored recurrence", exception);
        }
        TaskRecurrence recurrence = value.has("recurrence")
            ? TaskRecurrence.parse(value.get("recurrence"))
            : TaskRecurrence.none();
        if (!value.has("recurrence") && !"none".equals(oldRecurrence.kind())) {
            throw new ClientUpgradeRequiredException();
        }
        if (!"none".equals(recurrence.kind()) &&
                !Set.of("date", "datetime").contains(due.kind())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Recurring task requires date-only or timed due");
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
        TaskTimeBlocks.applyTo(entity, slots, json);
        entity.recurrenceJson = encode(recurrence.payload());
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
        result.put("timeBlock", TaskTimeBlock.toPayload(entity));
        result.put("timeBlocks", TaskTimeBlocks.toPayload(slots));
        result.put("recurrence", recurrence.payload());
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
