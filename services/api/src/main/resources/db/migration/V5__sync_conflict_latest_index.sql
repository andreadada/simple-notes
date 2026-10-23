-- Faster lookup of the last server version for a conflicted item.
-- The owner_id prefix guarantees account scoping in the repository query.
CREATE INDEX idx_sync_change_owner_entity_latest
    ON sync_change(owner_id, entity_type, entity_id, id DESC);
