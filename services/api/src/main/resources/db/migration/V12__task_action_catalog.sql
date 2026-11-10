-- P2: account-scoped task automation definitions. Additive; no task or outbox
-- migration, no replay, and no automatic execution of stored rules.
CREATE TABLE task_action_catalog (
    owner_id UUID PRIMARY KEY REFERENCES app_user(id),
    payload_json TEXT NOT NULL,
    version BIGINT NOT NULL CHECK (version > 0),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT task_action_catalog_max_bytes CHECK (octet_length(payload_json) <= 32768)
);
