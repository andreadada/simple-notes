package it.ddone.simplenotes.task;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "task_list")
public class TaskListEntity {
    @Id public UUID id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(nullable = false, length = 255) public String title;
    @Version public long version;
    @Column(name = "created_at", nullable = false) public Instant createdAt;
    @Column(name = "updated_at", nullable = false) public Instant updatedAt;
    @Column(name = "deleted_at") public Instant deletedAt;

    protected TaskListEntity() {}
    public TaskListEntity(UUID owner, String title) {
        this.id = UUID.randomUUID();
        this.ownerId = owner;
        this.title = title;
        this.createdAt = this.updatedAt = Instant.now();
    }
}
