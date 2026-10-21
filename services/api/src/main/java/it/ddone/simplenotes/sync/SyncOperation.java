package it.ddone.simplenotes.sync;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "sync_operation")
public class SyncOperation {
    @Id public UUID id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(name = "entity_type", nullable = false) public String entityType;
    @Column(name = "entity_id", nullable = false) public UUID entityId;
    @Column(name = "resulting_version", nullable = false) public long resultingVersion;
    @Column(name = "change_id", nullable = false) public long changeId;
    @Column(name = "created_at", nullable = false) public Instant createdAt = Instant.now();

    protected SyncOperation() {}
    public SyncOperation(UUID id, UUID owner, String type, UUID entityId, long version, long changeId) {
        this.id = id;
        this.ownerId = owner;
        this.entityType = type;
        this.entityId = entityId;
        this.resultingVersion = version;
        this.changeId = changeId;
    }
}
