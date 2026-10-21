package it.ddone.simplenotes.note;

import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NoteRepository extends JpaRepository<NoteEntity, UUID> {
    List<NoteEntity> findByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID ownerId);
    Optional<NoteEntity> findByIdAndOwnerIdAndDeletedAtIsNull(UUID id, UUID ownerId);
}
