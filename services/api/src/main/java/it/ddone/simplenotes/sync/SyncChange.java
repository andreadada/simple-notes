package it.ddone.simplenotes.sync;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "sync_change")
public class SyncChange {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) public Long id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(name = "entity_type", nullable = false) public String entityType;
    @Column(name = "entity_id", nullable = false) public UUID entityId;
    @Column(nullable = false, columnDefinition = "text") public String payload;
    @Column(nullable = false) public boolean deleted;
    @Column(nullable = false) public long version;
    @Column(name = "created_at", nullable = false) public Instant createdAt = Instant.now();

    protected SyncChange() {}
    public SyncChange(UUID owner, String type, UUID id, String payload, boolean deleted, long version) {
        this.ownerId = owner;
        this.entityType = type;
        this.entityId = id;
        this.payload = payload;
        this.deleted = deleted;
        this.version = version;
    }
}
