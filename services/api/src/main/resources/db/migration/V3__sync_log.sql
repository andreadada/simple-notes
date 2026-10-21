CREATE TABLE sync_change (
    id BIGSERIAL PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES app_user(id),
    entity_type VARCHAR(12) NOT NULL,
    entity_id UUID NOT NULL,
    payload TEXT NOT NULL,
    deleted BOOLEAN NOT NULL,
    version BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sync_change_owner_seq ON sync_change(owner_id, id);

CREATE TABLE sync_operation (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES app_user(id),
    entity_type VARCHAR(12) NOT NULL,
    entity_id UUID NOT NULL,
    resulting_version BIGINT NOT NULL,
    change_id BIGINT NOT NULL REFERENCES sync_change(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sync_operation_owner ON sync_operation(owner_id);
