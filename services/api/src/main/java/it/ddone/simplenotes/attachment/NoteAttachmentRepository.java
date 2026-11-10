package it.ddone.simplenotes.attachment;

import java.time.Instant;
import java.util.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface NoteAttachmentRepository
        extends JpaRepository<NoteAttachmentEntity, UUID> {
    List<NoteAttachmentEntity> findByOwnerIdAndNoteIdAndStateOrderByCreatedAtDesc(
        UUID ownerId, UUID noteId, String state);
    Optional<NoteAttachmentEntity> findByIdAndOwnerIdAndNoteId(
        UUID id, UUID owner, UUID note);
    @Query("select count(a) from NoteAttachmentEntity a where a.ownerId = :owner " +
        "and (a.state = 'READY' or a.pendingExpiresAt > :now)")
    long activeCount(@Param("owner") UUID owner, @Param("now") Instant now);
    @Query("select coalesce(sum(a.sizeBytes),0) from NoteAttachmentEntity a " +
        "where a.ownerId = :owner and " +
        "(a.state = 'READY' or a.pendingExpiresAt > :now)")
    long activeBytes(@Param("owner") UUID owner, @Param("now") Instant now);
}
