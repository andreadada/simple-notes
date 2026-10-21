package it.ddone.simplenotes.task;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "task")
public class TaskEntity {
    @Id public UUID id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(name = "list_id") public UUID listId;
    @Column(nullable = false) public String title;
    @Column(columnDefinition = "text") public String description;
    @Column(name = "due_at") public Instant dueAt;
    @Column(name = "completed_at") public Instant completedAt;
    @Version public long version;
    @Column(name = "created_at", nullable = false) public Instant createdAt;
    @Column(name = "updated_at", nullable = false) public Instant updatedAt;
    @Column(name = "deleted_at") public Instant deletedAt;

    protected TaskEntity() {}
    public TaskEntity(UUID ownerId, String title, String description, Instant dueAt) {
        id = UUID.randomUUID();
        this.ownerId = ownerId;
        this.title = title;
        this.description = description;
        this.dueAt = dueAt;
        createdAt = updatedAt = Instant.now();
    }
}
