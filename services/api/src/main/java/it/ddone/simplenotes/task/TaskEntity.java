package it.ddone.simplenotes.task;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

@Entity
@Table(name = "task")
public class TaskEntity {
    @Id public UUID id;
    @Column(name = "owner_id", nullable = false) public UUID ownerId;
    @Column(name = "list_id") public UUID listId;
    @Column(nullable = false) public int priority;
    @Column(name = "tags_json", nullable = false, columnDefinition = "text")
    public String tagsJson = "[]";
    @Column(name = "subtasks_json", nullable = false, columnDefinition = "text")
    public String subtasksJson = "[]";
    @Column(nullable = false) public String title;
    @Column(columnDefinition = "text") public String description;
    @Column(name = "due_at") public Instant dueAt;
    @Column(name = "due_kind", nullable = false, length = 16)
    public String dueKind = "none";
    @Column(name = "due_date") public LocalDate dueDate;
    @Column(name = "due_time") public LocalTime dueTime;
    @Column(name = "due_timezone", length = 128) public String dueTimezone;
    @Column(name = "due_offset_seconds") public Integer dueOffsetSeconds;
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
        TaskDue.fromOldInstant(dueAt).applyTo(this);
        createdAt = updatedAt = Instant.now();
    }
}
