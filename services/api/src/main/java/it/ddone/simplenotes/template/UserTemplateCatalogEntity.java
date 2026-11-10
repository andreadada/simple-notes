package it.ddone.simplenotes.template;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/** Definition storage only: never materializes tasks or sync operations. */
@Entity
@Table(name = "user_template_catalog")
public class UserTemplateCatalogEntity {
    @Id @Column(name = "owner_id", nullable = false)
    public UUID ownerId;
    @Column(name = "payload_json", nullable = false, columnDefinition = "text")
    public String payloadJson;
    @Column(nullable = false)
    public long version;
    @Column(name = "updated_at", nullable = false)
    public Instant updatedAt;

    protected UserTemplateCatalogEntity() {}

    public UserTemplateCatalogEntity(UUID owner, String payload) {
        ownerId = owner;
        payloadJson = payload;
        version = 1;
        updatedAt = Instant.now();
    }
}
