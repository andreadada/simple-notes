package it.ddone.simplenotes.automation;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/** Only definitions are stored: no task mutations or scheduled jobs. */
@Entity
@Table(name = "task_action_catalog")
public class TaskActionCatalogEntity {
    @Id @Column(name = "owner_id", nullable = false)
    public UUID ownerId;
    @Column(name = "payload_json", nullable = false, columnDefinition = "text")
    public String payloadJson;
    @Column(nullable = false)
    public long version;
    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    protected TaskActionCatalogEntity() {}

    public TaskActionCatalogEntity(UUID ownerId, String payloadJson) {
        this.ownerId = ownerId;
        this.payloadJson = payloadJson;
        this.version = 1;
        this.updatedAt = Instant.now();
    }
}
