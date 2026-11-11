package it.ddone.simplenotes.attachment;

import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Persisted S3 deletion outbox. Metadata removal and enqueue commit atomically;
 * a failed S3 DELETE never loses the cleanup intent. Per-row PostgreSQL locks
 * with SKIP LOCKED prevent duplicate concurrent workers across API instances.
 */
@Service
public class AttachmentDeletionQueue {
    private final JdbcTemplate jdbc;
    private final AttachmentObjectStore objects;

    @Value("${app.attachments.enabled:false}")
    boolean enabled;

    public AttachmentDeletionQueue(JdbcTemplate jdbc,
            AttachmentObjectStore objects) {
        this.jdbc = jdbc;
        this.objects = objects;
    }

    @Transactional
    public void enqueue(UUID owner, String key) {
        // Keys are assigned by our server only; refuse arbitrary S3 deletes.
        if (!key.startsWith("files/" + owner + "/") ||
                key.length() > 256) {
            throw new IllegalArgumentException("Invalid owned attachment key");
        }
        jdbc.update(
            "INSERT INTO attachment_object_delete_queue(object_key,owner_id) " +
            "VALUES (?,?) ON CONFLICT (object_key) DO NOTHING", key, owner);
    }

    @Scheduled(initialDelayString =
        "${app.attachments.delete-retry-interval-ms:60000}",
        fixedDelayString =
        "${app.attachments.delete-retry-interval-ms:60000}")
    @Transactional
    public int drain() {
        if (!enabled) return 0;
        var keys = jdbc.query(
            "SELECT object_key FROM attachment_object_delete_queue " +
            "WHERE retry_after <= now() ORDER BY queued_at LIMIT 25 " +
            "FOR UPDATE SKIP LOCKED",
            (rs, index) -> rs.getString(1));
        int deleted = 0;
        for (String key : keys) {
            try {
                // S3 DELETE is idempotent; retry after a crash between
                // object removal and transaction commit is safe.
                objects.delete(key);
                jdbc.update("DELETE FROM attachment_object_delete_queue " +
                    "WHERE object_key = ?", key);
                deleted++;
            } catch (RuntimeException unavailable) {
                // Never print object keys or provider responses to logs.
                jdbc.update("UPDATE attachment_object_delete_queue SET " +
                    "attempts = LEAST(attempts+1,100000), " +
                    "retry_after = now() + INTERVAL '5 minutes' " +
                    "WHERE object_key = ?", key);
            }
        }
        return deleted;
    }
}
