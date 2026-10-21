package it.ddone.simplenotes.sync;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SyncOperationRepository extends JpaRepository<SyncOperation, UUID> {}
