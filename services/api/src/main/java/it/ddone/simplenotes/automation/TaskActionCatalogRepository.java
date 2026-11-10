package it.ddone.simplenotes.automation;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TaskActionCatalogRepository
        extends JpaRepository<TaskActionCatalogEntity, UUID> {}
