package it.ddone.simplenotes.task;

import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class TaskService {
    private final TaskRepository repository;
    public TaskService(TaskRepository repository) { this.repository = repository; }

    @Transactional(readOnly = true)
    public List<TaskEntity> all(UUID ownerId) {
        return repository.findByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(ownerId);
    }

    @Transactional
    public TaskEntity create(UUID ownerId, String title, String description, Instant dueAt) {
        return repository.saveAndFlush(new TaskEntity(ownerId, title, description, dueAt));
    }

    @Transactional
    public TaskEntity update(UUID ownerId, UUID taskId, long expectedVersion,
            String title, String description, Instant dueAt, boolean completed) {
        TaskEntity task = owned(ownerId, taskId);
        if (task.version != expectedVersion)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Version conflict");
        task.title = title;
        task.description = description;
        task.dueAt = dueAt;
        task.completedAt = completed ? (task.completedAt == null ? Instant.now() : task.completedAt) : null;
        task.updatedAt = Instant.now();
        return repository.saveAndFlush(task);
    }

    @Transactional
    public TaskEntity setCompleted(UUID ownerId, UUID taskId, boolean completed) {
        TaskEntity task = owned(ownerId, taskId);
        task.completedAt = completed ? Instant.now() : null;
        task.updatedAt = Instant.now();
        return repository.saveAndFlush(task);
    }

    @Transactional
    public void delete(UUID ownerId, UUID taskId) {
        TaskEntity task = owned(ownerId, taskId);
        task.deletedAt = task.updatedAt = Instant.now();
        repository.saveAndFlush(task);
    }

    private TaskEntity owned(UUID ownerId, UUID taskId) {
        return repository.findByIdAndOwnerIdAndDeletedAtIsNull(taskId, ownerId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Task not found"));
    }
}
