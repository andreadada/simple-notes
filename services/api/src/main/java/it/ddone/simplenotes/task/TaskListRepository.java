package it.ddone.simplenotes.task;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TaskListRepository extends JpaRepository<TaskListEntity, UUID> {
    Optional<TaskListEntity> findByIdAndOwnerIdAndDeletedAtIsNull(UUID id, UUID ownerId);
    boolean existsByIdAndOwnerIdAndDeletedAtIsNull(UUID id, UUID ownerId);
}
