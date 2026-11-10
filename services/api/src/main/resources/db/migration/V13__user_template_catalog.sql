-- P2 additive, owner-scoped template definitions only; no task/outbox changes.
CREATE TABLE user_template_catalog (
  owner_id UUID PRIMARY KEY REFERENCES app_user(id),
  payload_json TEXT NOT NULL,
  version BIGINT NOT NULL CHECK (version > 0),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT user_template_catalog_max_bytes
    CHECK (octet_length(payload_json) <= 131072)
);
