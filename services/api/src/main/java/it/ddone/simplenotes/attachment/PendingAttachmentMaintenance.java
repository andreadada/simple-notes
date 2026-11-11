package it.ddone.simplenotes.attachment;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Expire only abandoned PENDING metadata after a safety margin. Do not delete
 * a READY attachment or any object belonging to a trashed note. The bucket's
 * lifecycle policy (separately configured) handles staging object expiry.
 */
@Service
public class PendingAttachmentMaintenance {
    private final NoteAttachmentRepository attachments;
    @Value("${app.attachments.enabled:false}")
    boolean enabled;

    public PendingAttachmentMaintenance(NoteAttachmentRepository attachments) {
        this.attachments = attachments;
    }

    @Scheduled(
        initialDelayString = "${app.attachments.pending-purge-interval-ms:3600000}",
        fixedDelayString = "${app.attachments.pending-purge-interval-ms:3600000}")
    @Transactional
    public int pruneExpired() {
        if (!enabled) return 0;
        var cutoff = Instant.now().minus(24, ChronoUnit.HOURS);
        var expired = attachments
            .findByStateAndPendingExpiresAtBeforeOrderByPendingExpiresAtAsc(
                "PENDING", cutoff, PageRequest.of(0, 200));
        if (!expired.isEmpty()) attachments.deleteAllInBatch(expired);
        return expired.size();
    }
}
