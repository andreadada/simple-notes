package it.ddone.simplenotes.task;

import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TaskRepository extends JpaRepository<TaskEntity, UUID> {
    List<TaskEntity> findByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID ownerId);
    Optional<TaskEntity> findByIdAndOwnerIdAndDeletedAtIsNull(UUID id, UUID ownerId);
}
