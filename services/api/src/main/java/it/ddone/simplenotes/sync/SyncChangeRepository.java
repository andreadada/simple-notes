package it.ddone.simplenotes.sync;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SyncChangeRepository extends JpaRepository<SyncChange, Long> {
    @Query(value = "SELECT * FROM sync_change WHERE owner_id = :owner " +
        "AND entity_type = :type AND entity_id = :entity ORDER BY id DESC LIMIT 1",
        nativeQuery = true)
    java.util.Optional<SyncChange> latest(@Param("owner") UUID owner,
        @Param("type") String type, @Param("entity") UUID entity);

    @Query(value = "SELECT * FROM sync_change WHERE owner_id = :owner AND id > :cursor " +
        "ORDER BY id ASC LIMIT :limit", nativeQuery = true)
    List<SyncChange> after(@Param("owner") UUID owner, @Param("cursor") long cursor,
                          @Param("limit") int limit);
}
