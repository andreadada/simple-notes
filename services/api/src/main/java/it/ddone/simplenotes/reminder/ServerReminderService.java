package it.ddone.simplenotes.reminder;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Server-owned, opt-in, owner-scoped reminder inbox. It is NOT remote push:
 * multiple clients see the same occurrence and share one acknowledgment.
 * No task content is persisted in the occurrence table or sent to third parties.
 */
@Service
public class ServerReminderService {
    public record Preferences(boolean enabled, int leadMinutes, long version) {}
    public record Occurrence(UUID id, UUID taskId, String title, Instant dueAt,
        Instant fireAt, int leadMinutes) {}

    public static final Set<Integer> ALLOWED_LEADS = Set.of(0,5,15,30,60,1440);
    private final JdbcTemplate jdbc;

    public ServerReminderService(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @Transactional(readOnly = true)
    public Preferences preferences(UUID owner) {
        var rows = jdbc.query("SELECT enabled,lead_minutes,version"
            + " FROM server_reminder_preference WHERE owner_id=?",
            (rs,n) -> new Preferences(rs.getBoolean(1),rs.getInt(2),
                rs.getLong(3)),owner);
        return rows.isEmpty() ? new Preferences(false,15,0) : rows.get(0);
    }

    @Transactional
    public Preferences configure(UUID owner, boolean enabled, int leadMinutes,
            long expectedVersion) {
        if (!ALLOWED_LEADS.contains(leadMinutes) || expectedVersion < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Invalid reminder settings");
        }
        jdbc.query("SELECT pg_advisory_xact_lock(hashtext(?))",
            rs -> { /* Ignore the PostgreSQL void return value. */ },
            owner.toString());
        Preferences current = preferences(owner);
        if (current.version() != expectedVersion || current.version() == Long.MAX_VALUE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Reminder preferences changed; reload before saving");
        }
        if (current.version() == 0) {
            jdbc.update("INSERT INTO server_reminder_preference"
                + "(owner_id,enabled,lead_minutes,version) VALUES(?,?,?,1)",
                owner,enabled,leadMinutes);
        } else {
            jdbc.update("UPDATE server_reminder_preference SET enabled=?,"
                + " lead_minutes=?,version=version+1,updated_at=now()"
                + " WHERE owner_id=?",enabled,leadMinutes,owner);
        }
        return new Preferences(enabled,leadMinutes,current.version()+1);
    }

    /**
     * Materialize overdue occurrences within a bounded look-back.
     * The SQL unique constraint prevents duplicate work across API instances.
     * Date-only and legacy due are deliberately excluded (no invented hour).
     */
    @Scheduled(initialDelayString = "$" + "{app.reminders.scan-initial-ms:60000}",
        fixedDelayString = "$" + "{app.reminders.scan-interval-ms:60000}")
    @Transactional
    public int scan() {
        return jdbc.update("""
            WITH eligible AS (
                SELECT t.id AS task_id, t.owner_id, t.due_at,
                    p.lead_minutes,
                    t.due_at - (p.lead_minutes * INTERVAL '1 minute') AS fire_at
                FROM task t
                JOIN server_reminder_preference p ON p.owner_id=t.owner_id
                WHERE p.enabled=TRUE
                  AND t.due_kind='datetime' AND t.due_at IS NOT NULL
                  AND t.completed_at IS NULL AND t.deleted_at IS NULL
                  AND t.due_at - (p.lead_minutes * INTERVAL '1 minute') <= now()
                  AND t.due_at - (p.lead_minutes * INTERVAL '1 minute')
                      >= now() - INTERVAL '24 hours'
                  AND NOT EXISTS (
                      SELECT 1 FROM server_reminder_occurrence o
                      WHERE o.owner_id=t.owner_id AND o.task_id=t.id
                        AND o.due_at=t.due_at
                        AND o.lead_minutes=p.lead_minutes
                  )
                ORDER BY t.due_at, t.id
                LIMIT 200
            )
            INSERT INTO server_reminder_occurrence
                (id,owner_id,task_id,due_at,fire_at,lead_minutes)
            SELECT gen_random_uuid(),owner_id,task_id,due_at,fire_at,lead_minutes
            FROM eligible
            ON CONFLICT ON CONSTRAINT uq_server_reminder_occurrence DO NOTHING
            """);
    }

    @Transactional(readOnly = true)
    public List<Occurrence> unread(UUID owner) {
        return jdbc.query("""
            SELECT o.id,o.task_id,t.title,o.due_at,o.fire_at,o.lead_minutes
            FROM server_reminder_occurrence o
            JOIN task t ON t.id=o.task_id AND t.owner_id=o.owner_id
            JOIN server_reminder_preference p
              ON p.owner_id=o.owner_id AND p.enabled=TRUE
            WHERE o.owner_id=? AND o.acknowledged_at IS NULL
              AND t.deleted_at IS NULL AND t.completed_at IS NULL
              AND t.due_kind='datetime' AND t.due_at=o.due_at
              AND o.fire_at>=now()-INTERVAL '24 hours'
              AND o.fire_at<=now()
            ORDER BY o.fire_at DESC, o.id
            LIMIT 50
            """, (rs,n) -> new Occurrence(
                rs.getObject(1,UUID.class), rs.getObject(2,UUID.class),
                rs.getString(3), rs.getTimestamp(4).toInstant(),
                rs.getTimestamp(5).toInstant(),rs.getInt(6)),owner);
    }

    @Transactional
    public void acknowledge(UUID owner, UUID id) {
        int found = jdbc.queryForObject(
            "SELECT COUNT(*) FROM server_reminder_occurrence"
                + " WHERE id=? AND owner_id=?",Integer.class,id,owner);
        if (found == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                "Reminder occurrence not found");
        }
        jdbc.update("UPDATE server_reminder_occurrence"
                + " SET acknowledged_at=COALESCE(acknowledged_at,now())"
                + " WHERE owner_id=? AND id=?",owner,id);
    }

    /** Keep only a bounded audit window; never touch tasks or preferences. */
    @Scheduled(initialDelayString = "$" + "{app.reminders.prune-initial-ms:3600000}",
        fixedDelayString = "$" + "{app.reminders.prune-interval-ms:86400000}")
    @Transactional
    public int prune() {
        return jdbc.update("DELETE FROM server_reminder_occurrence"
            + " WHERE fire_at<now()-INTERVAL '30 days'");
    }
}
