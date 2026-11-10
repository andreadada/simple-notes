package it.ddone.simplenotes.attachment;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "note_attachment")
public class NoteAttachmentEntity {
    @Id public UUID id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(name = "note_id", nullable = false) public UUID noteId;
    @Column(name = "object_key", nullable = false, unique = true) public String objectKey;
    @Column(name = "file_name", nullable = false) public String fileName;
    @Column(name = "content_type", nullable = false) public String contentType;
    @Column(name = "size_bytes", nullable = false) public long sizeBytes;
    @Column(nullable = false) public String state;
    @Column(name = "created_at", nullable = false) public Instant createdAt;
    @Column(name = "pending_expires_at", nullable = false)
    public Instant pendingExpiresAt;

    protected NoteAttachmentEntity() {}

    public NoteAttachmentEntity(UUID owner, UUID note, String name,
            String type, long size, Instant now) {
        id = UUID.randomUUID();
        ownerId = owner;
        noteId = note;
        fileName = name;
        contentType = type;
        sizeBytes = size;
        state = "PENDING";
        createdAt = now;
        pendingExpiresAt = now.plusSeconds(900);
        objectKey = "staging/" + owner + "/" + id;
    }
}
