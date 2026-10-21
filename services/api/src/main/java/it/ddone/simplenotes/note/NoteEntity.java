package it.ddone.simplenotes.note;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "note")
public class NoteEntity {
    @Id public UUID id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(nullable = false) public String title;
    @Column(nullable = false, columnDefinition = "text") public String body;
    @Version public long version;
    @Column(name = "created_at", nullable = false) public Instant createdAt;
    @Column(name = "updated_at", nullable = false) public Instant updatedAt;
    @Column(name = "deleted_at") public Instant deletedAt;

    protected NoteEntity() {}
    public NoteEntity(UUID ownerId, String title, String body) {
        id = UUID.randomUUID();
        this.ownerId = ownerId;
        this.title = title;
        this.body = body;
        createdAt = updatedAt = Instant.now();
    }
}
