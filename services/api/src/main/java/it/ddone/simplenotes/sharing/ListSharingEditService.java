package it.ddone.simplenotes.sharing;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import it.ddone.simplenotes.sync.SyncController;
import it.ddone.simplenotes.sync.SyncService;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * The only cross-account write path. Editor changes are small, explicit
 * patches applied through the OWNER's canonical SyncService ledger.
 * Never grant /sync/apply to collaborators or impersonate the member there.
 */
@Service
public class ListSharingEditService {
    public record EditTask(@NotNull @Min(0) Long expectedVersion,
        String title, String description, Boolean completed, Integer priority) {}
    public record EditedTask(long version, long changeId) {}

    private final JdbcTemplate jdbc;
    private final SyncService sync;
    private final ObjectMapper json;

    public ListSharingEditService(JdbcTemplate jdbc, SyncService sync,
            ObjectMapper json) {
        this.jdbc = jdbc;
        this.sync = sync;
        this.json = json;
    }

    private static ResponseStatusException missing() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND,
            "Shared task unavailable");
    }
    private static ResponseStatusException conflict() {
        return new ResponseStatusException(HttpStatus.CONFLICT,
            "Task changed; refresh before editing");
    }

    @Transactional
    public EditedTask edit(UUID actor, UUID listId, UUID taskId, EditTask edit) {
        if (edit.expectedVersion() == null || edit.expectedVersion() < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Expected task version required");
        }

        // Strictly allow these four fields. No list relocation, task delete,
        // scheduling, recurrence, tags, subtasks or note content can be edited
        // via this endpoint.
        List<String> changed = new ArrayList<>();
        if (edit.title() != null) {
            if (edit.title().isBlank() || edit.title().length() > 1024) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Invalid task title");
            }
            changed.add("title");
        }
        if (edit.description() != null) {
            if (edit.description().length() > 20000) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Description exceeds limit");
            }
            changed.add("description");
        }
        if (edit.completed() != null) changed.add("completed");
        if (edit.priority() != null) {
            if (edit.priority() < 0 || edit.priority() > 3) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Invalid priority");
            }
            changed.add("priority");
        }
        if (changed.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "No editable task field supplied");
        }

        // Resolve owner ONLY from an active membership. Re-check AFTER its
        // advisory lock: owner revocation/role downgrade must win if committed
        // before this operation and must serialize with this edit.
        List<UUID> owners = jdbc.query(
            "SELECT l.owner_id FROM list_share_member m " +
            "JOIN task_list l ON l.id=m.list_id AND l.owner_id=m.owner_id " +
            "WHERE m.member_id=? AND m.list_id=? AND m.role='EDITOR' " +
            "AND l.deleted_at IS NULL",
            (rs, i) -> (UUID) rs.getObject(1), actor, listId);
        if (owners.size() != 1) throw missing();
        UUID owner = owners.get(0);
        sync.lockAccount(owner);

        Integer permission = jdbc.queryForObject(
            "SELECT COUNT(*) FROM list_share_member m " +
            "JOIN task_list l ON l.id=m.list_id AND l.owner_id=m.owner_id " +
            "WHERE m.member_id=? AND m.list_id=? AND m.owner_id=? " +
            "AND m.role='EDITOR' AND l.deleted_at IS NULL",
            Integer.class, actor, listId, owner);
        if (permission == null || permission != 1) throw missing();

        List<Long> materialized = jdbc.query(
            "SELECT version FROM task WHERE id=? AND owner_id=? " +
            "AND list_id=? AND deleted_at IS NULL",
            (rs, i) -> rs.getLong(1), taskId, owner, listId);
        if (materialized.size() != 1) throw missing();

        SyncController.LatestChange current;
        try {
            current = sync.latest(owner, "task", taskId);
        } catch (ResponseStatusException missingLedger) {
            // A task without a matching sync ledger must never become writable
            // through the sharing API. No silent backfill of old records.
            throw conflict();
        }
        if (current.deleted() || current.version() != materialized.get(0) ||
                current.version() != edit.expectedVersion() ||
                current.payload() == null || !current.payload().isObject() ||
                !listId.toString().equals(
                    current.payload().path("listId").asText())) {
            throw conflict();
        }

        ObjectNode payload = (ObjectNode) current.payload().deepCopy();
        if (edit.title() != null) payload.put("title", edit.title().trim());
        if (edit.description() != null) {
            payload.put("description", edit.description());
        }
        if (edit.completed() != null) payload.put("completed", edit.completed());
        if (edit.priority() != null) payload.put("priority", edit.priority());

        // Reuses the same owner OCC, task serialization and sync_change ledger
        // as the desktop/mobile owner's writes; no dual write or fake cursor.
        SyncController.ApplyResponse result = sync.apply(owner,
            new SyncController.ApplyRequest(UUID.randomUUID(), taskId,
                "task", "upsert", edit.expectedVersion(),
                payload, null));

        // Durable actor attribution without storing title/description or PII.
        jdbc.update("INSERT INTO list_share_audit " +
            "(list_id,owner_id,actor_id,task_id,action,detail,sync_change_id) " +
            "VALUES (?,?,?,?,'TASK_EDIT',?,?)",
            listId, owner, actor, taskId, String.join(",", changed),
            result.changeId());
        return new EditedTask(result.version(), result.changeId());
    }
}
