-- Additive; existing notes remain plain text until edited in document mode.
ALTER TABLE note ADD COLUMN document_html TEXT;
ALTER TABLE note ADD CONSTRAINT note_document_size CHECK (document_html IS NULL OR octet_length(document_html)<=524288);
CREATE TABLE workspace_table (
 id UUID PRIMARY KEY,
 owner_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
 version BIGINT NOT NULL CHECK(version>0),
 payload_json TEXT NOT NULL CHECK(octet_length(payload_json)<=1048576),
 archived BOOLEAN NOT NULL DEFAULT FALSE,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX workspace_table_owner ON workspace_table(owner_id,archived,updated_at);
