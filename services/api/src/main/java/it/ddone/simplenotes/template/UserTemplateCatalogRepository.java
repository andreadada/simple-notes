package it.ddone.simplenotes.template;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserTemplateCatalogRepository
        extends JpaRepository<UserTemplateCatalogEntity, UUID> {}
